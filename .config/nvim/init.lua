vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 250

vim.filetype.add({
  extension = {
    pbxproj = "openstep",
    pkl = "pkl",
  },
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "folke/tokyonight.nvim", priority = 1000, opts = { style = "night" } },
  { "nvim-lualine/lualine.nvim", opts = { options = { theme = "auto" } } },
  { "nvim-tree/nvim-web-devicons" },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash", "css", "diff", "html", "javascript", "json", "lua", "markdown",
        "markdown_inline", "query", "swift", "toml", "typescript", "tsx", "vue", "xml", "yaml",
      },
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
  { "lewis6991/gitsigns.nvim", opts = {} },
  { "stevearc/conform.nvim", opts = {} },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    opts = { heading = { sign = false } },
  },
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "html", "jsonls", "marksman", "sqls", "taplo", "vtsls", "vue_ls" },
      automatic_installation = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      for _, server in ipairs({ "html", "jsonls", "marksman", "sqls", "taplo", "vtsls", "vue_ls" }) do
        lspconfig[server].setup({})
      end
      lspconfig.sourcekit.setup({})
      lspconfig.pkl_ls.setup({ cmd = { "pkl", "lsp" } })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(keys, action, description)
            vim.keymap.set("n", keys, action, { buffer = event.buf, desc = description })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        end,
      })
    end,
  },
})

vim.cmd.colorscheme("tokyonight")

local changes_buffer
local function refresh_changes()
  if not changes_buffer or not vim.api.nvim_buf_is_valid(changes_buffer) then
    return
  end

  local output = vim.fn.systemlist({ "git", "diff", "--no-ext-diff" })
  if vim.v.shell_error ~= 0 then
    output = { "This directory is not a Git repository." }
  elseif #output == 0 then
    output = { "No uncommitted changes." }
  end

  vim.bo[changes_buffer].modifiable = true
  vim.api.nvim_buf_set_lines(changes_buffer, 0, -1, false, output)
  vim.bo[changes_buffer].modifiable = false
end

local function open_changes()
  vim.cmd.tabnew()
  changes_buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(changes_buffer, "Git Changes")
  vim.bo[changes_buffer].buftype = "nofile"
  vim.bo[changes_buffer].bufhidden = "wipe"
  vim.bo[changes_buffer].swapfile = false
  vim.bo[changes_buffer].filetype = "diff"
  refresh_changes()
end

vim.api.nvim_create_user_command("GitChanges", open_changes, {})
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "CursorHold" }, { callback = refresh_changes })

vim.api.nvim_create_user_command("WorkspaceLayout", function()
  vim.cmd.tabonly()

  local files = {}
  for _, path in ipairs({ "README.md", "mise.toml", ".mise/config.toml" }) do
    if vim.uv.fs_stat(path) then
      table.insert(files, path)
    end
  end

  if #files > 0 then
    vim.cmd.edit(vim.fn.fnameescape(files[1]))
    for index = 2, #files do
      vim.cmd.tabnew(vim.fn.fnameescape(files[index]))
    end
  end
  open_changes()
end, {})
