{ den, ... }: {
  den.aspects.mac.darwin = { ... }: {
    # Touch ID for sudo (with tmux reattach support)
    security.pam.services.sudo_local.touchIdAuth = true;
    security.pam.services.sudo_local.reattach = true;

    # Caps Lock → Control
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    # Firewall
    networking.firewall.enable = true;

    system.defaults = {
      trackpad = {
        TrackpadThreeFingerDrag = true;
        Clicking = true;
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        "com.apple.sound.beep.feedback" = 0;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };

      dock = {
        autohide = true;
        show-recents = false;
        minimize-to-application = true;
        tilesize = 48;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "clmv";
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
      };

      screencapture.location = "~/Desktop";
      loginwindow.GuestEnabled = false;

      # Ctrl+1–9: switch to Desktop 1–9
      # Parameters: [unicode_char, key_code, modifier_flags] — Ctrl = 262144
      CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        "118" = { enabled = true; value = { type = "standard"; parameters = [ 49 18 262144 ]; }; };
        "119" = { enabled = true; value = { type = "standard"; parameters = [ 50 19 262144 ]; }; };
        "120" = { enabled = true; value = { type = "standard"; parameters = [ 51 20 262144 ]; }; };
        "121" = { enabled = true; value = { type = "standard"; parameters = [ 52 21 262144 ]; }; };
        "122" = { enabled = true; value = { type = "standard"; parameters = [ 53 22 262144 ]; }; };
        "123" = { enabled = true; value = { type = "standard"; parameters = [ 54 23 262144 ]; }; };
        "124" = { enabled = true; value = { type = "standard"; parameters = [ 55 24 262144 ]; }; };
        "125" = { enabled = true; value = { type = "standard"; parameters = [ 56 25 262144 ]; }; };
        "126" = { enabled = true; value = { type = "standard"; parameters = [ 57 26 262144 ]; }; };
      };
    };

    # Night Shift: CoreBrightness stores schedule per-display UUID so the
    # sunset-to-sunrise schedule must be enabled once via System Settings →
    # Displays → Night Shift. This activation script fixes the colour temperature.
    system.activationScripts.nightShift.text = ''
      /usr/bin/defaults write com.apple.CoreBrightness \
        CBBlueLightReductionCCTTargetRaw -float 2700 2>/dev/null || true
    '';

    nix.settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };

    nixpkgs = {
      hostPlatform = "aarch64-darwin";
      config.allowUnfree = true;
    };

    users.users.mac = {
      name = "mac";
      home = "/Users/mac";
    };

    system.stateVersion = 6;
  };
}
