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

-- ––– Plugins –––
vim.pack.add({
  "https://github.com/echasnovski/mini.nvim",
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

vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = apply_transparency })
vim.cmd.colorscheme("default")
apply_transparency()

-- ––– Mini modules –––
for _, mod in ipairs({ "icons", "git", "files", "extra" }) do
  require("mini." .. mod).setup()
end

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
    textobject = "gh",
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
    { mode = "n", keys = "<Leader>b", desc = "Buffer" },
    { mode = "n", keys = "<Leader>t", desc = "Tab" },
    { mode = "n", keys = "<Leader>f", desc = "Find" },
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

-- Commenting (gc/gcc built-in since Neovim 0.10)
map("n", "gc", "gcc", { remap = true, desc = "Comment: toggle line" })
map("x", "gc", "gc",  { remap = true, desc = "Comment: toggle selection" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window: left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window: down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window: up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window: right" })

-- Keep visual selection after indent
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Move lines
map("n", "<A-j>", "<Cmd>m .+1<CR>==",  { desc = "Move line down" })
map("n", "<A-k>", "<Cmd>m .-2<CR>==",  { desc = "Move line up" })
map("x", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("x", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

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
