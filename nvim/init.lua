vim.g.mapleader = " "
vim.opt.clipboard = "unnamedplus"
vim.opt.colorcolumn = "80,100,120"
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("tex_manual_indent", { clear = true }),
    desc = "Disable automatic indentation in TeX buffers",
    pattern = { "tex", "plaintex" },
    callback = function()
        vim.opt_local.autoindent = false
        vim.opt_local.smartindent = false
        vim.opt_local.cindent = false
        vim.opt_local.indentexpr = ""
    end,
})

for group, style in pairs({
    Normal = { bg = "none" },
    NormalFloat = { bg = "none" },
    FloatTitle = { fg = "#606060", bg = "none" },
    FloatBorder = { fg = "#606060", bg = "none" },
    VirtColumn = { fg = "#404040" },
}) do
    vim.api.nvim_set_hl(0, group, style)
end

vim.pack.add({
    "https://github.com/folke/snacks.nvim",
    "https://github.com/folke/which-key.nvim",
    "https://github.com/3rd/image.nvim",
    "https://github.com/lewis6991/gitsigns.nvim",
    "https://github.com/pablopunk/pi.nvim",
    "https://github.com/lukas-reineke/indent-blankline.nvim",
    "https://github.com/lukas-reineke/virt-column.nvim",
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/MunifTanjim/nui.nvim",
    "https://github.com/nvim-tree/nvim-web-devicons",
    "https://github.com/mfussenegger/nvim-lint",
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/OXY2DEV/markview.nvim",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range("3") },
}, { load = true })

require("conform").setup({
    formatters_by_ft = {
        bib = { "bibtex-tidy" },
    },
    format_on_save = {
        timeout_ms = 2000,
        lsp_format = "never",
    },
})

local map = vim.keymap.set

local which_key = require("which-key")
which_key.setup({
    delay = 300,
    win = { border = "rounded" },
    spec = {
        { "<leader>a", group = "AI", mode = { "n", "v" } },
        { "<leader>f", group = "Find", mode = { "n", "x" } },
        { "<leader>m", group = "Markdown" },
    },
})
map("n", "<leader>?", function()
    which_key.show({ keys = "<leader>" })
end, { desc = "Show leader keymaps" })

-- Missing parsers are installed asynchronously; requires tree-sitter CLI and a C compiler.
require("nvim-treesitter").install({ "markdown", "markdown_inline", "latex" })

require("markview").setup({
    preview = {
        icon_provider = "devicons",
    },
})
map("n", "<leader>mp", "<cmd>Markview toggle<cr>", { desc = "Toggle Markdown preview" })
map("n", "<leader>ms", "<cmd>Markview splitToggle<cr>", { desc = "Toggle Markdown split preview" })

local snacks = require("snacks")
snacks.setup({
    input = { enabled = true },
    picker = { enabled = true },
    -- Keep one image-file handler and one graphics protocol (image.nvim/Sixel).
    image = { enabled = false },
})
require("sixel_transport").setup()
require("image").setup({
    backend = "sixel",
    processor = "magick_cli",
    -- Overlap polling requeues unpainted Sixel frames and can starve its flush timer.
    window_overlap_clear_enabled = false,
    tmux_show_only_in_active_window = true,
    integrations = {
        markdown = {
            enabled = true,
            download_remote_images = true,
            only_render_image_at_cursor = true,
            only_render_image_at_cursor_mode = "popup",
            clear_in_insert_mode = true,
        },
        asciidoc = { enabled = false },
        neorg = { enabled = false },
        rst = { enabled = false },
        typst = { enabled = false },
        syslang = { enabled = false },
        org = { enabled = false },
        html = { enabled = false },
        css = { enabled = false },
    },
})
require("math_popup").setup()
require("preview_debug").setup()

for _, binding in ipairs({
    { "<leader><space>", "smart", "Smart find" },
    { "<leader>ff", "files", "Find files" },
    { "<leader>/", "grep", "Grep" },
    { "<leader>,", "buffers", "Buffers" },
    { "<leader>fw", "grep_word", "Find word", { "n", "x" } },
}) do
    map(binding[4] or "n", binding[1], function()
        snacks.picker[binding[2]]()
    end, { desc = binding[3] })
end

require("gitsigns").setup()
require("pi").setup({
    provider = "openai",
    model = "gpt-6-luna",
    thinking = "off",
    skills = false,
    extensions = false,
})
map("n", "<leader>ai", "<cmd>PiAsk<cr>", { desc = "Ask pi" })
map("v", "<leader>ai", "<cmd>PiAskSelection<cr>", { desc = "Ask pi (selection)" })

local rainbow = {
    { "RainbowRed", "#E06C75" },
    { "RainbowYellow", "#E5C07B" },
    { "RainbowBlue", "#61AFEF" },
    { "RainbowOrange", "#D19A66" },
    { "RainbowGreen", "#98C379" },
    { "RainbowViolet", "#C678DD" },
    { "RainbowCyan", "#56B6C2" },
}
local hooks = require("ibl.hooks")
hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
    for _, color in ipairs(rainbow) do
        vim.api.nvim_set_hl(0, color[1], { fg = color[2] })
    end
end)
require("ibl").setup({ indent = {
    char = "|",
    highlight = vim.tbl_map(function(color) return color[1] end, rainbow),
} })
require("virt-column").setup({ char = "|", highlight = "VirtColumn" })

local function copy_path(state)
    local node = state.tree:get_node()
    if not node or not node.id then
        vim.notify("No node selected.", vim.log.levels.WARN)
        return
    end
    local path = node:get_id()
    vim.ui.select({
        { "Absolute path", path },
        { "Path relative to CWD", vim.fn.fnamemodify(path, ":.") },
        { "Path relative to HOME", vim.fn.fnamemodify(path, ":~") },
        { "Filename", node.name },
    }, {
        prompt = "Choose a path to copy:",
        format_item = function(item) return string.format("%-30s %s", item[1], item[2]) end,
    }, function(choice)
        if choice then
            vim.fn.setreg("+", choice[2])
            vim.notify("Copied to clipboard: " .. choice[2])
        end
    end)
end

require("neo-tree").setup({
    popup_border_style = "rounded",
    filesystem = { window = {
        position = "float",
        popup = {
            size = { height = "80%", width = "80%" },
            position = "50%",
            border = "rounded",
        },
        mappings = { ["\\"] = "close_window", Y = copy_path },
    } },
})
map("n", "\\", "<cmd>Neotree reveal<cr>", { desc = "NeoTree reveal", silent = true })

local lint = require("lint")

lint.linters.chktex.ignore_exitcode = true
lint.linters_by_ft = {
    tex = { "chktex" },
    plaintex = { "chktex" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("tex_lint", { clear = true }),
    pattern = "*.tex",
    callback = function()
        lint.try_lint()
    end,
})

vim.diagnostic.config({
    severity_sort = true,
    float = {
        border = "rounded",
        source = true,
        header = { " Diagnostics ", "FloatTitle" },
        prefix = " ",
    },
})

map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })
