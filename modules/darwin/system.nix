{ den, lib, ... }: {
  den.aspects.mac.darwin = { ... }: {
    security.pam.services.sudo_local = { touchIdAuth = true; reattach = true; };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    networking.firewall.enable = true;

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
  };
}
