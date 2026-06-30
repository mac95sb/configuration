local au = vim.api.nvim_create_autocmd
local ag = vim.api.nvim_create_augroup

-- Restore last cursor position
au("BufReadPost", {
  group = ag("last_loc", { clear = true }),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Strip trailing whitespace on save (respect vim.b.no_strip_ws)
au("BufWritePre", {
  group = ag("strip_trailing_ws", { clear = true }),
  callback = function()
    if vim.b.no_strip_ws then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- Equalize splits on resize
au("VimResized", {
  group = ag("resize_splits", { clear = true }),
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Unix socket server (per-PID pipe for remote control)
au("VimEnter", {
  group = ag("nvim_server", { clear = true }),
  once = true,
  callback = function()
    local server_dir = vim.env.CONFIGURATION_NVIM_SERVER_DIR
      or ((vim.env.TMPDIR or "/tmp") .. "/configuration-nvim")
    vim.fn.mkdir(server_dir, "p")
    local pipe = server_dir .. "/nvim-" .. vim.fn.getpid() .. ".pipe"
    pcall(vim.fn.serverstart, pipe)
    au("VimLeavePre", {
      once = true,
      callback = function() pcall(vim.fn.delete, pipe) end,
    })
  end,
})
