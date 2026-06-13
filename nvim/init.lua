vim.loader.enable()

-- ––– Leaders –––
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

-- ––– Options –––
local opt = vim.opt

-- UI
opt.number         = true
opt.relativenumber = true
opt.wrap           = false
opt.scrolloff      = 10
opt.signcolumn     = "yes"
opt.cursorline     = true
opt.showmode       = false
opt.ruler          = false
opt.showcmd        = false
opt.cmdheight      = 0
opt.laststatus     = 2
opt.pumheight      = 10
opt.pumborder      = "rounded"

-- Indentation
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.softtabstop = 2
opt.expandtab   = true
opt.smartindent = true

-- Search & behaviour
opt.ignorecase  = true
opt.smartcase   = true
opt.undofile    = true
opt.updatetime  = 300
opt.timeoutlen  = 500
opt.completeopt = "menu,menuone,noselect"
opt.splitright  = true
opt.splitbelow  = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"

-- ––– Plugins –––
vim.pack.add({
  { src = "https://github.com/Saghen/blink.cmp", version = "v1.10.2" },
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/williamboman/mason.nvim",
})

-- ––– Transparency –––
local function apply_transparency()
  local groups = {
    "Normal", "NormalNC", "NormalFloat", "FloatBorder", "FloatTitle",
    "SignColumn", "StatusLine", "StatusLineNC", "WinSeparator",
    "TabLine", "TabLineFill", "TabLineSel",
  }
  for _, g in ipairs(groups) do
    vim.api.nvim_set_hl(0, g, { bg = "NONE", ctermbg = "NONE" })
  end
end

local function apply_ui_highlights()
  apply_transparency()
  local mode = {
    MiniStatuslineModeNormal  = "#7aa2f7",
    MiniStatuslineModeInsert  = "#9ece6a",
    MiniStatuslineModeVisual  = "#bb9af7",
    MiniStatuslineModeReplace = "#f7768e",
    MiniStatuslineModeCommand = "#e0af68",
    MiniStatuslineModeOther   = "#7dcfff",
  }
  for group, fg in pairs(mode) do
    vim.api.nvim_set_hl(0, group, { fg = fg, bg = "NONE", bold = true })
  end
  vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#c0caf5", bg = "NONE" })
  vim.api.nvim_set_hl(0, "MiniStatuslineInactive", { fg = "#565f89", bg = "NONE" })
end

vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = apply_ui_highlights })
vim.cmd.colorscheme("default")
apply_ui_highlights()

-- ––– Mini modules –––
for _, mod in ipairs({ "icons", "git", "files", "extra" }) do
  require("mini." .. mod).setup()
end

-- mini.statusline — mode colour bars, filename/branch, cursor location only
local statusline = require("mini.statusline")
local function statusline_branch()
  local summary = vim.b.minigit_summary_string or vim.b.gitsigns_head
  if summary == nil or summary == "" then return "" end
  return summary:match("^[^|%s%(]+") or summary
end

statusline.setup({
  use_icons = true,
  content = {
    active = function()
      local _, mode_hl = statusline.section_mode({ trunc_width = 120 })
      local filename = vim.fn.expand("%:t")
      if filename == "" then filename = "[No Name]" end
      local branch = statusline_branch()
      local left = branch == "" and filename or (filename .. " " .. branch)
      local location = "%l:%c"

      return statusline.combine_groups({
        { hl = mode_hl, strings = { "▊" } },
        { hl = "MiniStatuslineFilename", strings = { left } },
        "%=",
        { hl = "MiniStatuslineFilename", strings = { location } },
        { hl = mode_hl, strings = { "▊" } },
      })
    end,
    inactive = function()
      local filename = vim.fn.expand("%:t")
      if filename == "" then filename = "[No Name]" end
      return statusline.combine_groups({
        { hl = "MiniStatuslineInactive", strings = { "▊", filename } },
        "%=",
        { hl = "MiniStatuslineInactive", strings = { "%l:%c", "▊" } },
      })
    end,
  },
})

