{ den, pkgs, ... }: {
  den.aspects.mac.homeManager = { pkgs, ... }: {
    home = {
      username = "mac";
      homeDirectory = "/Users/mac";

      packages = with pkgs; [
        gh         # GitHub CLI — used by setup activation for SSH key registration
        ripgrep
        jq
        fd
      ];
    };
  };
}
