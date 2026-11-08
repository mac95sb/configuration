vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.signcolumn = 'yes'
vim.opt.mouse = 'a'
vim.opt.termguicolors = true
vim.opt.background = 'light'
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.completeopt = { 'menuone', 'noinsert', 'popup' }
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true

vim.pack.add({
  'https://github.com/nvim-mini/mini.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  { src = 'https://github.com/neovim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/neovim-treesitter/treesitter-parser-registry', version = 'main' },
})

local latte = {
  base00 = '#eff1f5', base01 = '#e6e9ef', base02 = '#ccd0da', base03 = '#bcc0cc',
  base04 = '#acb0be', base05 = '#4c4f69', base06 = '#dc8a78', base07 = '#4c4f69',
  base08 = '#d20f39', base09 = '#fe640b', base0A = '#df8e1d', base0B = '#40a02b',
  base0C = '#179299', base0D = '#1e66f5', base0E = '#ea76cb', base0F = '#dd7878',
}
require('mini.base16').setup({ palette = latte })

require('mini.basics').setup()
require('mini.icons').setup()
require('mini.ai').setup()
require('mini.bracketed').setup()
require('mini.comment').setup()
require('mini.completion').setup()
require('mini.cursorword').setup()
require('mini.diff').setup()
require('mini.files').setup()
require('mini.git').setup()
require('mini.indentscope').setup()
require('mini.jump').setup()
require('mini.move').setup()
require('mini.notify').setup()
require('mini.operators').setup()
require('mini.pairs').setup()
require('mini.pick').setup()
require('mini.sessions').setup()
require('mini.snippets').setup({ snippets = { require('mini.snippets').gen_loader.from_lang() } })
require('mini.statusline').setup({ use_icons = true })
require('mini.surround').setup()
require('mini.tabline').setup()
require('mini.trailspace').setup()

require('mini.clue').setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' }, { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' }, { mode = 'x', keys = 'g' },
    { mode = 'n', keys = '[' }, { mode = 'n', keys = ']' },
    { mode = 'n', keys = 'z' },
  },
  clues = {
    require('mini.clue').gen_clues.builtin_completion(),
    require('mini.clue').gen_clues.g(),
    require('mini.clue').gen_clues.marks(),
    require('mini.clue').gen_clues.registers(),
    require('mini.clue').gen_clues.windows(),
    require('mini.clue').gen_clues.z(),
    require('mini.clue').gen_clues.mini_bracketed(),
    require('mini.clue').gen_clues.mini_files(),
    require('mini.clue').gen_clues.mini_jump(),
    require('mini.clue').gen_clues.mini_move(),
    require('mini.clue').gen_clues.mini_operators(),
    require('mini.clue').gen_clues.mini_sessions(),
    require('mini.clue').gen_clues.mini_surround(),
  },
  window = { config = { width = 'auto' } },
})

local map = vim.keymap.set
map('n', '<leader>e', function() require('mini.files').open(nil, true) end, { desc = 'File explorer' })
map('n', '<leader>ff', function() require('mini.pick').builtin.files() end, { desc = 'Find files' })
map('n', '<leader>fg', function() require('mini.pick').builtin.grep_live() end, { desc = 'Search text' })
map('n', '<leader>fb', function() require('mini.pick').builtin.buffers() end, { desc = 'Find buffers' })
map('n', '<leader>fh', function() require('mini.pick').builtin.help() end, { desc = 'Find help' })
map('n', '<leader>fr', function() require('mini.pick').builtin.resume() end, { desc = 'Resume picker' })
map('n', '<leader>tt', function() require('mini.trailspace').trim() end, { desc = 'Trim trailing spaces' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function() vim.bo.shiftwidth = 4; vim.bo.tabstop = 4 end,
})

local lsp_keys = {
  { 'K', vim.lsp.buf.hover, 'Hover documentation' },
  { 'gd', vim.lsp.buf.definition, 'Go to definition' },
  { 'gD', vim.lsp.buf.declaration, 'Go to declaration' },
  { 'gi', vim.lsp.buf.implementation, 'Go to implementation' },
  { 'gr', vim.lsp.buf.references, 'Find references' },
  { '<leader>ca', vim.lsp.buf.code_action, 'Code action' },
  { '<leader>rn', vim.lsp.buf.rename, 'Rename symbol' },
  { '<leader>D', vim.lsp.buf.type_definition, 'Go to type definition' },
  { '<leader>f', vim.lsp.buf.format, 'Format buffer' },
}
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    for _, binding in ipairs(lsp_keys) do
      map('n', binding[1], binding[2], { buffer = event.buf, desc = binding[3] })
    end
  end,
})

local vue_root = vim.trim(vim.fn.system({ 'mise', 'where', 'npm:@vue/language-server' }))
local vue_plugin = vim.fs.joinpath(vue_root, 'node_modules', '@vue', 'language-server')
vim.lsp.config('vtsls', {
  filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' },
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = {{
          name = '@vue/typescript-plugin',
          location = vue_plugin,
          languages = { 'vue' },
          configNamespace = 'typescript',
        }},
      },
    },
  },
})
vim.lsp.config('vue_ls', { filetypes = { 'vue' }, root_markers = { 'package.json', 'vue.config.js', 'vite.config.js' } })
vim.lsp.config('pyright', { root_markers = { 'pyproject.toml', 'pyrightconfig.json', 'setup.py', 'requirements.txt', '.git' } })
vim.lsp.config('sourcekit', { root_markers = { 'Package.swift', '*.xcodeproj', '*.xcworkspace', '.git' } })
vim.lsp.config('jsonls', { root_markers = { 'package.json', '.git' } })
vim.lsp.config('yamlls', { root_markers = { '.git' } })
vim.lsp.config('bashls', { filetypes = { 'sh', 'bash', 'zsh' }, root_markers = { '.git' } })
vim.lsp.enable({ 'pyright', 'sourcekit', 'vtsls', 'vue_ls', 'jsonls', 'yamlls', 'bashls' })

local parsers = { 'python', 'swift', 'javascript', 'typescript', 'vue', 'json', 'yaml', 'bash' }
vim.filetype.add({
  filename = {
    ['.bashrc'] = 'bash', ['.bash_profile'] = 'bash',
    ['.zshrc'] = 'zsh', ['.zprofile'] = 'zsh', ['.zshenv'] = 'zsh',
  },
  extension = { zsh = 'zsh' },
})
table.insert(parsers, 'zsh')
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python', 'swift', 'javascript', 'typescript', 'vue', 'json', 'yaml', 'sh', 'bash', 'zsh' },
  callback = function() pcall(vim.treesitter.start) end,
})
require('nvim-treesitter').install(parsers)
