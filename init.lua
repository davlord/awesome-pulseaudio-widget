local setmetatable = setmetatable
local lgi = require 'lgi'
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local iconhelper = require("awesome-pulseaudio-widget.iconhelper")
local pulseaudio = require("awesome-pulseaudio-widget.pulseaudio")

local pulseaudio_widget = { mt = {} }

local pulse_client = nil

function pulseaudio_widget:update_icon(state)
    self.imagebox:set_image(iconhelper.get_icon(state):load_surface())
end

function pulseaudio_widget:update_text()
end

function pulseaudio_widget:update_tooltip()
end

function pulseaudio_widget:update(state)
    self:update_icon(state)
    self:update_text()
    self:update_tooltip()
end

local function new(args)
    local w = wibox.widget {
        layout = wibox.layout.fixed.horizontal,
        spacing = 2,
        {
            id = "imagebox",
            widget = wibox.widget.imagebox,
            resize = true,
        },
        {
            id = "textbox",
            widget = wibox.widget.textbox,
        }        
    }

    w.tooltip = awful.tooltip({ objects = { w },})

    gears.table.crush(w, pulseaudio_widget, true)

    pulse_client = pulseaudio()
    pulse_client:on_change(function(pulse_state) w:update(pulse_state) end)
    pulse_client:connect()

    -- todo get current state from pulseaudio
    w:update({})

    return w
end

function pulseaudio_widget.mt:__call(...)
    return new(...)
end

return setmetatable(pulseaudio_widget, pulseaudio_widget.mt)