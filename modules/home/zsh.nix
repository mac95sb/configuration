{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.zsh = {
      enable = true;
      autocd = true;
      enableCompletion = true;

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 50000;
        save = 50000;
        path = "$HOME/.zsh_history";
        ignoreDups = true;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
        share = true;
      };

      shellAliases = {
        dr = "sudo darwin-rebuild switch --flake ~/Developer/configuration#mac";
        hr = "home-manager switch --flake ~/Developer/configuration#mac";
      };

      # PATH extension is handled by home.sessionPath in defaults.nix.
      # Only shell functions that have no structured home-manager equivalent remain here.
      initContent = ''
        _git_info() {
          local out
          out=$(git status --porcelain=v1 -b 2>/dev/null) || return
          local branch=''${''${out%%$'\n'*}#'## '}
          branch=''${branch%%...*}
          local s=""
          [[ $out == *$'\n'?[!\ ?]* ]] && s="*"
          [[ $out == *$'\n'[!\ ?]* ]] && s+="+"
          print " $branch$s"
        }

        _build_prompt() {
          local e=$?
          local sym="%F{#a6dbff}"
          (( e != 0 )) && sym="%F{#ff9e64}"
          PROMPT="
        %F{#6C91BF}%~%F{#767676}$(_git_info)%f
        ''${sym}λ%f "
        }

        precmd_functions+=(_build_prompt)

        kp() {
          lsof -ti :"$1" | xargs kill -9
        }

        tdl() {
          emulate -L zsh
          if ! command -v tmux >/dev/null 2>&1; then
            print -u2 "tdl: tmux is not installed"
            return 1
          fi

          local editor="''${EDITOR:-nvim}"
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
        }
      '';
    };
  };
}
