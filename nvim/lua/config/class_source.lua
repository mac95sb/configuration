local source = {}

local css_filetypes = {
  css = true,
  less = true,
  scss = true,
  sass = true,
}

local scan_filetypes = {
  html = true,
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
}

local cache = {
  root = nil,
  at = 0,
  names = {},
}

local function in_vue_style_block()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor[1], false)
  local in_style = false

  for _, line in ipairs(lines) do
    if line:find("<style[%s>]", 1, false) or line:find("<style%s") then
      in_style = true
    end
    if line:find("</style>", 1, false) then
      in_style = false
    end
  end

  return in_style
end

local function add_class(names, class)
  if class and class:match("^[%w_:%-/%[%]%.!]+$") then
    names[class] = true
  end
end

local function scan_class_list(names, value)
  for class in value:gmatch("[^%s]+") do
    add_class(names, class)
  end
end

local function scan_vue_class_expr(names, expr)
  for value in expr:gmatch('"([^"]+)"') do
    scan_class_list(names, value)
  end
  for value in expr:gmatch("'([^']+)'") do
    scan_class_list(names, value)
  end
  for key in expr:gmatch("[{,]%s*([%w_:%-/%[%]%.!]+)%s*:") do
    add_class(names, key)
  end
end

local function scan_text(names, text)
  for value in text:gmatch('class%s*=%s*"([^"]+)"') do
    scan_class_list(names, value)
  end
  for value in text:gmatch("class%s*=%s*'([^']+)'") do
    scan_class_list(names, value)
  end
  for value in text:gmatch('className%s*=%s*"([^"]+)"') do
    scan_class_list(names, value)
  end
  for value in text:gmatch("className%s*=%s*'([^']+)'") do
    scan_class_list(names, value)
  end
  for expr in text:gmatch(':class%s*=%s*"([^"]+)"') do
    scan_vue_class_expr(names, expr)
  end
  for expr in text:gmatch(":class%s*=%s*'([^']+)'") do
    scan_vue_class_expr(names, expr)
  end
end

local function scan_buffers(names)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and scan_filetypes[vim.bo[bufnr].filetype] then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      scan_text(names, table.concat(lines, "\n"))
    end
  end
end

local function scan_project(names)
  if vim.fn.executable("rg") ~= 1 then return end

  local result = vim.system({
    "rg",
    "--no-heading",
    "--max-count",
    "500",
    "--glob",
    "!node_modules",
    "--glob",
    "!.git",
    "--glob",
    "!dist",
    "--glob",
    "!build",
    "--glob",
    "*.html",
    "--glob",
    "*.vue",
    "--glob",
    "*.jsx",
    "--glob",
    "*.tsx",
    "--glob",
    "*.js",
    "--glob",
    "*.ts",
    "class(Name)?\\s*=|:class\\s*=",
  }, { text = true }):wait(1000)

  if result.code == 0 and result.stdout then
    scan_text(names, result.stdout)
  end
end

local function collect_names()
  local root = vim.fn.getcwd()
  local now = vim.uv.now()

  if cache.root == root and now - cache.at < 10000 then
    return cache.names
  end

  local names = {}
  scan_buffers(names)
  scan_project(names)

  cache = {
    root = root,
    at = now,
    names = names,
  }

  return names
end

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  local ft = vim.bo.filetype
  return css_filetypes[ft] or (ft == "vue" and in_vue_style_block())
end

function source:get_trigger_characters()
  return { "." }
end

function source:get_completions(_, callback)
  local items = {}

  for name in pairs(collect_names()) do
    table.insert(items, {
      label = name,
      insertText = name,
      kind = vim.lsp.protocol.CompletionItemKind.Value,
      detail = "class name",
    })
  end

  table.sort(items, function(a, b) return a.label < b.label end)

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
