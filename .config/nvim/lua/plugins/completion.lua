return {
  {
    "saghen/blink.cmp",
    version = "*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "ripgrep" },
        providers = {
          ripgrep = {
            module = "blink-ripgrep",
            name = "Ripgrep",
            score_offset = -3,
          },
        },
      },
      completion = {
        documentation = { auto_show = false },
      },
      signature = { enabled = true, window = { show_documentation = false } },
      fuzzy = { implementation = "lua" },
    },
  },

  {
    "mikavilpas/blink-ripgrep.nvim",
    lazy = true,
  },
}
