{ ... }: {
  den.aspects.mac.homeManager =
    { lib, ... }:
    {
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

          # Restore mouse bindings removed by clearing the root table.
          bind -T root MouseDown1Pane if -Ft= "#{mouse_any_flag}" "send-keys -M" "select-pane -t="
          bind -T root MouseDrag1Pane if -Ft= "#{mouse_any_flag}" "send-keys -M" "copy-mode -M"
          bind -T root MouseDrag1Border resize-pane -M
          bind -T root WheelUpPane if -Ft= "#{mouse_any_flag}" "send-keys -M" "if -Ft= \"#{pane_in_mode}\" \"send-keys -M\" \"copy-mode -e\""
          bind -T root WheelDownPane select-pane -t= \; send-keys -M

          # Pane focus (Alt+hjkl) — send CSI-u sequences to nvim so <A-h> keymaps fire;
          # nvim's mappings handle intra-nvim movement and fall through to select-pane at edges.
          is_nvim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\S+\/)?nvim$'"
          bind -n M-h if-shell "$is_nvim" 'send-keys Escape "[104;3u"' "select-pane -L"
          bind -n M-j if-shell "$is_nvim" 'send-keys Escape "[106;3u"' "select-pane -D"
          bind -n M-k if-shell "$is_nvim" 'send-keys Escape "[107;3u"' "select-pane -U"
          bind -n M-l if-shell "$is_nvim" 'send-keys Escape "[108;3u"' "select-pane -R"

          # Pane resize (Alt+HJKL)
          bind -n M-H resize-pane -L 5
          bind -n M-J resize-pane -D 5
          bind -n M-K resize-pane -U 5
          bind -n M-L resize-pane -R 5

          # New / close window
          bind -n M-t new-window -c "#{pane_current_path}"
          bind -n M-w kill-window

          # Directional split (Ctrl+Alt+hjkl)
          bind -n C-M-h split-window -h -c "#{pane_current_path}" \; swap-pane -D
          bind -n C-M-j split-window -v -c "#{pane_current_path}"
          bind -n C-M-k split-window -v -c "#{pane_current_path}" \; swap-pane -D
          bind -n C-M-l split-window -h -c "#{pane_current_path}"

          # Jump to window by number (Alt+1–9)
          ${lib.concatMapStrings (n: "bind -n M-${toString n} select-window -t ${toString n}\n        ") (
            lib.range 1 9
          )}

          # Copy mode (vi bindings set via keyMode = "vi" above)
          bind -n M-[ copy-mode
          bind -T copy-mode-vi v send -X begin-selection
          bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
          bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "pbcopy"

          # Floating popup shell — one scratch session per window, split into two panes on first use.
          bind -n M-F display-popup \
            -S "fg=#4f5258" \
            -s "fg=#e0e2ea" \
            -T "shell" \
            -w "75%" \
            -h "45%" \
            -b rounded \
            -E \
            -d "#{pane_current_path}" \
            "tmux new-session -A -s 'scratch-#{window_id}'"

          set-hook -g session-created \
            'if -F "#{m:scratch-*,#{session_name}}" \
             "set-option -t #{session_name} status off \; \
              split-window -h -p 50 -t #{session_name}:1 -c \"#{pane_current_path}\" \; \
              select-pane -t #{session_name}:1.0"'

          set -ag terminal-overrides ",tmux-256color:RGB"
        '';
      };
    };
}
