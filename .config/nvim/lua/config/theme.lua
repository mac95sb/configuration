local M = {}

function M.apply()
  vim.g.everforest_background = vim.o.background == "light" and "medium" or "hard"
  vim.g.everforest_transparent_background = 2
  vim.g.everforest_enable_italic = 1
  vim.g.everforest_better_performance = 1
  vim.cmd.colorscheme("everforest")
end

function M.setup()
  vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = function()
      if vim.g.colors_name == "everforest" then
        M.apply()
      end
    end,
  })
  vim.api.nvim_create_user_command("ThemeLight", function()
    vim.o.background = "light"
    M.apply()
  end, {})
  vim.api.nvim_create_user_command("ThemeDark", function()
    vim.o.background = "dark"
    M.apply()
  end, {})
  vim.keymap.set("n", "<leader>ut", function()
    vim.o.background = vim.o.background == "light" and "dark" or "light"
    M.apply()
  end, { desc = "Toggle Everforest light/dark" })
end

return M
