-- Run: nvim --headless -u NONE -l nvim/tests/sixel_transport.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
local original_system = vim.system
local original_chansend = vim.fn.chansend
local original_ui_send = vim.api.nvim_ui_send
local sixel = "\27P0;1;0q#1;2;100;0;0!20~\27\\"
local c1_sixel = "\155q!20~\156"
local kitty = "\27_Ga=d\27\\"

local function run()
    local function check(in_tmux, response, code, expected)
        local queries, raw, ui = 0, {}, {}
        vim.fn.chansend = function(channel, data)
            raw[#raw + 1] = { channel, data }
            return type(data) == "string" and #data or 0
        end
        vim.api.nvim_ui_send = function(data) ui[#ui + 1] = data end
        local tmux = {
            is_tmux = in_tmux,
            escape = function(data) return "wrapped:" .. data end,
        }
        package.loaded["image/utils/tmux"] = tmux
        package.loaded.sixel_transport = nil
        vim.system = function()
            queries = queries + 1
            return { wait = function() return { code = code, stdout = response } end }
        end
        local mod = require("sixel_transport")
        assert(mod.setup() == expected)
        assert(mod.setup() == expected, "setup is not idempotent")
        assert(queries == (in_tmux and 1 or 0), "capability queried repeatedly")
        assert(tmux.escape(sixel) == (expected and sixel or "wrapped:" .. sixel))
        assert(tmux.escape(c1_sixel) == (expected and c1_sixel or "wrapped:" .. c1_sixel))
        assert(tmux.escape(kitty) == "wrapped:" .. kitty, "non-Sixel transport was changed")
        assert(tmux.escape("\27P1$rstatus\27\\") == "wrapped:\27P1$rstatus\27\\")
        local packet = "\27[s\27[3;4H" .. tmux.escape(sixel) .. "\27[u"
        assert(vim.fn.chansend(vim.v.stderr, packet) == #packet)
        assert(#ui == 1 and ui[1] == packet and #raw == 0, "Sixel bypassed TUI output")
        vim.fn.chansend(vim.v.stderr, "ordinary stderr")
        vim.fn.chansend(vim.v.stderr, "")
        vim.fn.chansend(123, packet)
        vim.fn.chansend(vim.v.stderr, "\27[s\27[3;4H" .. kitty .. "\27[u")
        assert(#raw == 4 and #ui == 1, "non-Sixel channel write was intercepted")
    end
    check(true, "1\n", 0, true)
    check(true, "0\n", 0, false)
    check(true, "\n", 0, false)
    check(true, "1\n", 1, false)
    check(false, "1\n", 0, false)
    print("sixel_transport: TUI output routing, non-Sixel isolation, tmux detection and idempotence OK")
end

local ok, err = xpcall(run, debug.traceback)
vim.system = original_system
vim.fn.chansend = original_chansend
vim.api.nvim_ui_send = original_ui_send
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
