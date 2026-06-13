{ den, ... }: {
  den.aspects.mac.homeManager = { ... }: {
    programs.claude-code = {
      enable = true;
      settings = {
        theme = "dark";
        attribution = {
          commit = "";
          pr = "";
        };
      };
      context = ''
        When writing code comments, only explain *why* something is done when
        the reason is non-obvious (e.g. a subtle invariant, a workaround for a
        specific bug, a hidden constraint). Never write comments that describe
        *what* the code does — well-named identifiers already do that. Examples
        of comments to avoid: "Moved X to Y", "Added handler for Z", "Loop over
        items". Examples of comments worth keeping: "pam_tid must come before
        pam_opendirectory or Touch ID is silently skipped on macOS 14+".
      '';
    };

    programs.codex = {
      enable = true;
      context = ''
        When writing code comments, only explain *why* something is done when
        the reason is non-obvious (e.g. a subtle invariant, a workaround for a
        specific bug, a hidden constraint). Never write comments that describe
        *what* the code does — well-named identifiers already do that. Examples
        of comments to avoid: "Moved X to Y", "Added handler for Z", "Loop over
        items". Examples of comments worth keeping: "pam_tid must come before
        pam_opendirectory or Touch ID is silently skipped on macOS 14+".
      '';
    };
  };
}
