--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'olimorris/codecompanion.nvim',
    version = '^18.0.0',
    opts = {
      adapters = {
        acp = {
          gemini_cli = function()
            return require('codecompanion.adapters').extend('gemini_cli', {
              env = {
                GEMINI_MODEL = 'gemini-3-flash-preview',
              },
              commands = {
                default = {
                  'gemini',
                  '--experimental-acp',
                },
              },
              defaults = {
                auth_method = 'oauth-personal',
                oauth_credentials_path = vim.fn.expand '~/.gemini/oauth_creds.json',
              },
              handlers = {
                auth = function(self)
                  local creds = self.defaults.oauth_credentials_path
                  return (creds and vim.fn.filereadable(creds)) == 1
                end,
              },
            })
          end,
        },
        http = {
          gemini = function()
            return require('codecompanion.adapters').extend('gemini', {
              url = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions?key=${api_key}',
              schema = {
                model = {
                  default = 'gemini-2.5-flash',
                },
              },
              env = {
                api_key = 'GEMINI_API_KEY',
              },
            })
          end,
        },
      },
      display = {
        chat = {
          window = {
            layout = 'float',
          },
        },
      },
      extensions = {
        spinner = {
          opts = {
            style = 'native',
            native = {
              done_timer = 1000,
              window = {
                relative = 'editor',
                width = 30,
                height = 1,
                row = vim.o.lines - 5,
                col = vim.o.columns - 35,
                style = 'minimal',
                border = 'rounded',
                title = 'CodeCompanion',
                title_pos = 'center',
                focusable = false,
                noautocmd = true,
              },
            },
          },
        },
      },
      strategies = {
        chat = { adapter = 'gemini_cli' },
        inline = { adapter = 'gemini' },
        cmd = { adapter = 'gemini' },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'lalitmee/codecompanion-spinners.nvim',
    },
    keys = {
      {
        '<leader>cc',
        '<cmd>CodeCompanionChat Toggle<cr>',
        desc = 'CodeCompanionChat Toggle',
      },
      {
        '<leader>ca',
        '<cmd>CodeCompanionActions<cr>',
        mode = { 'n', 'v' },
        desc = 'CodeCompanion Actions',
      },
      {
        '<leader>ci',
        '<cmd>CodeCompanion<cr>',
        mode = { 'n', 'v' },
        desc = 'CodeCompanion Inline',
      },
    },
  },
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
