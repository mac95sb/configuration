{ ... }: {
  den.aspects.mac.darwin = { ... }: {
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
