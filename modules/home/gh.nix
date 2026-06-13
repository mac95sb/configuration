{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };
  };
}
