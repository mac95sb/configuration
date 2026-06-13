{ lib, ... }: {
  home.file.".claude/settings.json".text = builtins.toJSON {
    theme = "dark";
    attribution = {
      commit = "";
      pr = "";
    };
  };
}
