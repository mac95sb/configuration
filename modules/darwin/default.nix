{ pkgs, inputs, ... }: {
  imports = [
    ./system.nix
    ./homebrew.nix
  ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  environment.systemPackages = with pkgs; [
    git
    tree-sitter
  ];

  users.users.mac = {
    name = "mac";
    home = "/Users/mac";
  };

  system.stateVersion = 6;
}
