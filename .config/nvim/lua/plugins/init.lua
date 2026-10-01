return {
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function() require("config.theme").apply() end,
  },
  { "nvim-tree/nvim-web-devicons", opts = {} },
  {
    "echasnovski/mini.files",
    version = false,
    opts = {
      options = {
        use_as_default_explorer = true,
        permanent_delete = false,
      },
      windows = {
        preview = false,
        width_focus = 50,
        width_nofocus = 15,
      },
    },
    keys = {
      {
        "<leader>e",
        function() require("mini.files").open(vim.api.nvim_buf_get_name(0), false) end,
        desc = "File explorer",
      },
    },
  },
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 900,
    opts = {
      picker = {
        enabled = true,
        sources = { files = { hidden = true } },
      },
      input = { enabled = true },
      notifier = { enabled = true },
      bigfile = { enabled = true },
      quickfile = { enabled = true },
    },
    keys = {
      { "<leader><space>", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "Search project" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>gc", function() Snacks.picker.git_log() end, desc = "Git commits" },
      { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "File commits" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git status" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace symbols" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Workspace diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer diagnostics" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notifications" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git / GitHub" },
        { "<leader>s", group = "Search" },
        { "<leader>c", group = "Code" },
        { "<leader>u", group = "UI" },
        { "<leader>r", group = "PR review" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
    },
  },
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim", "nvim-tree/nvim-web-devicons" },
    opts = { picker = "snacks", enable_builtin = true },
    keys = {
      { "<leader>gp", "<cmd>Octo pr list<cr>", desc = "PRs (Snacks → Octo)" },
      { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "All GitHub PRs" },
      { "<leader>gi", "<cmd>Octo issue list<cr>", desc = "GitHub issues" },
      { "<leader>rs", "<cmd>Octo review start<cr>", desc = "Start PR review" },
      { "<leader>rr", "<cmd>Octo review resume<cr>", desc = "Resume PR review" },
      { "<leader>rc", "<cmd>Octo review comments<cr>", desc = "Review comments" },
      { "<leader>rd", "<cmd>Octo pr diff<cr>", desc = "PR diff" },
      { "<leader>rb", "<cmd>Octo pr browser<cr>", desc = "Open PR in browser" },
      { "<leader>rt", "<cmd>Octo review submit<cr>", desc = "Submit PR review" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "default" },
      completion = { documentation = { auto_show = true } },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      signature = { enabled = true },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      require("mason").setup()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.config("pyright", {
        settings = { python = { analysis = { typeCheckingMode = "basic" } } },
      })
      -- Ruff handles lint/fixes; Pyright handles types/navigation/hover.
      vim.lsp.config("ruff", {
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })
      require("mason-lspconfig").setup({
        ensure_installed = { "ts_ls", "pyright", "ruff" },
        automatic_enable = { "ts_ls", "pyright", "ruff" },
      })
      local sourcekit = vim.fn.system({ "xcrun", "--find", "sourcekit-lsp" }):gsub("%s+$", "")
      if vim.v.shell_error == 0 then
        vim.lsp.config("sourcekit", { cmd = { sourcekit } })
        vim.lsp.enable("sourcekit")
      end
      vim.diagnostic.config({ virtual_text = { spacing = 2 }, severity_sort = true, float = { border = "rounded" } })
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = event.buf, desc = desc })
          end
          map("gd", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("gr", function() Snacks.picker.lsp_references() end, "References")
          map("gI", function() Snacks.picker.lsp_implementations() end, "Implementations")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
        end,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        python = { "ruff_format" },
      },
      -- Explicit formatting only: avoid surprising changes during PR reviews.
      default_format_opts = { lsp_format = "fallback" },
    },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format code" },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = { ensure_installed = { "prettier" } },
  },
}
