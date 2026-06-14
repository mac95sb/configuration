{ inputs, den, ... }: {
  den.aspects.mac.darwin = { ... }: {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    nix-homebrew = {
      enable = true;
      user = "mac";
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };

      brews = [
        "container"
      ];

      casks = [
        "crossover"
        "font-sf-mono-nerd-font-ligaturized"
        "steam"
      ];

      masApps = {
        "Compressor"     = 424390742;
        "Final Cut Pro"  = 424389933;
        "Keynote"        = 361285480;
        "Logic Pro"      = 634148309;
        "MainStage"      = 634159523;
        "Motion"         = 434290957;
        "Numbers"        = 361304891;
        "Pages"          = 361309726;
        "Pixelmator Pro" = 1289583905;
        "Wipr 2"         = 1662217862;
      };
    };
  };
}
