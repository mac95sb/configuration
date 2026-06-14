{
  inputs,
  den,
  lib,
  ...
}:
{
  imports = [ inputs.den.flakeModule ];

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.default.homeManager.home = {
    stateVersion = "25.11";
    homeDirectory = lib.mkDefault "/Users/mac";
    sessionPath = [ "$HOME/.local/bin" ];
  };
  den.default.homeManager.nixpkgs.config.allowUnfree = true;
  den.default.includes = [ den.batteries.define-user ];

  # mac host (aarch64-darwin) with mac user
  den.hosts.aarch64-darwin.mac.users.mac = { };

  den.aspects.mac = {
    includes = [ den.batteries.hostname ];

    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      lib.mkMerge [
        {
          targets.darwin.copyApps = {
            directory = "/Applications";
            enableChecks = false;
          };
        }

        (lib.mkIf config.targets.darwin.copyApps.enable {
          home.activation.copyApps = lib.mkForce (
            lib.hm.dag.entryAfter
              [
                "installPackages"
                "linkGeneration"
              ]
              (
                let
                  applications = pkgs.buildEnv {
                    name = "home-manager-applications";
                    paths = config.home.packages;
                    pathsToLink = [ "/Applications" ];
                  };
                in
                ''
                  targetFolder='/Applications'
                  oldTargetFolder="$HOME/Applications/Home Manager Apps"
                  sourceFolder='${applications}/Applications'

                  echo "setting up $targetFolder..." >&2

                  run mkdir -p "$targetFolder"

                  if [ -d "$sourceFolder" ]; then
                    find "$sourceFolder" -maxdepth 1 -mindepth 1 -name '*.app' -print0 | while IFS= read -r -d "" app; do
                      target="$targetFolder/$(basename "$app")"

                      rsyncFlags=(
                        --recursive
                        --checksum
                        --perms
                        --links
                        --copy-unsafe-links
                        --specials
                        --delete
                        --chmod=+w
                      )

                      run ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" "$app/" "$target/"

                      oldTarget="$oldTargetFolder/$(basename "$app")"
                      if [ -e "$oldTarget" ]; then
                        run rm -rf "$oldTarget"
                      fi
                    done
                  fi

                  run rmdir "$oldTargetFolder" 2>/dev/null || true
                ''
              )
          );
        })
      ];
  };
}
