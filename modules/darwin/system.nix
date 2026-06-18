{ den, lib, ... }: {
  den.aspects.mac.darwin = { config, pkgs, ... }: {
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    system = {
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      defaults = {
        trackpad = {
          TrackpadThreeFingerDrag = true;
          Clicking = true;
        };

        NSGlobalDomain = {
          AppleInterfaceStyleSwitchesAutomatically = true;
        };

        finder = {
          FXPreferredViewStyle = "clmv";
          ShowPathbar = true;
          FXEnableExtensionChangeWarning = false;
        };
      };

      stateVersion = 7;
      primaryUser = "mac";

      activationScripts.applications.text = lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2

        targetFolder='/Applications'
        oldTargetFolder='/Applications/Nix Apps'
        sourceFolder='${config.system.build.applications}/Applications'

        mkdir -p "$targetFolder"

        if [ -d "$sourceFolder" ]; then
          find "$sourceFolder" -maxdepth 1 -mindepth 1 -name '*.app' -print0 | while IFS= read -r -d "" app; do
            target="$targetFolder/$(basename "$app")"

            rsyncFlags=(
              --checksum
              --copy-unsafe-links
              --archive
              --delete
              --chmod=-w
              --no-group
              --no-owner
            )

            ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" "$app/" "$target/"

            oldTarget="$oldTargetFolder/$(basename "$app")"
            if [ -e "$oldTarget" ]; then
              rm -rf "$oldTarget"
            fi
          done
        fi

        rmdir "$oldTargetFolder" 2>/dev/null || true
      '';
    };

    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };

    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      optimise.automatic = true;
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        };
        options = "--delete-older-than 30d";
      };
    };

    nixpkgs = {
      hostPlatform = "aarch64-darwin";
      config.allowUnfree = true;
    };
  };
}
