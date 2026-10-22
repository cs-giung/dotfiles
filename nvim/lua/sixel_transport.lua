-- Compatibility for image.nvim's Sixel backend on Neovim 0.12:
-- route terminal bytes through the TUI, and use native tmux Sixel when available.
local M = {}
local configured = false
local native = false

local function install_ui_sender()
    if not vim.api.nvim_ui_send then return end
    local send = vim.fn.chansend
    vim.fn.chansend = function(channel, data)
        -- Only intercept image.nvim's complete save-cursor/CUP/Sixel/restore
        -- packet, not arbitrary stderr, Kitty data, or other channel writes.
        local is_sixel = type(data) == "string"
            and data:match("^\27%[s\27%[%d+;%d+H")
            and data:sub(-3) == "\27[u"
            and (data:find("\27P[0-?]*q") or data:find("\155[0-?]*q"))
        if channel == vim.v.stderr and is_sixel then
            -- :h nvim_ui_send explicitly requires this instead of raw channel
            -- writes to the terminal. This keeps graphics in the TUI stream.
            vim.api.nvim_ui_send(data)
            if vim.g.preview_debug_log then
                vim.fn.writefile({ os.date("%H:%M:%S") .. " [sixel-transport] ui_send bytes=" .. #data },
                    vim.g.preview_debug_log, "a")
            end
            return #data
        end
        return send(channel, data)
    end
end

function M.setup()
    if configured then return native end
    configured = true
    install_ui_sender()
    local tmux = require("image/utils/tmux")
    if not tmux.is_tmux then return false end
    local ok, result = pcall(function()
        return vim.system({ "tmux", "display-message", "-p", "#{sixel_support}" }, {
            text = true,
            timeout = 2000,
        }):wait()
    end)
    if not ok or result.code ~= 0 or vim.trim(result.stdout or "") ~= "1" then return false end

    local escape = tmux.escape
    tmux.escape = function(sequence)
        -- Only change Sixel transport. Leave Kitty/other escape sequences alone.
        if sequence:match("^\27P[0-?]*q") or sequence:match("^\155[0-?]*q") then
            return sequence
        end
        return escape(sequence)
    end
    native = true
    return true
end

return M
