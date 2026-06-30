return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls",           -- Lua
        "volar",            -- Vue (vue-language-server)
        "vtsls",            -- TypeScript / JS
        "emmet_ls",         -- Emmet (HTML/Vue templates)
        "html",             -- HTML
        "cssls",            -- CSS
        "pyright",          -- Python
        "tailwindcss",      -- Tailwind CSS
        "marksman",         -- Markdown
      },
      automatic_installation = false,
    },
  },
}
