return {
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      -- Icons
      require("mini.icons").setup()

      -- Git integration
      require("mini.git").setup()

      -- File explorer
      require("mini.files").setup()

      -- Extra pickers / utilities
      require("mini.extra").setup()

      -- Git diff signs
      require("mini.diff").setup({
        view = {
          style = "sign",
          signs = { add = "┃", change = "┃", delete = "" },
        },
        source = require("mini.diff").gen_source.git(),
        mappings = {
          apply = "gh",
          reset = "gH",
          textobject = "ih",
          goto_first = "[H",
          goto_prev  = "[h",
          goto_next  = "]h",
          goto_last  = "]H",
        },
      })

      -- Which-key style hints
      local clue = require("mini.clue")
      clue.setup({
        window = {
          delay     = 200,
          config    = { border = "rounded" },
        },
        triggers = {
          { mode = "n", keys = "<leader>" },
          { mode = "x", keys = "<leader>" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "'" },
          { mode = "n", keys = "`" },
          { mode = "n", keys = '"' },
          { mode = "i", keys = "<C-x>" },
          { mode = "n", keys = "<C-w>" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
        },
        clues = {
          clue.gen_clues.builtin_completion(),
          clue.gen_clues.g(),
          clue.gen_clues.marks(),
          clue.gen_clues.registers(),
          clue.gen_clues.windows(),
          clue.gen_clues.z(),
          -- Group labels
          { mode = "n", keys = "<leader>b",  desc = "+Buffer" },
          { mode = "n", keys = "<leader>t",  desc = "+Tab" },
          { mode = "n", keys = "<leader>f",  desc = "+Find" },
          { mode = "n", keys = "<leader>ca", desc = "+Code action" },
          { mode = "n", keys = "<leader>af", desc = "+Format" },
          { mode = "n", keys = "<leader>g",  desc = "+Git" },
        },
      })

      -- Fuzzy finder
      require("mini.pick").setup({
        window = { config = { border = "rounded" } },
      })

      -- keymaps for pick
      local map = vim.keymap.set
      local pick = require("mini.pick")
      local extra = require("mini.extra")
      map("n", "<leader>ff", function() pick.builtin.files() end,           { desc = "Find files" })
      map("n", "<leader>fb", function() pick.builtin.buffers() end,         { desc = "Find buffers" })
      map("n", "<leader>f/", function() pick.builtin.grep_live() end,       { desc = "Live grep" })
      map("n", "<leader>fh", function() pick.builtin.help() end,            { desc = "Help" })
      map("n", "<leader>fm", function()
        extra.pickers.marks({ scope = "global" })
      end, { desc = "Marks" })
      map("n", "<leader>e", function() require("mini.files").open() end, { desc = "File explorer" })

      -- Statusline
      require("mini.statusline").setup({
        content = {
          active = function()
            local sl = require("mini.statusline")
            local mode, mode_hl = sl.section_mode({ trunc_width = 120 })
            local git          = sl.section_git({ trunc_width = 75 })
            local diagnostics  = sl.section_diagnostics({ trunc_width = 75 })
            local filename     = sl.section_filename({ trunc_width = 140 })
            local fileinfo     = sl.section_fileinfo({ trunc_width = 120 })
            local location     = sl.section_location({ trunc_width = 75 })
            return sl.combine_groups({
              { hl = mode_hl,              strings = { mode } },
              { hl = "MiniStatuslineDevinfo", strings = { git, diagnostics } },
              "%<",
              { hl = "MiniStatuslineFilename", strings = { filename } },
              "%=",
              { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
              { hl = mode_hl,              strings = { location } },
            })
          end,
          inactive = function()
            local sl = require("mini.statusline")
            local filename = sl.section_filename({ trunc_width = 140 })
            return sl.combine_groups({
              { hl = "MiniStatuslineFilename", strings = { filename } },
            })
          end,
        },
      })
    end,
  },
}
