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
    };
  };
}
