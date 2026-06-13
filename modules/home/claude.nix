{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    home.file.".claude/settings.json".text = builtins.toJSON {
      theme = "dark";
      attribution = {
        commit = "";
        pr = "";
      };
    };
  };
}
