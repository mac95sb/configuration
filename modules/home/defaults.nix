{ den, ... }: {
  den.aspects.mac.homeManager = { pkgs, ... }: {
    home = {
      username = "mac";
      homeDirectory = "/Users/mac";

      sessionPath = [ "$HOME/.local/bin" ];

      packages = with pkgs; [
        gh
      ];
    };
  };
}
