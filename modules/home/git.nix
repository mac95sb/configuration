{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.git = {
      enable = true;

      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519";
      };

      ignores = [
        ".DS_Store"
        "*.swp"
        "*~"
        ".env"
        ".direnv"
      ];

      settings = {
        user = {
          name = "Mac";
          email = "contact@maclong.dev";
        };
        alias = {
          br = "branch";
          cm = "commit -m";
          co = "checkout";
          lg = "log --graph --oneline --decorate --all";
          st = "status -sb";
        };
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

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings.git_protocol = "ssh";
    };
  };
}
