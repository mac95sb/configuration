vim9script

# Core Settings
syntax enable
set encoding=utf-8

# UI Settings
set number
set relativenumber
set nowrap
set scrolloff=10

# Indentation
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab

# Search & Behavior
set undofile
set ignorecase
set smartcase
set completeopt=menu,menuone,noselect,popup
set updatetime=300
set timeoutlen=500

# Key Mappings
g:mapleader = " "
g:maplocalleader = "\\"

# Buffer Management
nnoremap <leader>bc :enew<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bo :%bdelete\|edit #\|bdelete #<CR>

# Tab Management
nnoremap <leader>tc :tabnew<CR>
nnoremap <leader>td :tabclose<CR>
nnoremap <leader>tn :tabnext<CR>
nnoremap <leader>tp :tabprevious<CR>

# Disable Ex mode
nnoremap Q <nop>

# File Explorer
g:netrw_banner = 0
g:netrw_liststyle = 3
nnoremap <leader>e :Explore<CR>

