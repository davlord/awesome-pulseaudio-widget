local setmetatable = setmetatable
local lgi = require 'lgi'
local GLib, Gio = lgi.GLib, lgi.Gio
local DBusProxy = Gio.DBusProxy
local BusType = Gio.BusType
local DBusConnection = Gio.DBusConnection
local DBusConnectionFlags = Gio.DBusConnectionFlags
local DBusSignalFlags = Gio.DBusSignalFlags
local Variant = GLib.Variant

local dbus_proxy = require("awesome-pulseaudio-widget.dbusproxy")

local pulse = { mt = {} }

local function get_connection(session_bus)
    
    local address_proxy = dbus_proxy({
            bus = session_bus,
            interface = "org.PulseAudio.ServerLookup1",
            name="org.PulseAudio1",
            path="/org/pulseaudio/server_lookup1"
    })
    address_proxy:connect()

    local address = address_proxy:get("Address")

    return DBusConnection.new_for_address_sync(address, DBusConnectionFlags.AUTHENTICATION_CLIENT)
end

local function get_core(connection)
    local core_proxy = dbus_proxy({
            bus=connection,
            interface="org.PulseAudio.Core1",
            name=nil,
            path="/org/pulseaudio/core1"
    })
    core_proxy:connect()
    return core_proxy
end

local function get_device(connection, path)
    local core_proxy = dbus_proxy({
            bus=connection,
            interface="org.PulseAudio.Core1.Device",
            name=nil,
            path=path
    })
    core_proxy:connect()
    return core_proxy
end

function pulse:enable_core_events()
    local core = self._private.core
    core:call(
        nil,
        "ListenForSignal",
        Variant('(sao)',{"org.PulseAudio.Core1.Device.VolumeUpdated",{}})
    )
    core:call(
        nil,
        "ListenForSignal",
        Variant('(sao)',{"org.PulseAudio.Core1.Device.MuteUpdated",{}})
    )
    core:call(
        nil,
        "ListenForSignal",
        Variant('(sao)',{"org.PulseAudio.Core1.NewSink",{core:get_path()}})
    )
    core:call(
        nil,
        "ListenForSignal",
        Variant('(sao)',{"org.PulseAudio.Core1.SinkRemoved",{core:get_path()}})
    )
    core:on_signal(function() 
        self:update_sinks() 
    end)
end

local function get_base_volume(device)
    return device:get_property("org.PulseAudio.Core1.Device","BaseVolume")[1].value
end

local function get_volume_percent(device)
    local base_volume = get_base_volume(device)
    local volume = device:get_property("org.PulseAudio.Core1.Device","Volume")[1].value
    
    local volume_percent = {}
    for i, v in ipairs(volume) do
        volume_percent[i] = math.ceil(v / base_volume * 100)
    end
  
    return volume_percent
end

local function set_volume(device, value)
    device:set_property("org.PulseAudio.Core1.Device","Volume", Variant("au", value))
end

local function set_volume_percent(device, value)
    local base_volume = get_base_volume(device)
    local volume = {}
    for i, v in ipairs(value) do
      volume[i] = v * base_volume / 100
    end
    set_volume(device, volume)
end

local function is_muted(device)
    return device:get_property("org.PulseAudio.Core1.Device","Mute")[1].value
end

local function set_muted(device, muted)
    device:set_property("org.PulseAudio.Core1.Device","Mute", Variant("b", muted))
end

function pulse:update_device(device)
    local old_device = self._private.device
    -- stop listening events on old device
    if (old_device ~= nil) then
        old_device.on_signal = nil
        old_device.on_properties_changed = nil
    end

    self._private.device = device

    local function notify()    
        local name = device:get_property("org.PulseAudio.Core1.Device","Name")[1].value

        local audio_state = {
            name = name,
            muted = is_muted(device),
            volume = get_volume_percent(device)[1],
            pulse = true
        }

        self._private.on_change(audio_state) 
    end

    device:on_signal(notify)
    device:on_properties_changed(notify)
    notify()
end

function pulse:update_sinks()
    local core = self._private.core
    local connection = self._private.connection 

    local sinks = core:get_property("org.PulseAudio.Core1","Sinks")[1].value
    local device = dbus_proxy({
            bus=connection,
            interface="org.PulseAudio.Core1.Device",
            name=nil,
            path=sinks[#sinks]
    })
    device:connect()
    self:update_device(device)
end

function pulse:toggle_mute()
    local device = self._private.device
    local is_muted = is_muted(device)
    set_muted(device, not is_muted)
end

function pulse:update_volume(value)
    local device = self._private.device
    local volume = get_volume_percent(device)
    for i, v in ipairs(volume) do  
        volume[i] = v + value
        if (volume[i] < 0) then volume[i] = 0 end
        if (volume[i] > 200) then volume[i] = 200 end
    end
    set_volume_percent(device, volume)
end

function pulse:on_pulse_connect(on_pulse_connect)
    self._private.on_pulse_connect = on_pulse_connect
end

function pulse:connect(on_change)
    self._private.on_change = on_change
    -- initial widget state
    self._private.on_change({
        muted = true,
        volume = -1,
        pulse = false
    })

    local session_bus_subscribtion = nil
    local session_bus = Gio.bus_get_sync(BusType.SESSION)

    local init = function()
        self._private.connection = get_connection(session_bus)
        self._private.core = get_core(self._private.connection)
        self:enable_core_events()
        self:update_sinks()
        session_bus:signal_unsubscribe(session_bus_subscribtion)
        if self._private.on_pulse_connect ~= nil then self._private.on_pulse_connect() end
    end

    -- if dbus is started after the widget
    session_bus_subscribtion = session_bus:signal_subscribe(
        nil, 
        "org.freedesktop.DBus", 
        nil, 
        nil, 
        "org.PulseAudio1", 
        DBusSignalFlags.NONE, 
        init
    )
    
    -- init will fail if pulseaudio is not started
    pcall(init)
end


local function new(args)
    local p = { _private = {} }

    setmetatable(p, {__index = pulse})

    return p
end

function pulse.mt:__call(...)
    return new(...)
end

return setmetatable(pulse, pulse.mt)