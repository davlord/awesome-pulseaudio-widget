local setmetatable = setmetatable
local lgi = require 'lgi'
local GLib, Gio = lgi.GLib, lgi.Gio
local DBusProxy = Gio.DBusProxy
local BusType = Gio.BusType
local DBusConnection = Gio.DBusConnection
local DBusConnectionFlags = Gio.DBusConnectionFlags
local Variant = GLib.Variant

local dbus_proxy = require("awesome-pulseaudio-widget.dbusproxy")

local pulse = { mt = {} }

local function get_connection()
    local session_bus = Gio.bus_get_sync(BusType.SESSION)

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

local function listen_core_events(connection, core, on_change)
    local sinks = core:get("Sinks")

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
    
    local device = dbus_proxy({
            bus=connection,
            interface="org.PulseAudio.Core1.Device",
            name=nil,
            path=sinks[1]
    })
    device:connect()

    local function notify()
        
        local muted = device:get_property("org.PulseAudio.Core1.Device","Mute")[1].value
        local volume = device:get_property("org.PulseAudio.Core1.Device","Volume")[1].value

        local audio_state = {
            muted = muted,
            volume = volume
        }

        on_change(audio_state) 
    end

    device:on_signal(notify)
    device:on_properties_changed(notify)
end

function pulse:on_change(callback)
    self._private.on_change = callback
end

function pulse:connect()
    local connection = get_connection()
    local core = get_core(connection)
    listen_core_events(connection, core, self._private.on_change)
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