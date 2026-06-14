{ den, ... }: {
  den.aspects.mac.homeManager = { pkgs, lib, ... }: {
    programs.tmux = {
      enable = true;
      mouse = true;
      baseIndex = 1;
      historyLimit = 50000;
      terminal = "tmux-256color";
      escapeTime = 0;
      focusEvents = true;
      keyMode = "vi";
      sensibleOnTop = false;

      plugins = [
        {
          plugin = pkgs.tmuxPlugins.tmux-floax;
          extraConfig = ''
            set -g @floax-bind '-n M-F'
            set -g @floax-width '88%'
            set -g @floax-height '60%'
            set -g @floax-border-color '#4f5258'
            set -g @floax-text-color '#e0e2ea'
            set -g @floax-title 'shell'
            set -g @floax-session-name 'tdl-shell'
          '';
        }
      ];

      extraConfig = ''
        set -g renumber-windows on
        set -g extended-keys on
        set -g extended-keys-format csi-u
        set -g set-clipboard on

        # Appearance
        set -g pane-border-style "fg=#4f5258"
        set -g pane-active-border-style "fg=#4f5258"
        set -g pane-border-lines single

        # Status bar
        set -g status-position bottom
        set -g status-justify centre
        set -g status-style "bg=default,fg=default"
        set -g status-left ""
        set -g status-right ""
        setw -g window-status-format         " #I "
        setw -g window-status-current-format " #I "
        setw -g window-status-style          "fg=#4f5258,bg=default"
        setw -g window-status-current-style  "fg=#e0e2ea,bg=default,bold"
        setw -g window-status-separator      ""

        # Remove all root-table defaults; use Alt as prefix-free modifier
        unbind-key -a -T root
        set -g prefix None

        # Pane focus (Alt+hjkl) — pass through to nvim when active
        is_nvim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\S+\/)?nvim$'"
        bind -n M-h if-shell "$is_nvim" "send-keys M-h" "select-pane -L"
        bind -n M-j if-shell "$is_nvim" "send-keys M-j" "select-pane -D"
        bind -n M-k if-shell "$is_nvim" "send-keys M-k" "select-pane -U"
        bind -n M-l if-shell "$is_nvim" "send-keys M-l" "select-pane -R"

        # Pane resize (Alt+HJKL)
        bind -n M-H resize-pane -L 5
        bind -n M-J resize-pane -D 5
        bind -n M-K resize-pane -U 5
        bind -n M-L resize-pane -R 5

        # New / close window
        bind -n M-t new-window
        bind -n M-w kill-window

        # Directional split (Ctrl+Alt+hjkl)
        bind -n C-M-h split-window -h \; swap-pane -D
        bind -n C-M-j split-window -v
        bind -n C-M-k split-window -v \; swap-pane -D
        bind -n C-M-l split-window -h

        # Jump to window by number (Alt+1–9)
        ${lib.concatMapStrings (n: "bind -n M-${toString n} select-window -t ${toString n}\n        ") (lib.range 1 9)}

        # Copy mode (vi bindings set via keyMode = "vi" above)
        bind -n M-[ copy-mode
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
        bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "pbcopy"

        # Floating shell session hook
        set-hook -g session-created \
          'if -F "#{==:#{session_name},tdl-shell}" \
           "set-option -t tdl-shell status off \; \
            split-window -h -p 50 -t tdl-shell:1.1 -c \"#{pane_current_path}\" \; \
            select-pane -t tdl-shell:1.1"'

        set -ag terminal-overrides ",xterm-256color:RGB"
      '';
    };
  };
}
