-- Hyper-V: keep 30 Hz and disable costly rendering.
hl.monitor({ output = "Virtual-1", mode = "2560x1440@30", position = "auto", scale = "1" })
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    for _, command in ipairs({
        "fcitx5",
        "waybar",
        -- PSK stays outside Git but is still visible in process arguments.
        [[psk=; { IFS= read -r psk || [ -n "$psk" ]; } < "$HOME/.config/p2p-clipboard/psk" || exit; psk=${psk%"$(printf '\r')"}; [ -n "$psk" ] && exec "$HOME/.local/bin/p2p-clipboard" --psk "$psk"]],
        [[swaybg -i "$HOME/windows-11-blue-ub.jpg" -m fill]],
    }) do
        hl.exec_cmd(command)
    end
end)

-- Equal-width tiles; float windows for manual sizing.
hl.layout.register("columns", {
    recalculate = function(ctx)
        for i, target in ipairs(ctx.targets) do
            target:place(ctx:column(i, #ctx.targets))
        end
    end,
})

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 5,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "lua:columns",
    },
    decoration = {
        rounding = 5,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = false },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
    input = { kb_layout = "us", follow_mouse = 1, sensitivity = 0 },
})

local dsp = hl.dsp
local function bind(key, action, options)
    hl.bind("SUPER + " .. key, action, options)
end

bind("RETURN", dsp.exec_cmd("foot"))
bind("W", dsp.exec_cmd("chromium"))
bind("Q", dsp.window.close())
bind("F", dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("V", dsp.window.float({ action = "toggle" }))
for key, direction in pairs({ H = "l", L = "r" }) do
    bind(key, dsp.focus({ direction = direction }))
    bind("SHIFT + " .. key, dsp.window.swap({ direction = direction }))
end
for i = 1, 10 do
    bind(i % 10, dsp.focus({ workspace = i }))
    bind("SHIFT + " .. i % 10, dsp.window.move({ workspace = i }))
end
bind("mouse:272", dsp.window.drag(), { mouse = true })
bind("mouse:273", dsp.window.resize(), { mouse = true })

for key, command in pairs({
    RaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    LowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    Mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    MicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    Next = "playerctl next",
    Pause = "playerctl play-pause",
    Play = "playerctl play-pause",
    Prev = "playerctl previous",
}) do
    hl.bind("XF86Audio" .. key, dsp.exec_cmd(command), {
        locked = true,
        repeating = key == "RaiseVolume" or key == "LowerVolume",
    })
end

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})