-- mini.diff — signs against HEAD (stable regardless of staging state)
require("mini.diff").setup({
  source = require("mini.diff").gen_source.git({ diff_args = { "HEAD" } }),
  view = {
    style = "sign",
    signs = { add = "┃", change = "┃", delete = "" },
  },
  mappings = {
    apply      = "gh",
    reset      = "gH",
    textobject = "ih",
    goto_first = "[H",
    goto_prev  = "[h",
    goto_next  = "]h",
    goto_last  = "]H",
  },
})

-- mini.clue — which-key style hint popup
local clue = require("mini.clue")
clue.setup({
  triggers = {
    { mode = "n", keys = "<Leader>" },
    { mode = "x", keys = "<Leader>" },
    { mode = "i", keys = "<C-x>" },
    { mode = "n", keys = "g" },
    { mode = "x", keys = "g" },
    { mode = "n", keys = "'" },
    { mode = "n", keys = "`" },
    { mode = "n", keys = '"' },
    { mode = "i", keys = "<C-r>" },
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
    -- Leader subgroup descriptions (shown as category headers)
    { mode = "n", keys = "<Leader>b",  desc = "Buffer" },
    { mode = "n", keys = "<Leader>t",  desc = "Tab" },
    { mode = "n", keys = "<Leader>f",  desc = "Find" },
    { mode = "n", keys = "<Leader>ca", desc = "Code action" },
  },
  window = {
    delay  = 200,
    config = { border = "rounded" },
  },
})

-- mini.pick — fuzzy finder with help/grep/buffer pickers
require("mini.pick").setup({
  window = {
    config = { border = "rounded" },
  },
})

-- blink.cmp — completion and LSP signature help
local blink = require("blink.cmp")
blink.setup({
  keymap = { preset = "default" },
  appearance = {
    nerd_font_variant = "mono",
  },
  completion = {
    documentation = { auto_show = false },
    trigger = {
      show_on_blocked_trigger_characters = {},
    },
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "class_names" },
    providers = {
      lsp = {
        override = {
          get_trigger_characters = function(self)
            local trigger_characters = self:get_trigger_characters()
            vim.list_extend(trigger_characters, { " " })
            return trigger_characters
          end,
        },
      },
      class_names = {
        name = "Classes",
        module = "config.class_source",
      },
    },
  },
  fuzzy = {
    implementation = "lua",
  },
  signature = {
    enabled = true,
    window = {
      show_documentation = false,
    },
  },
})

-- ––– Keymaps –––
local map = vim.keymap.set

-- Disable Ex mode
map("n", "Q", "<Nop>")

-- Buffer management
map("n", "<leader>bc", "<Cmd>enew<CR>",                      { desc = "Buffer: new" })
map("n", "<leader>bn", "<Cmd>bnext<CR>",                     { desc = "Buffer: next" })
map("n", "<leader>bp", "<Cmd>bprevious<CR>",                 { desc = "Buffer: prev" })
map("n", "<leader>bd", "<Cmd>bdelete<CR>",                   { desc = "Buffer: delete" })
map("n", "<leader>bo", "<Cmd>%bdelete|edit #|bdelete #<CR>", { desc = "Buffer: only" })

-- Tab management
map("n", "<leader>tc", "<Cmd>tabnew<CR>",      { desc = "Tab: new" })
map("n", "<leader>td", "<Cmd>tabclose<CR>",    { desc = "Tab: close" })
map("n", "<leader>tn", "<Cmd>tabnext<CR>",     { desc = "Tab: next" })
map("n", "<leader>tp", "<Cmd>tabprevious<CR>", { desc = "Tab: prev" })

-- File explorer
map("n", "<leader>e", function()
  if not require("mini.files").close() then
    require("mini.files").open(vim.api.nvim_buf_get_name(0))
  end
end, { desc = "Explorer: toggle" })

