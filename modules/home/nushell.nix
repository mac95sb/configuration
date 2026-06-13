{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.nushell = {
      enable = true;

      shellAliases = {
        dr = "sudo darwin-rebuild switch --flake ~/Developer/configuration#mac";
        hr = "home-manager switch --flake ~/Developer/configuration#mac";
      };

      environmentVariables = {
        EDITOR = "nvim";
        PATH   = "($env.HOME + '/.local/bin'):($env.PATH)";
      };

      settings = {
        show_banner = false;
        history = {
          max_size     = 50000;
          sync_on_enter = true;
          file_format  = "sqlite";
        };
        completions = {
          algorithm        = "fuzzy";
          case_sensitive   = false;
        };
      };

      # Prompt and shell functions. Nushell closures run in a sandboxed scope so
      # helper defs used by PROMPT_COMMAND must be defined before it in env.nu.
      extraEnv = ''
        def git-info [] {
          let result = (do { git status --porcelain=v1 -b } | complete)
          if $result.exit_code != 0 { return "" }
          let branch = (
            $result.stdout
            | lines
            | first
            | str replace --regex '^## ([^. ]+).*' '$1'
          )
          let dirty = (
            $result.stdout | lines | skip 1
            | any { |l| ($l | str trim | str length) > 0 }
          )
          if $dirty { $" ($branch)*" } else { $" ($branch)" }
        }

        $env.PROMPT_COMMAND = {||
          let dir    = (pwd | str replace --string $env.HOME "~")
          let branch = (git-info)
          $"(ansi blue)($dir)(ansi dark_gray)($branch)(ansi reset)\n(ansi light_blue)λ(ansi reset) "
        }
        $env.PROMPT_COMMAND_RIGHT = {|| ""}
        $env.PROMPT_INDICATOR      = ""
        $env.PROMPT_INDICATOR_VI_INSERT  = ""
        $env.PROMPT_INDICATOR_VI_NORMAL  = ""
      '';

      extraConfig = ''
        # Kill the process on a port
        def kp [port: int] {
          lsof -ti $":($port)"
          | lines
          | each { |pid| kill -9 ($pid | into int) }
        }

        # Open a tmux coding layout: editor left, agent panes right, floating shell on Alt+F
        def tdl [...agents: string] {
          if (which tmux | is-empty) {
            error make { msg: "tdl: tmux is not installed" }
          }

          let editor      = ($env | get EDITOR? | default "nvim")
          let window_name = (pwd | path basename | if ($in | is-empty) { "tdl" } else { $in })

          let in_tmux = ($env | get TMUX? | is-not-empty)

          let target = if $in_tmux {
            tmux display-message -p '#{session_name}:#{window_index}'
          } else {
            let session = $"tdl-(
              $window_name | str replace --all --regex '[^A-Za-z0-9_.-]' '-'
            )"
            let exists = (do { tmux has-session -t $session } | complete | get exit_code) == 0
            if $exists {
              tmux attach-session -t $session
              return
            }
            tmux new-session -d -P -F '#{session_name}:#{window_index}' \
              -s $session -n $window_name -c (pwd)
          }

          let editor_pane = (tmux display-message -p -t $target '#{pane_id}')
          tmux send-keys -t $editor_pane -- $editor Enter

          mut pane = (
            tmux split-window -h -p 30 -t $editor_pane -c (pwd) -P -F '#{pane_id}'
          )

          let n = ($agents | length)
          if $n > 0 {
            for agent in ($agents | take ($n - 1)) {
              tmux send-keys -t $pane -- $agent Enter
              $pane = (tmux split-window -v -t $pane -c (pwd) -P -F '#{pane_id}')
            }
            tmux send-keys -t $pane -- ($agents | last) Enter
          }

          tmux select-pane -t $editor_pane

          if not $in_tmux {
            tmux attach-session -t ($target | split row ":" | first)
          }
        }
      '';
    };
  };
}
