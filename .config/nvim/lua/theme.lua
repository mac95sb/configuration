-- Everforest hard dark with transparency
vim.o.background = "dark"
local ok, _ = pcall(function()
  vim.g.everforest_background = "hard"
  vim.g.everforest_transparent_background = 2
  vim.cmd.colorscheme("everforest")
end)
if not ok then
  vim.cmd.colorscheme("default")
end

-- Transparency highlights (applied after colorscheme)
local function apply_transparency()
  local groups = {
    "Normal", "NormalNC", "NormalFloat", "FloatBorder",
    "SignColumn", "StatusLine", "WinSeparator",
    "TabLine", "TabLineFill", "TabLineSel",
  }
  for _, g in ipairs(groups) do
    vim.api.nvim_set_hl(0, g, { bg = "NONE", ctermbg = "NONE" })
  end
end

apply_transparency()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparency", { clear = true }),
  callback = apply_transparency,
})