-- Fuzzy pickers
map("n", "<leader>ff", "<Cmd>Pick files<CR>",     { desc = "Find: files" })
map("n", "<leader>fb", "<Cmd>Pick buffers<CR>",   { desc = "Find: buffers" })
map("n", "<leader>f/", "<Cmd>Pick grep_live<CR>", { desc = "Find: grep (live)" })
map("n", "<leader>fh", "<Cmd>Pick help<CR>",      { desc = "Find: help" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window: left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window: down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window: up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window: right" })

-- Tmux/nvim unified pane navigation (Alt + hjkl)
local function nav(dir)
  local dirs = { h = "L", j = "D", k = "U", l = "R" }
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)
  if vim.api.nvim_get_current_win() == cur and vim.env.TMUX then
    vim.fn.system("tmux select-pane -" .. dirs[dir])
  end
end
map("n", "<A-h>", function() nav("h") end, { desc = "Navigate: left" })
map("n", "<A-j>", function() nav("j") end, { desc = "Navigate: down" })
map("n", "<A-k>", function() nav("k") end, { desc = "Navigate: up" })
map("n", "<A-l>", function() nav("l") end, { desc = "Navigate: right" })

-- Keep visual selection after indent
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Clear search highlight
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- ––– Autocommands –––
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Briefly highlight yanked region
autocmd("TextYankPost", {
  group    = augroup("highlight_yank", { clear = true }),
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

-- Restore cursor to last edit position
autocmd("BufReadPost", {
  group    = augroup("restore_cursor", { clear = true }),
  callback = function()
    local mark       = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Strip trailing whitespace on save (set vim.b.no_strip_ws = true to opt out)
autocmd("BufWritePre", {
  group    = augroup("strip_trailing_ws", { clear = true }),
  callback = function()
    if vim.b.no_strip_ws then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- Equalise splits on terminal resize
autocmd("VimResized", {
  group   = augroup("resize_splits", { clear = true }),
  command = "tabdo wincmd =",
})

-- ––– Treesitter –––
local ts_languages = { "lua", "python", "swift", "typescript", "javascript", "vue" }
local treesitter = require("nvim-treesitter")
treesitter.setup()

autocmd("FileType", {
  group = augroup("treesitter_features", { clear = true }),
  pattern = ts_languages,
  callback = function()
    if pcall(vim.treesitter.start) then
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

vim.api.nvim_create_user_command("TSInstallConfigured", function()
  treesitter.install(ts_languages)
end, {})

vim.defer_fn(function() treesitter.install(ts_languages) end, 0)

-- ––– Mason –––
require("mason").setup()

-- ––– Formatting –––
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    swift = { "swiftformat" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    vue = { "prettier" },
    html = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    less = { "prettier" },
  },
  format_on_save = {
    timeout_ms = 3000,
    lsp_format = "fallback",
  },
})

-- ––– LSP –––
vim.diagnostic.config({
  virtual_text = {
    severity = { min = vim.diagnostic.severity.WARN },
  },
  signs = false,
})

-- ––– LSP –––
local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"
local vue_language_server = mason_packages .. "/vue-language-server"
local vue_typescript_plugin = vue_language_server .. "/node_modules/@vue/typescript-plugin"
local vue_tsdk = vue_language_server .. "/node_modules/typescript/lib"

local servers = {
  sourcekit = {
    cmd          = { "sourcekit-lsp" },
    filetypes    = { "swift" },
    root_markers = { "Package.swift", ".git" },
  },
  pyright = {
    cmd          = { "pyright-langserver", "--stdio" },
    filetypes    = { "python" },
    root_markers = { "pyproject.toml", "setup.py", ".git" },
    settings     = { python = { analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true } } },
  },
  lua_ls = {
    cmd          = { "lua-language-server" },
    filetypes    = { "lua" },
    root_markers = { ".luarc.json", ".git" },
    settings     = { Lua = {
      runtime   = { version = "LuaJIT" },
      workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
    }},
  },
  ts_ls = {
    cmd          = { "typescript-language-server", "--stdio" },
    filetypes    = { "typescript", "javascript", "typescriptreact", "javascriptreact", "vue" },
    root_markers = { "tsconfig.json", "package.json", ".git" },
    init_options = {
      hostInfo = "neovim",
      plugins = {
        {
          name      = "@vue/typescript-plugin",
          location  = vue_typescript_plugin,
          languages = { "typescript", "javascript", "vue" },
        },
      },
    },
  },
  html = {
    cmd          = { "vscode-html-language-server", "--stdio" },
    filetypes    = { "html", "vue" },
    root_markers = { "package.json", ".git" },
  },
  cssls = {
    cmd          = { "vscode-css-language-server", "--stdio" },
    filetypes    = { "css", "scss", "less" },
    root_markers = { "package.json", ".git" },
  },
  tailwindcss = {
    cmd          = { "tailwindcss-language-server", "--stdio" },
    filetypes    = {
      "html",
      "css",
      "scss",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "vue",
    },
    root_markers = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
      "package.json",
      ".git",
    },
  },
  volar = {
    cmd          = { "vue-language-server", "--stdio", "--tsdk=" .. vue_tsdk },
    filetypes    = { "vue" },
    root_markers = { "vite.config.ts", "package.json", ".git" },
    on_init      = function(client)
      local retries = 0

      client.handlers["tsserver/request"] = function(_, result, context)
        local ts_client = vim.lsp.get_clients({ bufnr = context.bufnr, name = "ts_ls" })[1]
        if not ts_client then
          if retries <= 10 then
            retries = retries + 1
            vim.defer_fn(function()
              client.handlers["tsserver/request"](_, result, context)
            end, 100)
          else
            vim.notify("Could not find ts_ls client required by vue-language-server.", vim.log.levels.ERROR)
          end
          return
        end

        local request = result[1]
        local id, command, payload = request[1], request[2], request[3]
        ts_client:exec_cmd({
          title = "vue_request_forward",
          command = "typescript.tsserverRequest",
          arguments = { command, payload },
        }, { bufnr = context.bufnr }, function(_, response)
          client:notify("tsserver/response", { { id, response and response.body } })
        end)
      end
    end,
  },
}

for name, cfg in pairs(servers) do
  cfg.capabilities = blink.get_lsp_capabilities(cfg.capabilities)
  vim.lsp.config(name, cfg)
end

local function enable_lsp()
  local enabled = vim.tbl_filter(function(name)
    return vim.fn.executable(servers[name].cmd[1]) == 1
  end, vim.tbl_keys(servers))
  if #enabled > 0 then
    vim.lsp.enable(enabled)
  end
end
enable_lsp()

-- Auto-install Mason packages; re-enable LSP after each one finishes
vim.defer_fn(function()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return end
  local packages = {
    "lua-language-server",
    "pyright",
    "typescript-language-server",
    "vue-language-server",
    "html-lsp",
    "css-lsp",
    "tailwindcss-language-server",
    "stylua",
    "prettier",
    "swiftformat",
  }
  registry.refresh(function()
    for _, name in ipairs(packages) do
      local pkg_ok, pkg = pcall(registry.get_package, name)
      if pkg_ok and not pkg:is_installed() then
        pkg:install():once("closed", vim.schedule_wrap(enable_lsp))
      end
    end
  end)
end, 0)

autocmd("LspAttach", {
  group    = augroup("lsp_keys", { clear = true }),
  callback = function(ev)
    local lmap = function(k, fn, d) map("n", k, fn, { buffer = ev.buf, desc = d }) end
    lmap("gd",         vim.lsp.buf.definition,     "LSP: definition")
    lmap("gD",         vim.lsp.buf.declaration,    "LSP: declaration")
    lmap("gr",         vim.lsp.buf.references,     "LSP: references")
    lmap("gi",         vim.lsp.buf.implementation, "LSP: implementation")
    lmap("K",          vim.lsp.buf.hover,          "LSP: hover")
    lmap("<leader>r",  vim.lsp.buf.rename,         "LSP: rename")
    lmap("<leader>ca", vim.lsp.buf.code_action,    "LSP: code action")
    lmap("[d",         vim.diagnostic.goto_prev,   "Diagnostic: prev")
    lmap("]d",         vim.diagnostic.goto_next,   "Diagnostic: next")

    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})
