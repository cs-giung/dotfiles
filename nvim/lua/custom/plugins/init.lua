--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'olimorris/codecompanion.nvim',
    version = '^18.0.0',
    opts = {
      adapters = {
        http = {
          gemini = function()
            return require('codecompanion.adapters').extend('gemini', {
              schema = {
                model = {
                  default = 'gemini-2.5-flash-lite',
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
              -- How long (in ms) the "Done!" message should remain visible after completion.
              done_timer = 1000,

              -- Window configuration - all nvim_open_win options are supported
              window = {
                -- Position and size
                relative = 'editor', -- "editor", "win", "cursor"
                width = 30, -- Window width in characters
                height = 1, -- Window height in lines
                row = vim.o.lines - 5, -- Row position (from top)
                col = vim.o.columns - 35, -- Column position (from left)

                -- Appearance
                style = 'minimal', -- Window style
                border = 'rounded', -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
                title = 'CodeCompanion', -- Window title text
                title_pos = 'center', -- Title position: "left", "center", "right"

                -- Behavior
                focusable = false, -- Whether window can receive focus
                noautocmd = true, -- Disable autocmds for performance
              },

              -- Additional window options using nvim_set_option_value
              win_options = {
                -- winblend = 10,           -- Window transparency (0-100)
                -- winhighlight = "Normal:Normal,FloatBorder:Normal", -- Custom highlighting
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
  --- {
  ---   'mozanunal/sllm.nvim',
  ---   dependencies = {
  ---     'echasnovski/mini.notify',
  ---     'echasnovski/mini.pick',
  ---   },
  ---   config = function()
  ---     require('sllm').setup {
  ---       llm_cmd = 'llm',
  ---       default_model = 'gemini-2.5-flash',
  ---       show_usage = true,
  ---       on_start_new_chat = true,
  ---       reset_ctx_each_prompt = true,
  ---       window_type = 'vertical',
  ---       pick_func = require('mini.pick').ui_select,
  ---       notify_func = require('mini.notify').make_notify(),
  ---       input_func = vim.ui.input,
  ---       keymaps = {
  ---         ask_llm = '<leader>as',
  ---         new_chat = '<leader>an',
  ---         cancel = '<leader>ac',
  ---         focus_llm_buffer = '<leader>af',
  ---         toggle_llm_buffer = '<leader>at',
  ---         select_model = '<leader>am',
  ---         add_file_to_ctx = '<leader>aa',
  ---         add_url_to_ctx = '<leader>au',
  ---         add_sel_to_ctx = '<leader>av',
  ---         add_cmd_out_to_ctx = '<leader>ax',
  ---         reset_context = '<leader>ar',
  ---       },
  ---     }
  ---   end,
  --- },
}
