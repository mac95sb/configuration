return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose", "DiffviewToggleFiles" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",             desc = "Diff working tree" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",    desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",      desc = "Repo history" },
      { "<leader>gc", "<cmd>DiffviewClose<cr>",            desc = "Close diffview" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = "diff2_horizontal" },
        merge_tool = { layout = "diff3_horizontal", disable_diagnostics = true },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 35 },
      },
    },
  },
}
