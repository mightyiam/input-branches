{ lib, ... }:
{
  perSystem =
    psArgs@{ pkgs, ... }:
    let
      cfg = psArgs.config.prose;
    in
    {
      options.prose = {
        chapters = lib.mkOption {
          type = lib.types.lazyAttrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    internal = true;
                    readOnly = true;
                    default = name;
                  };
                  title = lib.mkOption {
                    type = lib.types.str;
                  };
                  contents = lib.mkOption {
                    types = lib.types.listOf (lib.types.enum [ ]);
                  };
                };
              }
            )
          );
        };
        order = lib.mkOption {
          type = lib.types.listOf lib.types.singleLineStr;
        };
        summary = lib.mkOption {
          internal = true;
          readOnly = true;
          type = lib.types.package;
        };
      };
      config = {
        prose = {
          summary = lib.pipe cfg.chapters [
            # todo here
          ];
        };
        packages.prose = pkgs.runCommand "write-prose" { } ''
          cp ${cfg.summary} summary.md
          mkbook
        '';
      };
    };
}
