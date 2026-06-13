{ inputs, pkgs, ... }: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./claude.nix
    ./git.nix
    ./zsh.nix
    ./tmux.nix
    ./ghostty.nix
    ./nvim.nix
  ];

  home = {
    username = "mac";
    homeDirectory = "/Users/mac";
    stateVersion = "25.11";

    packages = with pkgs; [
      black
      nodejs
      ripgrep
      jq
      fd
    ];
  };
}
