--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'OXY2DEV/markview.nvim',
    lazy = false,
    opts = {
      preview = {
        filetypes = { 'markdown', 'codecompanion' },
        ignore_buftypes = {},
      },
      markdown = {
        code_blocks = {
          enable = true,
          style = 'language',
        },
      },
      latex = {
        enable = true,
        blocks = {
          enable = true,
        },
        inlines = {
          enable = true,
        },
      },
    },
  },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      direction = 'float',
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)
    end,
    keys = {
      {
        '<leader>ct',
        '<cmd>ToggleTerm direction=float<cr>',
        desc = 'Open a horizontal terminal at the current directory',
      },
    },
  },
}
