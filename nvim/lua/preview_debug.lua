-- Opt-in diagnostics: do not keep verbose image logs running by default.
local M = {}
local path = vim.fn.stdpath("cache") .. "/document-preview.log"

function M.start()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({
        "Document preview diagnostic session: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Neovim: " .. tostring(vim.version()),
        "TERM=" .. (vim.env.TERM or "") .. " TMUX=" .. tostring(vim.env.TMUX ~= nil),
        "Screen: " .. vim.o.columns .. "x" .. vim.o.lines,
        "Native tmux Sixel transport: " .. tostring(require("sixel_transport").setup()),
    }, path)
    vim.g.preview_debug_log = path
    require("image/utils/logger").setup({
        enabled = true,
        level = "debug",
        file_path = path,
        format = "detailed",
    })
    vim.notify("Preview logging started: " .. path)
end

function M.stop()
    vim.g.preview_debug_log = nil
    require("image/utils/logger").setup({ enabled = false })
    vim.notify("Preview logging stopped: " .. path)
end

function M.setup()
    vim.api.nvim_create_user_command("PreviewDebugStart", M.start, {
        desc = "Start a fresh document-preview diagnostic log",
        force = true,
    })
    vim.api.nvim_create_user_command("PreviewDebugStop", M.stop, {
        desc = "Stop document-preview diagnostic logging",
        force = true,
    })
end

return M
