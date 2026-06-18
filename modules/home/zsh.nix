{ ... }: {
  den.aspects.mac.homeManager =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      programs.zsh = {
        enable = true;
        autocd = true;
        enableCompletion = true;

        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          size = 50000;
          save = 50000;
          path = "${config.home.homeDirectory}/.zsh_history";
          ignoreDups = true;
          ignoreSpace = true;
          expireDuplicatesFirst = true;
          share = true;
        };

        sessionVariables = {
          EDITOR = "nvim";
        };

        siteFunctions = {
          _git_info = ''
            local out
            out=$(git status --porcelain=v1 -b 2>/dev/null) || return
            local branch=''${''${out%%$'\n'*}#'## '}
            branch=''${branch%%...*}
            local s=""
            [[ $out == *$'\n'?[!\ ?]* ]] && s="*"
            [[ $out == *$'\n'[!\ ?]* ]] && s+="+"
            print " $branch$s"
          '';

          _build_prompt = ''
              local e=$?
              local sym="%F{#a6dbff}"
              (( e != 0 )) && sym="%F{#ff9e64}"
              PROMPT="
            %F{#6C91BF}%~%F{#767676}$(_git_info)%f
            ''${sym}λ%f "
          '';

          kp = ''
            emulate -L zsh
            if [[ -z "$1" ]]; then
              print -u2 "kp: usage: kp <port>"
              return 1
            fi
            local pids
            pids=$(lsof -ti :"$1") || { print -u2 "kp: no process on port $1"; return 1; }
            print "$pids" | xargs kill -9
          '';

          dr = ''
            emulate -L zsh

            local config_dir="$HOME/Developer/configuration"
            sudo darwin-rebuild switch --flake "$config_dir#mac"
          '';

          hr = ''
            emulate -L zsh

            local config_dir="$HOME/Developer/configuration"
            local activation
            activation=$(nix build --no-link --print-out-paths "$config_dir#darwinConfigurations.mac.config.home-manager.users.mac.home.activationPackage") || return
            "$activation/activate"
          '';

          theme = ''
            emulate -L zsh
            setopt extended_glob

            local config_dir="$HOME/Developer/configuration"
            local theme_file="$config_dir/.theme.nix"

            local -a labels ghostty nvim_name nvim_style
            labels=(
              "Nvim Dark : None (Default)"
              "Everforest Dark Hard : everforest"
              "GitHub Dark Default : github"
              "Gruvbox Dark : gruvbox"
              "Atom One Dark : onedark"
              "Oxocarbon : oxocarbon"
              "Rose Pine : rose-pine"
            )
            ghostty=(
              "Nvim Dark"
              "Everforest Dark Hard"
              "GitHub Dark Default"
              "Gruvbox Dark"
              "Atom One Dark"
              "Oxocarbon"
              "Rose Pine"
            )
            nvim_name=("" "everforest" "github" "gruvbox" "onedark" "oxocarbon" "rose-pine")
            nvim_style=("" "hard" "dark_default" "dark" "dark" "dark" "main")

            local current_ghostty=""
            local current_index=""
            if [[ -r "$theme_file" ]]; then
              current_ghostty=$(sed -n 's/^  ghostty = "\(.*\)";$/\1/p' "$theme_file")
              local i
              for i in {1..''${#ghostty[@]}}; do
                if [[ "''${ghostty[$i]}" == "$current_ghostty" ]]; then
                  current_index="$i"
                  break
                fi
              done
            fi

            local choice="$*"
            local index=""
            if [[ -z "$choice" ]]; then
              local i
              for i in {1..''${#labels[@]}}; do
                if [[ "$i" == "$current_index" ]]; then
                  print "''${i}) ''${labels[$i]} [active]"
                else
                  print "''${i}) ''${labels[$i]}"
                fi
              done
              print -n "Theme: "
              read -r choice
            fi

            if [[ "$choice" == <-> ]]; then
              index="$choice"
            else
              local needle="''${choice:l}"
              local i
              for i in {1..''${#labels[@]}}; do
                if [[ "''${labels[$i]:l}" == *"$needle"* || "''${ghostty[$i]:l}" == *"$needle"* || "''${nvim_name[$i]:l}" == "$needle" ]]; then
                  index="$i"
                  break
                fi
              done
            fi

            if [[ -z "$index" || "$index" -lt 1 || "$index" -gt ''${#labels[@]} ]]; then
              print -u2 "theme: unknown theme '$choice'"
              return 1
            fi

            local nvim_config="null"
            if [[ -n "''${nvim_name[$index]}" ]]; then
              nvim_config="{ name = \"''${nvim_name[$index]}\"; style = \"''${nvim_style[$index]}\"; }"
            fi

            {
              print "{"
              print "  ghostty = \"''${ghostty[$index]}\";"
              print "  nvim = $nvim_config;"
              print "}"
            } >| "$theme_file"

            print "Switching theme: ''${labels[$index]}"
            local activation
            activation=$(nix build --no-link --print-out-paths "$config_dir#darwinConfigurations.mac.config.home-manager.users.mac.home.activationPackage") || return
            "$activation/activate" || return

            if command -v nvim >/dev/null 2>&1; then
              local nvim_server_dir="''${CONFIGURATION_NVIM_SERVER_DIR:-''${TMPDIR:-/tmp}/configuration-nvim}"
              local nvim_init
              nvim_init=$(sed -n "s/^export VIMINIT='source \(.*\)'$/\1/p" "$(command -v nvim)")
              local nvim_config_dir="''${nvim_init:h}"
              local nvim_reload="$nvim_server_dir/reload.lua"
              if [[ -n "$nvim_init" && -r "$nvim_init" ]]; then
                mkdir -p "$nvim_server_dir"
                {
                  print "vim.opt.packpath:prepend(\"$nvim_config_dir\")"
                  print "vim.opt.runtimepath:prepend(\"$nvim_config_dir\")"
                  print "dofile(\"$nvim_init\")"
                } >| "$nvim_reload"
              fi

              if [[ -r "$nvim_reload" ]]; then
                local server
                for server in "$nvim_server_dir"/nvim-*.pipe(N); do
                  nvim --server "$server" --remote-expr "luaeval('dofile(_A)', '$nvim_reload')" >/dev/null 2>&1 || rm -f "$server"
                done
              fi
            fi

            if [[ -n "$GHOSTTY_RESOURCES_DIR" ]] && command -v osascript >/dev/null 2>&1; then
              osascript \
                -e 'tell application "Ghostty" to activate' \
                -e 'tell application "System Events" to keystroke "," using {command down, shift down}' \
                >/dev/null 2>&1 || print -u2 "theme: reload Ghostty manually with Cmd+Shift+,"
            fi
          '';

          tdl = ''
            emulate -L zsh
            if ! command -v tmux >/dev/null 2>&1; then
              print -u2 "tdl: tmux is not installed"
              return 1
            fi

            local editor="''${VISUAL:-''${EDITOR:-nvim}}"
            local window_name="''${PWD:t}"
            [[ -z $window_name ]] && window_name="tdl"

            local target session
            if [[ -n $TMUX ]]; then
              target=$(tmux display-message -p '#{session_name}:#{window_index}')
            else
              session="tdl-''${window_name//[^A-Za-z0-9_.-]/-}"
              if tmux has-session -t "$session" 2>/dev/null; then
                tmux attach-session -t "$session"
                return
              fi
              target=$(tmux new-session -d -P -F '#{session_name}:#{window_index}' \
                -s "$session" -n "$window_name" -c "$PWD")
            fi

            local editor_pane agent_pane
            editor_pane=$(tmux display-message -p -t "$target" '#{pane_id}')
            tmux send-keys -t "$editor_pane" -- "$editor" C-m

            agent_pane=$(tmux split-window -h -p 30 -t "$editor_pane" -c "$PWD" -P -F '#{pane_id}')

            local pane="$agent_pane"
            for agent in "''${@:1:$(( $# > 0 ? $# - 1 : 0 ))}"; do
              tmux send-keys -t "$pane" -- "$agent" C-m
              pane=$(tmux split-window -v -t "$pane" -c "$PWD" -P -F '#{pane_id}')
            done
            (( $# )) && tmux send-keys -t "$pane" -- "''${@[-1]}" C-m

            tmux select-pane -t "$editor_pane"
            [[ -z $TMUX ]] && tmux attach-session -t "$session"
          '';
        };

        initContent = lib.mkOrder 1200 ''
          precmd_functions+=(_build_prompt)
        '';
      };
    };
}
