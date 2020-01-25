local lgi = require 'lgi'

local icon_theme = lgi.Gtk.IconTheme.get_default()
local IconLookupFlags = lgi.Gtk.IconLookupFlags

local iconhelper = {}

local function lookup_icon(name)
    return icon_theme:lookup_icon(name, 64, {IconLookupFlags.GENERIC_FALLBACK})
end

local icon = {
    high = lookup_icon("audio-volume-high-symbolic"),
    medium = lookup_icon("audio-volume-medium-symbolic"),
    low = lookup_icon("audio-volume-low-symbolic"),
    muted = lookup_icon("audio-volume-muted-symbolic"),
}

function iconhelper.get_icon(state)
    if state.muted then return icon.muted end
    if state.volume <= 33 then return icon.low end
    if state.volume <= 66 then return icon.medium end
    return icon.high
end

return iconhelper