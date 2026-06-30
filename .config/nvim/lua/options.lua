local opt = vim.opt

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Indentation
opt.tabstop     = 2
opt.shiftwidth  = 2
opt.expandtab   = true
opt.smartindent = true

-- Scrolling
opt.scrolloff = 10

-- Clipboard / undo
opt.clipboard = "unnamedplus"
opt.undofile  = true

-- UI
opt.signcolumn  = "no"
opt.cmdheight   = 0
opt.laststatus  = 3        -- global statusline
opt.splitright  = true
opt.splitbelow  = true
opt.termguicolors = true
opt.showmode    = false    -- mini.statusline shows mode

-- Search
opt.ignorecase = true
opt.smartcase  = true

-- Misc
opt.updatetime = 250
opt.timeoutlen = 200       -- for mini.clue
