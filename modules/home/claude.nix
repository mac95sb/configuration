{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.claude-code = {
      enable = true;
      settings = {
        theme = "dark";
        attribution = {
          commit = "";
          pr = "";
        };
      };
    };
  };
}
