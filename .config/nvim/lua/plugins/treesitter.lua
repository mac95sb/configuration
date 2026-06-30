return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = "all",
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
}
