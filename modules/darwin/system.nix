{ den, lib, ... }: {
  den.aspects.mac.darwin = { config, pkgs, ... }: {
    security.pam.services.sudo_local = { touchIdAuth = true; reattach = true; };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };

    system.defaults = {
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

      # Ctrl+1–9: switch to Desktop 1–9
      CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
        lib.listToAttrs (map (n: {
          name  = toString (117 + n);
          value = { enabled = true; value = { type = "standard"; parameters = [ (48 + n) (17 + n) 262144 ]; }; };
        }) (lib.range 1 9));
    };

    nix.settings.experimental-features = "nix-command flakes";
    nix.optimise.automatic = true;

    nixpkgs = {
      hostPlatform = "aarch64-darwin";
      config.allowUnfree = true;
    };

    system.stateVersion = 7;
    system.primaryUser = "mac";

    system.activationScripts.applications.text = lib.mkForce ''
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
}
