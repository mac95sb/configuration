{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.git = {
      enable = true;
      userName = "Mac";
      userEmail = "contact@maclong.dev";

      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519";
      };

      aliases = {
        br = "branch";
        cm = "commit -m";
        co = "checkout";
        lg = "log --graph --oneline --decorate --all";
        st = "status -sb";
      };

      ignores = [
        ".DS_Store"
        "*.swp"
        "*~"
        ".env"
        ".direnv"
      ];

      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        fetch.prune = true;
        core = {
          editor = "nvim";
          pager = "less -FRX";
        };
        gpg.format = "ssh";
        tag.gpgsign = true;
        branch.sort = "-committerdate";
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };
  };
}
