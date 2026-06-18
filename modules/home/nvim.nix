{ den, inputs, ... }: {
  den.aspects.mac.homeManager =
    { lib, pkgs, ... }:
    let
      lua = lib.generators.mkLuaInline;
      selectedTheme = import ../../state/theme-selection.nix;
    in
    {
      imports = [ inputs.nvf.homeManagerModules.default ];

      programs.nvf = {
        enable = true;
        settings.vim = {
          enableLuaLoader = true;
          hideSearchHighlight = true;
          theme = lib.mkIf (selectedTheme.nvim != null) {
            enable = true;
            name = selectedTheme.nvim.name;
            style = selectedTheme.nvim.style;
            transparent = true;
          };

          globals = {
            mapleader = " ";
            maplocalleader = "\\";
          };

          options = {
            number = true;
            relativenumber = true;
            wrap = false;
            scrolloff = 10;
            signcolumn = "no";
            cursorline = true;
            exrc = true;
            showmode = false;
            ruler = false;
            showcmd = false;
            cmdheight = 0;
            laststatus = 3;
            pumheight = 10;
            tabstop = 2;
            shiftwidth = 2;
            softtabstop = 2;
            expandtab = true;
            smartindent = true;
            ignorecase = true;
            smartcase = true;
            undofile = true;
            updatetime = 300;
            timeoutlen = 500;
            completeopt = "menu,menuone,noselect";
            splitright = true;
            splitbelow = true;
            termguicolors = true;
            clipboard = "unnamedplus";
          };

          lsp = {
            enable = true;
            servers = {
              "*".capabilities = lua "require('blink.cmp').get_lsp_capabilities()";
              vscode-html-language-server = {
                enable = true;
                cmd = [
                  "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server"
                  "--stdio"
                ];
                filetypes = [
                  "html"
                  "shtml"
                  "xhtml"
                  "htm"
                  "vue"
                ];
                root_markers = [
                  ".git"
                  "package.json"
                ];
                init_options = {
                  provideFormatter = true;
                };
                get_language_id = lua ''
                  function(_, _)
                    return "html"
                  end
                '';
              };
              tailwindcss-language-server = {
                root_dir = lib.mkForce (lua ''
                  function(bufnr, on_dir)
                    local root_files = {
                      'tailwind.config.js',
                      'tailwind.config.cjs',
                      'tailwind.config.mjs',
                      'tailwind.config.ts',
                      'postcss.config.js',
                      'postcss.config.cjs',
                      'postcss.config.mjs',
                      'postcss.config.ts',
                      'vite.config.js',
                      'vite.config.ts',
                      'nuxt.config.js',
                      'nuxt.config.ts',
                      'package.json',
                    }
                    local fname = vim.api.nvim_buf_get_name(bufnr)
                    local found = vim.fs.find(root_files, { path = fname, upward = true })[1]
                    if not found then return end
                    local root = vim.fs.dirname(found)
                    on_dir(root)
                  end
                '');
                settings.tailwindCSS = {
                  includeLanguages = {
                    vue = "html";
                    javascript = "javascript";
                    typescript = "typescript";
                    javascriptreact = "javascriptreact";
                    typescriptreact = "typescriptreact";
                  };
                  experimental.classRegex = [
                    [
                      "class[:=]\\s*\"([^\"]*)\""
                      "\"([^\"]*)\""
                    ]
                    [
                      "class[:=]\\s*'([^']*)'"
                      "'([^']*)'"
                    ]
                  ];
                };
              };
              lua-language-server.settings.Lua = {
                diagnostics.globals = [ "vim" ];
                workspace.checkThirdParty = false;
              };
            };
          };

          diagnostics = {
            enable = true;
            config = {
              virtual_text = {
                prefix = "●";
                source = "if_many";
                spacing = 4;
              };
              signs = false;
            };
          };

          languages = {
            enableTreesitter = true;
            enableFormat = true;

            nix = {
              enable = true;
              format.type = [ "nixfmt" ];
            };
            vue = {
              enable = true;
              lsp.servers = [
                "vue-language-server"
                "vtsls"
                "emmet-ls"
              ];
              format.enable = false;
            };
            html = {
              enable = true;
              lsp.servers = [ "emmet-ls" ];
            };
            css = {
              enable = true;
              lsp.servers = [
                "vscode-css-language-server"
                "emmet-ls"
              ];
            };
            markdown = {
              enable = true;
              extensions.render-markdown-nvim.enable = true;
            };
            lua = {
              enable = true;
              lsp.lazydev.enable = true;
            };
          }
          // lib.genAttrs [ "python" "typescript" ] (_: {
            enable = true;
          });

          # Tailwind has no vim.languages module.
          lsp.presets.tailwindcss-language-server.enable = true;

          formatter.conform-nvim.setupOpts = {
            format_on_save = lua ''
              function(bufnr)
                if vim.b.disable_autoformat then
                  return
                end
                return {
                  timeout_ms = 3000,
                  lsp_format = "fallback"
                }
              end
            '';
            formatters_by_ft.vue = [ "prettier" ];
          };

          autocomplete.blink-cmp = {
            enable = true;
            friendly-snippets.enable = true;
            setupOpts = {
              keymap.preset = "default";
              appearance.nerd_font_variant = "mono";
              completion = {
                documentation.auto_show = false;
                trigger.show_on_blocked_trigger_characters = [ ];
              };
              sources.default = [
                "lsp"
                "path"
                "snippets"
                "buffer"
              ];
              fuzzy.implementation = "lua";
              signature = {
                enabled = true;
                window.show_documentation = false;
              };
            };
            sourcePlugins.ripgrep.enable = true;
          };

          mini = {
            icons.enable = true;
            git.enable = true;
            files.enable = true;
            extra.enable = true;

            diff = {
              enable = true;
              setupOpts = {
                source = lua "require('mini.diff').gen_source.git({ diff_args = { 'HEAD' } })";
                view = {
                  style = "sign";
                  signs = {
                    add = "┃";
                    change = "┃";
                    delete = "";
                  };
                };
                mappings = {
                  apply = "gh";
                  reset = "gH";
                  textobject = "ih";
                  goto_first = "[H";
                  goto_prev = "[h";
                  goto_next = "]h";
                  goto_last = "]H";
                };
              };
            };

            clue = {
              enable = true;
              setupOpts = {
                triggers = [
                  {
                    mode = "n";
                    keys = "<Leader>";
                  }
                  {
                    mode = "x";
                    keys = "<Leader>";
                  }
                  {
                    mode = "i";
                    keys = "<C-x>";
                  }
                  {
                    mode = "n";
                    keys = "g";
                  }
                  {
                    mode = "x";
                    keys = "g";
                  }
                  {
                    mode = "n";
                    keys = "'";
                  }
                  {
                    mode = "n";
                    keys = "`";
                  }
                  {
                    mode = "n";
                    keys = "\"";
                  }
                  {
                    mode = "i";
                    keys = "<C-r>";
                  }
                  {
                    mode = "n";
                    keys = "<C-w>";
                  }
                  {
                    mode = "n";
                    keys = "z";
                  }
                  {
                    mode = "x";
                    keys = "z";
                  }
                ];
                clues = [
                  (lua "require('mini.clue').gen_clues.builtin_completion()")
                  (lua "require('mini.clue').gen_clues.g()")
                  (lua "require('mini.clue').gen_clues.marks()")
                  (lua "require('mini.clue').gen_clues.registers()")
                  (lua "require('mini.clue').gen_clues.windows()")
                  (lua "require('mini.clue').gen_clues.z()")
                  {
                    mode = "n";
                    keys = "<Leader>b";
                    desc = "Buffer";
                  }
                  {
                    mode = "n";
                    keys = "<Leader>t";
                    desc = "Tab";
                  }
                  {
                    mode = "n";
                    keys = "<Leader>f";
                    desc = "Find";
                  }
                  {
                    mode = "n";
                    keys = "<Leader>ca";
                    desc = "Code action";
                  }
                  {
                    mode = "n";
                    keys = "<Leader>af";
                    desc = "Format";
                  }
                ];
                window = {
                  delay = 200;
                  config.border = "rounded";
                };
              };
            };

            pick = {
              enable = true;
              setupOpts.window.config.border = "rounded";
            };

            statusline = {
              enable = true;
              setupOpts = {
                use_icons = true;
                content = {
                  active = lua ''
                    function()
                      local statusline = require("mini.statusline")
                      local _, mode_hl = statusline.section_mode({ trunc_width = 120 })
                      local filename = vim.fn.expand("%:t")
                      if filename == "" then filename = "[No Name]" end

                      local summary = vim.b.minigit_summary_string or vim.b.gitsigns_head
                      local branch = ""
                      if summary ~= nil and summary ~= "" then
                        branch = summary:match("^[^|%s%(]+") or summary
                      end

                      local left = branch == "" and filename or (filename .. " " .. branch)
                      return statusline.combine_groups({
                        { hl = mode_hl,                  strings = { "▊" } },
                        { hl = "MiniStatuslineFilename", strings = { left } },
                        "%=",
                        { hl = "MiniStatuslineFilename", strings = { "%l:%c" } },
                        { hl = mode_hl,                  strings = { "▊" } },
                      })
                    end
                  '';
                  inactive = lua ''
                    function()
                      local statusline = require("mini.statusline")
                      local filename = vim.fn.expand("%:t")
                      if filename == "" then filename = "[No Name]" end
                      return statusline.combine_groups({
                        { hl = "MiniStatuslineInactive", strings = { "▊", filename } },
                        "%=",
                        { hl = "MiniStatuslineInactive", strings = { "%l:%c", "▊" } },
                      })
                    end
                  '';
                };
              };
            };
          };

          keymaps = [
            {
              mode = "n";
              key = "Q";
              action = "<Nop>";
            }

            {
              mode = "n";
              key = "<leader>bc";
              action = "<Cmd>enew<CR>";
              desc = "Buffer: new";
            }
            {
              mode = "n";
              key = "<leader>bn";
              action = "<Cmd>bnext<CR>";
              desc = "Buffer: next";
            }
            {
              mode = "n";
              key = "<leader>bp";
              action = "<Cmd>bprevious<CR>";
              desc = "Buffer: prev";
            }
            {
              mode = "n";
              key = "<leader>bd";
              action = "<Cmd>bdelete<CR>";
              desc = "Buffer: delete";
            }
            {
              mode = "n";
              key = "<leader>bo";
              action = "<Cmd>%bdelete|edit #|bdelete #<CR>";
              desc = "Buffer: only";
            }

            {
              mode = "n";
              key = "<leader>tc";
              action = "<Cmd>tabnew<CR>";
              desc = "Tab: new";
            }
            {
              mode = "n";
              key = "<leader>td";
              action = "<Cmd>tabclose<CR>";
              desc = "Tab: close";
            }
            {
              mode = "n";
              key = "<leader>tn";
              action = "<Cmd>tabnext<CR>";
              desc = "Tab: next";
            }
            {
              mode = "n";
              key = "<leader>tp";
              action = "<Cmd>tabprevious<CR>";
              desc = "Tab: prev";
            }

            {
              mode = "n";
              key = "<leader>e";
              lua = true;
              action = ''
                function()
                  if not require("mini.files").close() then
                    require("mini.files").open(vim.api.nvim_buf_get_name(0))
                  end
                end
              '';
              desc = "Explorer: toggle";
            }

            {
              mode = "n";
              key = "<leader>ff";
              action = "<Cmd>Pick files<CR>";
              desc = "Find: files";
            }
            {
              mode = "n";
              key = "<leader>fb";
              action = "<Cmd>Pick buffers<CR>";
              desc = "Find: buffers";
            }
            {
              mode = "n";
              key = "<leader>f/";
              action = "<Cmd>Pick grep_live<CR>";
              desc = "Find: grep (live)";
            }
            {
              mode = "n";
              key = "<leader>fh";
              action = "<Cmd>Pick help<CR>";
              desc = "Find: help";
            }
            {
              mode = "n";
              key = "<leader>fm";
              lua = true;
              action = ''
                function()
                  local items = {}

                  local function add_marks(mark_list)
                    for _, info in ipairs(mark_list) do
                      if info.mark:match("^'[A-Za-z]$") then
                        local path
                        if type(info.file) == "string" then
                          path = vim.fn.fnamemodify(info.file, ":.")
                        end

                        local bufnr
                        if path == nil then
                          bufnr = info.pos[1]
                        end

                        local line, col = info.pos[2], math.abs(info.pos[3])
                        local text = string.format(
                          "%s │ %s%s│%s",
                          info.mark:sub(2),
                          path == nil and "" or (path .. "│"),
                          line,
                          col
                        )
                        table.insert(items, { text = text, bufnr = bufnr, path = path, lnum = line, col = col })
                      end
                    end
                  end

                  add_marks(vim.fn.getmarklist(vim.api.nvim_get_current_buf()))
                  add_marks(vim.fn.getmarklist())

                  require("mini.pick").start({ source = { items = items, name = "Marks" } })
                end
              '';
              desc = "Find: marks";
            }

            {
              mode = "n";
              key = "<C-h>";
              action = "<C-w>h";
              desc = "Window: left";
            }
            {
              mode = "n";
              key = "<C-j>";
              action = "<C-w>j";
              desc = "Window: down";
            }
            {
              mode = "n";
              key = "<C-k>";
              action = "<C-w>k";
              desc = "Window: up";
            }
            {
              mode = "n";
              key = "<C-l>";
              action = "<C-w>l";
              desc = "Window: right";
            }

            {
              mode = "n";
              key = "<A-h>";
              lua = true;
              action = ''
                function()
                  local cur = vim.api.nvim_get_current_win()
                  vim.cmd("wincmd h")
                  if vim.api.nvim_get_current_win() == cur and vim.env.TMUX then
                    vim.fn.system("tmux select-pane -L")
                  end
                end
              '';
              desc = "Navigate: left";
            }
            {
              mode = "n";
              key = "<A-j>";
              lua = true;
              action = ''
                function()
                  local cur = vim.api.nvim_get_current_win()
                  vim.cmd("wincmd j")
                  if vim.api.nvim_get_current_win() == cur and vim.env.TMUX then
                    vim.fn.system("tmux select-pane -D")
                  end
                end
              '';
              desc = "Navigate: down";
            }
            {
              mode = "n";
              key = "<A-k>";
              lua = true;
              action = ''
                function()
                  local cur = vim.api.nvim_get_current_win()
                  vim.cmd("wincmd k")
                  if vim.api.nvim_get_current_win() == cur and vim.env.TMUX then
                    vim.fn.system("tmux select-pane -U")
                  end
                end
              '';
              desc = "Navigate: up";
            }
            {
              mode = "n";
              key = "<A-l>";
              lua = true;
              action = ''
                function()
                  local cur = vim.api.nvim_get_current_win()
                  vim.cmd("wincmd l")
                  if vim.api.nvim_get_current_win() == cur and vim.env.TMUX then
                    vim.fn.system("tmux select-pane -R")
                  end
                end
              '';
              desc = "Navigate: right";
            }

            {
              mode = "x";
              key = "<";
              action = "<gv";
            }
            {
              mode = "x";
              key = ">";
              action = ">gv";
            }

            {
              mode = "n";
              key = "gd";
              lua = true;
              action = "vim.lsp.buf.definition";
              desc = "LSP: definition";
            }
            {
              mode = "n";
              key = "gD";
              lua = true;
              action = "vim.lsp.buf.declaration";
              desc = "LSP: declaration";
            }
            {
              mode = "n";
              key = "gr";
              lua = true;
              action = "vim.lsp.buf.references";
              desc = "LSP: references";
            }
            {
              mode = "n";
              key = "gi";
              lua = true;
              action = "vim.lsp.buf.implementation";
              desc = "LSP: implementation";
            }
            {
              mode = "n";
              key = "K";
              lua = true;
              action = "vim.lsp.buf.hover";
              desc = "LSP: hover";
            }
            {
              mode = "n";
              key = "<leader>r";
              lua = true;
              action = "vim.lsp.buf.rename";
              desc = "LSP: rename";
            }
            {
              mode = "n";
              key = "<leader>ca";
              lua = true;
              action = "vim.lsp.buf.code_action";
              desc = "LSP: code action";
            }
            {
              mode = "n";
              key = "[d";
              lua = true;
              action = "vim.diagnostic.goto_prev";
              desc = "Diagnostic: prev";
            }
            {
              mode = "n";
              key = "]d";
              lua = true;
              action = "vim.diagnostic.goto_next";
              desc = "Diagnostic: next";
            }

            {
              mode = "n";
              key = "<leader>af";
              lua = true;
              action = ''
                function()
                  vim.b.disable_autoformat = not vim.b.disable_autoformat
                  local status = vim.b.disable_autoformat and "disabled" or "enabled"
                  vim.notify("Auto-format " .. status, vim.log.levels.INFO)
                end
              '';
              desc = "Format: toggle auto";
            }
          ];

          augroups = [
            { name = "ui_highlights"; }
            { name = "highlight_yank"; }
            { name = "restore_cursor"; }
            { name = "strip_trailing_ws"; }
            { name = "resize_splits"; }
            { name = "lsp_inlay_hints"; }
          ];

          autocmds = [
            {
              event = [ "ColorScheme" ];
              group = "ui_highlights";
              pattern = [ "*" ];
              callback = lua "function() apply_ui_highlights() end";
            }
            {
              event = [ "TextYankPost" ];
              group = "highlight_yank";
              callback = lua ''
                function()
                  vim.highlight.on_yank({ timeout = 150 })
                end
              '';
            }
            {
              event = [ "BufReadPost" ];
              group = "restore_cursor";
              callback = lua ''
                function()
                  local mark = vim.api.nvim_buf_get_mark(0, '"')
                  local line_count = vim.api.nvim_buf_line_count(0)
                  if mark[1] > 0 and mark[1] <= line_count then
                    vim.api.nvim_win_set_cursor(0, mark)
                  end
                end
              '';
            }
            {
              event = [ "BufWritePre" ];
              group = "strip_trailing_ws";
              callback = lua ''
                function()
                  if vim.b.no_strip_ws then return end
                  local pos = vim.api.nvim_win_get_cursor(0)
                  vim.cmd([[%s/\s\+$//e]])
                  vim.api.nvim_win_set_cursor(0, pos)
                end
              '';
            }
            {
              event = [ "VimResized" ];
              group = "resize_splits";
              command = "tabdo wincmd =";
            }
            {
              event = [ "LspAttach" ];
              group = "lsp_inlay_hints";
              callback = lua ''
                function(ev)
                  local client = vim.lsp.get_client_by_id(ev.data.client_id)
                  if client and client:supports_method("textDocument/inlayHint") then
                    vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
                  end
                end
              '';
            }
          ];

          luaConfigRC.init = # lua
            ''
              do
                local server_dir = vim.env.CONFIGURATION_NVIM_SERVER_DIR
                  or ((vim.env.TMPDIR or "/tmp") .. "/configuration-nvim")
                vim.fn.mkdir(server_dir, "p")
                local server = server_dir .. "/nvim-" .. vim.fn.getpid() .. ".pipe"
                pcall(vim.fn.serverstart, server)
                vim.api.nvim_create_autocmd("VimLeavePre", {
                  callback = function()
                    pcall(vim.fn.delete, server)
                  end,
                })
              end

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

              function apply_ui_highlights()
                apply_transparency()
                local mode = {
                  MiniStatuslineModeNormal  = "#7aa2f7",
                  MiniStatuslineModeInsert  = "#9ece6a",
                  MiniStatuslineModeVisual  = "#bb9af7",
                  MiniStatuslineModeReplace = "#f7768e",
                  MiniStatuslineModeCommand = "#e0af68",
                  MiniStatuslineModeOther   = "#7dcfff",
                }
                for group, fg in pairs(mode) do
                  vim.api.nvim_set_hl(0, group, { fg = fg, bg = "NONE", bold = true })
                end
                vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#c0caf5", bg = "NONE" })
                vim.api.nvim_set_hl(0, "MiniStatuslineInactive", { fg = "#565f89", bg = "NONE" })

                local treesitter_highlights = {
                  ["@keyword"] = { fg = "#bb9af7", bold = true },
                  ["@keyword.function"] = { fg = "#bb9af7", bold = true },
                  ["@function"] = { fg = "#7dcfff" },
                  ["@function.call"] = { fg = "#7dcfff" },
                  ["@method"] = { fg = "#7dcfff" },
                  ["@method.call"] = { fg = "#7dcfff" },
                  ["@variable"] = { fg = "#c0caf5" },
                  ["@variable.member"] = { fg = "#7aa2f7" },
                  ["@property"] = { fg = "#7aa2f7" },
                  ["@string"] = { fg = "#9ece6a" },
                  ["@string.special.url"] = { fg = "#73daca", underline = true },
                  ["@constant"] = { fg = "#ff9e64" },
                  ["@number"] = { fg = "#ff9e64" },
                  ["@boolean"] = { fg = "#ff9e64" },
                  ["@type"] = { fg = "#2ac3de" },
                  ["@constructor"] = { fg = "#2ac3de" },
                  ["@module"] = { fg = "#7aa2f7" },
                  ["@operator"] = { fg = "#89ddff" },
                  ["@punctuation.delimiter"] = { fg = "#89ddff" },
                  ["@punctuation.bracket"] = { fg = "#89ddff" },
                  ["@comment"] = { fg = "#565f89", italic = true },
                  ["@tag"] = { fg = "#7dcfff" },
                  ["@tag.delimiter"] = { fg = "#89ddff" },
                  ["@tag.attribute"] = { fg = "#7aa2f7" },
                  ["@markup.heading"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.1"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.2"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.3"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.4"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.5"] = { fg = "#e0af68", bold = true },
                  ["@markup.heading.6"] = { fg = "#e0af68", bold = true },
                }
                for group, hl in pairs(treesitter_highlights) do
                  vim.api.nvim_set_hl(0, group, hl)
                end
              end

              ${lib.optionalString (selectedTheme.nvim == null) ''
                vim.cmd.colorscheme("default")
              ''}

              apply_ui_highlights()

              local web_syntax_by_filetype = {
                html = "html",
                htmldjango = "html",
                xhtml = "html",
                javascript = "javascript",
                javascriptreact = "javascript",
                typescript = "typescript",
                typescriptreact = "typescript",
                vue = "vue",
                css = "css",
              }

              local web_syntax_by_extension = {
                html = "html",
                htm = "html",
                xhtml = "html",
                js = "javascript",
                jsx = "javascript",
                mjs = "javascript",
                cjs = "javascript",
                ts = "typescript",
                tsx = "typescript",
                mts = "typescript",
                cts = "typescript",
                vue = "vue",
                css = "css",
              }

              local function apply_web_highlighting(bufnr)
                bufnr = bufnr or vim.api.nvim_get_current_buf()
                local ft = vim.bo[bufnr].filetype
                local syntax = web_syntax_by_filetype[ft]
                if syntax == nil then
                  local name = vim.api.nvim_buf_get_name(bufnr)
                  local ext = name:match("%.([^.]+)$")
                  syntax = ext == nil and nil or web_syntax_by_extension[ext]
                end
                if syntax == nil then return end

                vim.bo[bufnr].syntax = syntax
                pcall(vim.treesitter.start, bufnr)
              end

              vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType", "VimEnter" }, {
                callback = function(ev)
                  apply_web_highlighting(ev.buf)
                end,
              })

              local function apply_web_highlighting_to_loaded_buffers()
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                  if vim.api.nvim_buf_is_loaded(bufnr) then
                    apply_web_highlighting(bufnr)
                  end
                end
              end

              vim.schedule(apply_web_highlighting_to_loaded_buffers)
            '';
        };
      };
    };
}
