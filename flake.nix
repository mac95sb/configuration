{
  description = "Mac's configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    den.url = "github:denful/den";
    import-tree.url = "github:denful/import-tree";

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs:
    let
      flake =
        (inputs.nixpkgs.lib.evalModules {
          modules = [ (inputs.import-tree ./modules) ];
          specialArgs = {
        inherit inputs;
        theme = import ./state/theme-selection.nix;
      };
        }).config.flake;
    in
    builtins.removeAttrs flake [
      "collisionPolicy"
      "denful"
      "id_hash"
      "resolved"
    ];
}
