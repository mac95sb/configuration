{ inputs, lib, ... }:
let
  systems = [
    "aarch64-darwin"
  ];

  forSystems =
    fn:
    lib.genAttrs systems (
      system:
      fn (
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      )
    );

  treefmt =
    pkgs:
    pkgs.treefmt.withConfig {
      name = "configuration-treefmt";

      runtimeInputs = with pkgs; [
        deno
        nixfmt
      ];

      settings = {
        on-unmatched = "info";
        tree-root-file = "flake.nix";

        formatter = {
          nixfmt = {
            command = "nixfmt";
            includes = [ "*.nix" ];
          };

          deno_fmt = {
            command = "deno";
            options = [ "fmt" ];
            includes = [ "*.md" ];
          };
        };
      };
    };

  nixLint =
    pkgs:
    pkgs.runCommandLocal "configuration-nix-lint"
      {
        nativeBuildInputs = with pkgs; [
          deadnix
          statix
        ];

        src = pkgs.lib.cleanSourceWith {
          src = ../.;
          filter =
            path: type:
            type == "directory" || pkgs.lib.hasSuffix ".nix" path || baseNameOf path == "statix.toml";
        };
      }
      ''
        cp -R "$src" source
        chmod -R u+w source
        cd source

        statix check .
        deadnix --no-lambda-arg --no-lambda-pattern-names --fail .

        touch "$out"
      '';
in
{
  flake = {
    formatter = forSystems treefmt;

    checks = forSystems (pkgs: {
      formatting = (treefmt pkgs).check ../.;
      nix-lint = nixLint pkgs;
    });
  };
}
