--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'olimorris/codecompanion.nvim',
    version = '^18.0.0',
    opts = {
      strategies = {
        chat = { adapter = 'gemini_cli' },
        cmd = { adapter = 'gemini' },
      },
      display = {
        chat = {
          window = {
            layout = 'float',
          },
        },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    keys = {
      { '<leader>cc', '<cmd>CodeCompanionChat Toggle<cr>', desc = 'CodeCompanionChat Toggle' },
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
