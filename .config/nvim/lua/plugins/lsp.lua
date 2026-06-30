return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "folke/lazydev.nvim",
      { "saghen/blink.cmp" },
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.diagnostic.config({
        virtual_text = { prefix = "●", source = "if_many", spacing = 4 },
        signs = false,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_inlay_hints", { clear = true }),
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          end
        end,
      })

      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.enable({ "lua_ls", "volar", "vtsls", "emmet_ls", "html", "cssls", "pyright", "tailwindcss", "marksman" })
    end,
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        vue = { "prettier" },
      },
      format_on_save = function(bufnr)
        if vim.b[bufnr].format_on_save == false then return end
        return { timeout_ms = 500, lsp_fallback = true }
      end,
    },
  },
}
