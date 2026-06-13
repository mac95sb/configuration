{ inputs, den, lib, ... }: {
  imports = [ inputs.den.flakeModule ];

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  den.default.homeManager.home.stateVersion = "25.11";

  # mac host (aarch64-darwin) with mac user
  den.hosts.aarch64-darwin.mac.users.mac = {};

  den.aspects.mac = {
    includes = [ den.batteries.hostname ];
  };
}
