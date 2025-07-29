{ lib, html, ... }:
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
              chapterArgs@{ name, ... }:
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
                    type = lib.types.listOf (
                      lib.types.attrTag {
                        markdown = lib.mkOption { type = lib.types.str; };
                        command = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              path_ = lib.mkOption { type = lib.types.str; };
                              args = lib.mkOption {
                                type = lib.types.listOf lib.types.str;
                                default = [ ];
                              };
                              stdout = lib.mkOption {
                                type = lib.types.str;
                                default = "[\\s\\S]*";
                              };
                              stderr = lib.mkOption {
                                type = lib.types.str;
                                default = "[\\s\\S]*";
                              };
                            };
                          };
                        };
                      }
                    );
                  };
                  rendered = lib.mkOption {
                    internal = true;
                    readOnly = true;
                    type = lib.types.str;
                    default = lib.pipe chapterArgs.config.contents [
                      (map (
                        piece:
                        piece.markdown or (
                          let
                            inherit (piece) command;
                            inherit (html) h;
                          in
                          with html.tags;
                          h "command" [
                            (h "path" command.path_)
                            (h "arguments" (map (h "argument") command.args))
                            (h "output" [
                              (p "Stdout:")
                              (h "stdout" command.stdout)
                              (p "Stderr:")
                              (h "stderr" command.stderr)
                            ])
                          ]
                        )
                      ))
                      html.render
                    ];
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
        bookToml = lib.mkOption {
          type = lib.types.anything;
          internal = true;
          readOnly = true;
        };
        chapterFiles = lib.mkOption {
          type = lib.types.package;
          internal = true;
          readOnly = true;
        };
      };
      config = {
        prose = {
          bookToml = pkgs.writers.writeTOML "book.toml" {
            build.create-missing = false;
          };
          chapterFiles = lib.pipe cfg.chapters [
            lib.attrValues
            (map (chapter: pkgs.writeTextDir "${chapter.name}.md" chapter.rendered))
            (
              paths:
              pkgs.symlinkJoin {
                name = "chapter-files";
                inherit paths;
              }
            )
          ];
          summary = lib.pipe cfg.order [
            (map (lib.flip lib.getAttr cfg.chapters))
            (map (chapter: "[${chapter.title}](${chapter.name}.md)"))
            lib.concatLines
            (pkgs.writeText "SUMMARY.md")
          ];
        };
        packages.prose = pkgs.runCommand "write-prose" { nativeBuildInputs = [ pkgs.mdbook ]; } ''
          mkdir src
          ln -s ${cfg.bookToml} book.toml
          for file in ${cfg.chapterFiles}/*; do ln -s "$file" src; done
          ln -s ${cfg.summary} src/SUMMARY.md
          mdbook build --dest-dir $out
        '';
      };
    };
}
