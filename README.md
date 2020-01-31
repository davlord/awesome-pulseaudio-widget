# awesome-pulseaudio-widget
A pulseaudio volume control widget for Awesome WM

![awesome-pulseaudio-widget screenshot](awesome-pulseaudio-widget.png)

## features

* Lightweight (no constant polling but event based updates)
* Support multiple sinks
* Volume/Mute control
* Does not fail if pulseaudio is not up yet

## install

1.Clone in your config directory (`~/.config/awesome/`)
```bash
cd ~/.config/awesome/
git clone https://github.com/davlord/awesome-pulseaudio-widget.git
```

2.Add to your wibar widgets (`~/.config/awesome/rc.lua`)

```lua
local audio_widget = require("awesome-pulseaudio-widget")

-- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            audio_widget(),
            wibox.widget.systray(),
            mytextclock,
            s.mylayoutbox,
        },
    }
```
3. Reload Awesome WM