-- PTY fixture for sixel_flush.py. Real image.nvim/TUI/transform/flush code;
-- TUI output is captured by the private PTY rather than shown as graphics.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
dofile(root .. "/init.lua")
vim.api.nvim_del_augroup_by_name("sixel_math_popup")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Preview test", "", "$x^2$" })
vim.bo.filetype = "markdown"
local api = require("image")
local state
for i = 1, 10 do
    local name, value = debug.getupvalue(api.get_images, i)
    if name == "state" then state = value; break end
end
assert(state, "image.nvim state layout changed; update regression fixture")
assert(state.options.window_overlap_clear_enabled == false, "Sixel overlap polling must remain disabled")
-- Replay the old setting in an isolated Neovim process for the control case.
if vim.env.TEST_OVERLAP == "1" then state.options.window_overlap_clear_enabled = true end
require("image/utils/term").get_size = function()
    return { screen_cols = 104, screen_rows = 20, cell_width = 8, cell_height = 16, screen_x = 832, screen_y = 320 }
end
local renders, sends = 0, 0
local backend = require("image/backends/sixel")
local render = backend.render
backend.render = function(...)
    renders = renders + 1
    return render(...)
end
local send = vim.api.nvim_ui_send
vim.api.nvim_ui_send = function(data)
    sends = sends + 1
    return send(data)
end
vim.defer_fn(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "math_popup"
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor", row = 2, col = 2, width = 20, height = 4, style = "minimal", noautocmd = true,
    })
    local image = api.from_file(vim.env.TEST_PNG, { id = "flush-test", window = win, buffer = buf })
    image:render({ x = 0, y = 0, width = 20, height = 4 })
    -- Simulate redraw activity while the Sixel backend is waiting to flush.
    for delay = 10, 500, 10 do vim.defer_fn(function() vim.cmd("redraw!") end, delay) end
    local checkpoint
    vim.defer_fn(function()
        checkpoint = { sends = sends, renders = renders, painted = image.is_rendered }
    end, 300)
    vim.defer_fn(function()
        vim.fn.writefile({ vim.json.encode({ checkpoint = checkpoint, sends = sends, renders = renders }) }, vim.env.TEST_RESULT)
        vim.cmd("qa!")
    end, 700)
end, 100)
