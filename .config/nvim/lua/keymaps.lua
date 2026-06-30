local map = vim.keymap.set

-- Disable ex mode
map("n", "Q", "<nop>")

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>")

-- Indent and reselect in visual
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Window navigation (overridden by herdr-splits when inside Herdr)
map("n", "<M-h>", "<C-w>h")
map("n", "<M-j>", "<C-w>j")
map("n", "<M-k>", "<C-w>k")
map("n", "<M-l>", "<C-w>l")

-- Buffer
map("n", "<leader>bc", "<cmd>enew<cr>",      { desc = "New buffer" })
map("n", "<leader>bn", "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>",   { desc = "Delete buffer" })
map("n", "<leader>bo", "<cmd>only<cr>",      { desc = "Close others" })

-- Tab
map("n", "<leader>tc", "<cmd>tabnew<cr>",    { desc = "New tab" })
map("n", "<leader>td", "<cmd>tabclose<cr>",  { desc = "Close tab" })
map("n", "<leader>tn", "<cmd>tabnext<cr>",   { desc = "Next tab" })
map("n", "<leader>tp", "<cmd>tabprevious<cr>", { desc = "Prev tab" })

-- LSP (populated after LSP attaches via on_attach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
  callback = function(ev)
    local opts = { buffer = ev.buf }
    map("n", "gd",         vim.lsp.buf.definition,    vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    map("n", "gD",         vim.lsp.buf.declaration,   vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
    map("n", "gr",         vim.lsp.buf.references,    vim.tbl_extend("force", opts, { desc = "References" }))
    map("n", "gi",         vim.lsp.buf.implementation,vim.tbl_extend("force", opts, { desc = "Implementations" }))
    map("n", "K",          vim.lsp.buf.hover,         vim.tbl_extend("force", opts, { desc = "Hover" }))
    map("n", "<leader>r",  vim.lsp.buf.rename,        vim.tbl_extend("force", opts, { desc = "Rename" }))
    map("n", "<leader>ca", vim.lsp.buf.code_action,   vim.tbl_extend("force", opts, { desc = "Code action" }))
    map("n", "[d", function() vim.diagnostic.goto_prev() end, vim.tbl_extend("force", opts, { desc = "Prev diagnostic" }))
    map("n", "]d", function() vim.diagnostic.goto_next() end, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))
    -- Toggle format on save
    map("n", "<leader>af", function()
      vim.b.format_on_save = not vim.b.format_on_save
      vim.notify("Format on save: " .. tostring(vim.b.format_on_save))
    end, vim.tbl_extend("force", opts, { desc = "Toggle format on save" }))
  end,
})
