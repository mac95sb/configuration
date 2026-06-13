{ den, ... }: {
  den.aspects.mac.homeManager = { pkgs, ... }: {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty-bin;
      settings = {
        theme = "Nvim Dark";
        background-opacity = 0.9;
        background-blur = true;

        font-family = "Liga SFMono Nerd Font";
        font-size = 11;
        font-feature = [ "+liga" "+calt" "+dlig" ];

        window-padding-x = 8;
        window-padding-y = 8;
        window-padding-balance = true;

        macos-option-as-alt = true;

        keybind = [ "alt+shift+3=text:#" ];
      };
    };
  };
}
