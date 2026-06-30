return {
  {
    "lmilojevicc/herdr-splits.nvim",
    cond = vim.env.HERDR_ENV == "1",
    event = "VeryLazy",
    config = function()
      require("herdr-splits").setup({
        default_amount    = 0.03,
        neovim_amount     = 3,
        at_edge           = "wrap",
        ignored_buftypes  = { "nofile", "quickfix", "prompt" },
        ignored_filetypes = { "NvimTree" },
        move_cursor_same_row = false,
      })
    end,
    keys = {
      { "<M-h>", function() require("herdr-splits").move_cursor_left() end,  desc = "Move left" },
      { "<M-j>", function() require("herdr-splits").move_cursor_down() end,  desc = "Move down" },
      { "<M-k>", function() require("herdr-splits").move_cursor_up() end,    desc = "Move up" },
      { "<M-l>", function() require("herdr-splits").move_cursor_right() end, desc = "Move right" },
      { "<M-H>", function() require("herdr-splits").resize_left() end,       desc = "Resize left" },
      { "<M-J>", function() require("herdr-splits").resize_down() end,       desc = "Resize down" },
      { "<M-K>", function() require("herdr-splits").resize_up() end,         desc = "Resize up" },
      { "<M-L>", function() require("herdr-splits").resize_right() end,      desc = "Resize right" },
    },
  },
}
