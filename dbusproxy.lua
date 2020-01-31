local setmetatable = setmetatable
local lgi = require 'lgi'
local GLib, Gio = lgi.GLib, lgi.Gio
local DBusProxy = Gio.DBusProxy
local DBusProxyFlags = Gio.DBusProxyFlags
local DBusInterfaceInfo = Gio.DBusInterfaceInfo
local DBusCallFlags = Gio.DBusCallFlags
local Variant = GLib.Variant

local proxy = { mt = {} }

function proxy:connect()
    local p, err = DBusProxy.new_sync(
                self._private.bus,
                DBusProxyFlags.NONE,
                DBusInterfaceInfo({name = self._private.interface}),
                self._private.name,
                self._private.path,
                self._private.interface)
    self._private.proxy = p
end

function proxy:get_path()
    return self._private.path
end

function proxy:get(name)
    return self._private.proxy:get_cached_property(name).value
end

function proxy:get_property(interface, name)
    return self:call(
        "org.freedesktop.DBus.Properties",
        "Get",
        Variant('(ss)',{interface, name})
    ).value
end

function proxy:set_property(interface, name, params)
    self:call(
        "org.freedesktop.DBus.Properties",
        "Set",
        Variant('(ssv)',{interface, name, params})
    )
end

function proxy:call(interface, method, params)
    return self._private.proxy:call_sync(
        (interface or self._private.interface) .. "." .. method,
        params,
        DBusCallFlags.NONE,
        -1
    )
end

function proxy:on_signal(callback)
    self._private.proxy.on_g_signal = callback
end

function proxy:on_properties_changed(callback)
    self._private.proxy.on_g_properties_changed = callback
end

local function new(args)
    local p = { _private = {} }

    p._private.bus = args.bus
    p._private.interface = args.interface
    p._private.name = args.name
    p._private.path = args.path

    setmetatable(p, {__index = proxy})

    return p
end

function proxy.mt:__call(...)
    return new(...)
end

return setmetatable(proxy, proxy.mt)