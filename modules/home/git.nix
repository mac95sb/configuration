{ den, ... }: {
  den.aspects.mac.homeManager =
    { lib, pkgs, ... }:
    {
      home.file.".config/git/allowed_signers".text = ''
        contact@maclong.dev ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHG84kHk81YW93M91uK9QqYxeT82LkZd8RndkBnISAF4 mac@mac
      '';

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
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "~/.config/git/allowed_signers";
          };
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

      home.activation.configureConfigurationGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        repo="$HOME/Developer/configuration"
        if [ -d "$repo/.git" ]; then
          run ${pkgs.git}/bin/git -C "$repo" config core.hooksPath .githooks
        fi
      '';
    };
}
