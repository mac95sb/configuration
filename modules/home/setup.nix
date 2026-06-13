{ den, pkgs, lib, ... }: {
  den.aspects.mac.homeManager = { pkgs, lib, ... }: {
    home.activation.sshAndGitHub = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      KEY="$HOME/.ssh/id_ed25519"

      # Generate SSH key if missing
      if [ ! -f "$KEY" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ${pkgs.openssh}/bin/ssh-keygen \
          -t ed25519 \
          -C "$(scutil --get ComputerName 2>/dev/null || hostname)" \
          -f "$KEY" -N ""
        echo ""
        echo "→ SSH key generated at $KEY"
      fi

      # Register key with GitHub via gh CLI
      GH="${pkgs.gh}/bin/gh"
      if [ -f "$KEY.pub" ] && [ -x "$GH" ]; then
        if ! "$GH" auth status --hostname github.com &>/dev/null 2>&1; then
          echo ""
          echo "→ Authenticate with GitHub (admin:public_key scope required to add SSH key):"
          "$GH" auth login \
            --hostname github.com \
            --git-protocol ssh \
            --scopes "admin:public_key" \
            --web
        else
          # Ensure admin:public_key scope is present, then add the key
          "$GH" auth refresh \
            --hostname github.com \
            --scopes "admin:public_key" 2>/dev/null || true
        fi

        TITLE="$(scutil --get ComputerName 2>/dev/null || hostname)"
        "$GH" ssh-key add "$KEY.pub" --title "$TITLE" 2>/dev/null \
          && echo "→ SSH key registered on GitHub as '$TITLE'." \
          || true
      fi
    '';
  };
}
