vim.g.mapleader = " "

vim.opt.clipboard = "unnamedplus"
vim.opt.colorcolumn = '80,100,120'

vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "FloatTitle", { fg = "#606060", bg = "none" })
vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#606060", bg = "none" })
vim.api.nvim_set_hl(0, "VirtColumn", { fg = "#404040" })

vim.pack.add({
    { src = "https://github.com/folke/snacks.nvim" },
})
require("snacks").setup({
    input = { enabled = true },
    picker = { enabled = true },
})

vim.pack.add({
    { src = "https://github.com/pablopunk/pi.nvim" },
}, { load = true })
require("pi").setup({
    provider = "openai-codex",
    model = "gpt-5.6-luna",
    thinking = "off",
    skills = false,
    extensions = false,
})
vim.keymap.set("n", "<leader>ai", "<cmd>PiAsk<cr>", { desc = "Ask pi" })
vim.keymap.set("v", "<leader>ai", "<cmd>PiAskSelection<cr>", { desc = "Ask pi (selection)" })

vim.pack.add({
    "https://github.com/lukas-reineke/indent-blankline.nvim",
    "https://github.com/lukas-reineke/virt-column.nvim",
})
local highlight = {
    "RainbowRed",
    "RainbowYellow",
    "RainbowBlue",
    "RainbowOrange",
    "RainbowGreen",
    "RainbowViolet",
    "RainbowCyan",
}
local hooks = require "ibl.hooks"
hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
    vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
    vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
    vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
    vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
    vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
    vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
end)
require("ibl").setup({ indent = { char = "|", highlight = highlight }})
require("virt-column").setup({ char = "|", highlight = "VirtColumn" })

vim.pack.add({
    {
        src = "https://github.com/nvim-neo-tree/neo-tree.nvim",
	version = vim.version.range("3"),
    },
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/MunifTanjim/nui.nvim",
    "https://github.com/nvim-tree/nvim-web-devicons",
})
require("neo-tree").setup({
    popup_border_style = "rounded",
    filesystem = {
        window = {
	    position = "float",
	    popup = {
	        size = {
		    height = "80%",
		    width = "80%",
		},
		position = "50%",
		border = "rounded",
	    },
	    mappings = {
	        ["\\"] = "close_window",
		["Y"] = function(state)
		    local node = state.tree:get_node()
		    if not node or not node.id then
		        vim.notify("No node selected.", vim.log.levels.WARN)
			return
		    end
		    local filepath = node:get_id()
		    local filename = node.name
		    local modify = vim.fn.fnamemodify
		    local choices = {
		        { label = "Absolute path", value = filepath },
			{ label = "Path relative to CWD", value = modify(filepath, ":.") },
			{ label = "Path relative to HOME", value = modify(filepath, ":~") },
			{ label = "Filename", value = filename },
		    }
		    vim.ui.select(choices, {
		        prompt = "Choose to copy to clipboard:",
			format_item = function(item)
			    return string.format("%-30s %s", item.label, item.value)
			end,
		    }, function(choice)
		        if not choice then
			    return
			end
			vim.fn.setreg("+", choice.value)
			vim.notify("Copied to clipboard: " .. choice.value)
		    end)
		end,
	    },
	},
    },
})
vim.keymap.set("n", "\\", "<cmd>Neotree reveal<cr>", { desc = "NeoTree reveal", silent = true })
