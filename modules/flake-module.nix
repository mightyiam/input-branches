{
  flake.flakeModules.default =
    {
      inputs,
      lib,
      flake-parts-lib,
      config,
      ...
    }:
    let
      cfg = config.input-branches;
      # This can probably be wrong in some cases
      remoteName = "origin";
      cmdBase = "input-branch";
      cmdPrefix = lib.genAttrs [ "init" "rebase" "push-force" ] (n: "${cmdBase}-${n}");
      shallowCommitMessage = "shallow input branch";
    in
    {
      options = {
        input-branches = {
          baseDir = lib.mkOption {
            type = lib.types.str;
            description = ''
              Directory relative to Git top-level for git submodules.
            '';
            readOnly = true;
            default = "inputs";
          };

          inputs = lib.mkOption {
            default = { };
            defaultText = ''{ }'';
            description = ''
              Input branch definitions.
              Each attribute name must correspond to an existing flake input.
            '';
            example =
              lib.literalExpression
                # nix
                ''
                  {
                    nixpkgs.upstream = {
                      url = "https://github.com/NixOS/nixpkgs.git";
                      ref = "nixpkgs-unstable";
                    };
                    home-manager.upstream = {
                      url = "https://github.com/nix-community/home-manager.git";
                      ref = "master";
                    };
                  }
                '';
            type = lib.types.lazyAttrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      description = ''
                        Name of input.
                        A flake input by this name must exist.
                      '';
                      example = lib.literalExpression ''"flake-parts"'';
                      default = name;
                      defaultText = lib.literalMD "`<name>`";
                    };

                    shallow = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      example = true;
                      description = ''
                        Useful for an input with huge history, such as Nixpkgs.
                        Fetching occurs with `--depth 1`.
                        The input branch is initialized with a single, artificial, initial commit.
                        Prior to rebasing such a commit is recreated.
                      '';
                    };

                    upstream = {
                      url = lib.mkOption {
                        type = lib.types.str;
                        example = lib.literalExpression ''"https://github.com/nix-community/stylix.git"'';
                        description = ''
                          remote URL of the upstream Git repo
                        '';
                      };
                      ref = lib.mkOption {
                        type = lib.types.str;
                        description = ''
                          ref of the upstream Git repo
                        '';
                        example = lib.literalExpression ''"master"'';
                      };
                      name = lib.mkOption {
                        readOnly = true;
                        type = lib.types.str;
                        default = "upstream";
                        description = ''
                          remote upstream name
                        '';
                      };
                    };
                    path_ = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      description = ''
                        path of submodule relative to Git top-level
                      '';
                      default = "${cfg.baseDir}/${name}";
                      defaultText = lib.literalMD "`${cfg.baseDir}/<name>`";
                    };
                    branch = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      description = ''
                        input branch name
                      '';
                      default = "inputs/${name}";
                      defaultText = lib.literalMD "`inputs/<name>`";
                    };
                  };
                }
              )
            );
          };
        };
        perSystem = flake-parts-lib.mkPerSystemOption {
          options.input-branches = {
            commands = {
              init = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                readOnly = true;
                description = ''
                  A list of `${cmdPrefix.init}-<INPUT>` commands
                  that attempt to initialize `INPUT`.
                  For example:

                  ```
                  $ ${cmdPrefix.init}-nixpkgs
                  ```

                  And you end up with a git submodule at the configured path.
                  It inherited the remote of the remote tracking branch of the current branch.
                  It has an upstream remote according to configuration.
                  The configured branch is checked out
                  and its HEAD set to the rev that the corresponding flake input is locked to.
                  The input url can be set to use it:

                  ```nix
                  {
                    inputs.flake-parts.url = "./${cfg.baseDir}/nixpkgs";
                  }
                  ```

                  Pushing is the last action this command takes,
                  so if that fails you can step into the directory
                  and attempt to resolve the matter.
                '';
              };
              rebase = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                readOnly = true;
                description = ''
                  a list of `${cmdPrefix.rebase}-<INPUT>` commands
                  that attempt to rebase `INPUT`
                '';
              };
              push-force = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                readOnly = true;
                description = ''
                  a list of `${cmdPrefix.push-force}-<INPUT>` commands
                  that push with `--force` the configured branch of `INPUT`
                '';
              };

              all = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                readOnly = true;
                description = ''
                  a list of all of the commands, for convenience
                '';
              };
            };
          };
        };
      };

      config.perSystem =
        { pkgs, ... }:
        {
          input-branches = {
            commands = lib.pipe cfg.inputs [
              lib.attrValues
              (map (
                {
                  name,
                  upstream,
                  path_,
                  branch,
                  shallow,
                }:
                let
                  cdToplevel = ''
                    toplevel=$(git rev-parse --show-toplevel)
                    cd "$toplevel"
                  '';
                  ensure-upstream = ''
                    if ! git remote get-url ${upstream.name} > /dev/null 2>&1; then
                      git remote add ${upstream.name} "${upstream.url}"
                    fi
                  '';
                in
                {
                  init =
                    if (inputs.${name} ? rev) then
                      (pkgs.writeShellApplication {
                        name = "${cmdPrefix.init}-${name}";
                        runtimeInputs = [ pkgs.git ];
                        text =
                          ''
                            set -o xtrace
                            ${cdToplevel}

                            current_branch_remote_name=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" | cut -d'/' -f1)
                            git submodule add ./. "${path_}"
                            (
                              cd "${path_}"
                              ${ensure-upstream}
                              git fetch ${lib.optionalString shallow "--depth 1"} ${upstream.name} "${inputs.${name}.rev}"
                          ''
                          + (
                            if shallow then
                              ''
                                git switch --orphan "${branch}"
                                git checkout "${inputs.${name}.rev}" .
                                git add .
                                git commit --message "${shallowCommitMessage}"
                              ''
                            else
                              ''
                                git switch --create "${branch}" "${inputs.${name}.rev}"
                              ''
                          )
                          + ''
                              git push --set-upstream "$current_branch_remote_name" "${branch}"
                            )
                            git config --file .gitmodules submodule.${path_}.url "./."
                          '';
                      })
                    else
                      null;

                  rebase = pkgs.writeShellApplication {
                    name = "${cmdPrefix.rebase}-${name}";
                    runtimeInputs = [ pkgs.git ];
                    text =
                      ''
                        set -o xtrace
                        ${cdToplevel}
                        cd "${path_}"
                        if [ -n "$(git status --porcelain)" ]; then
                          exit 70
                        fi
                        ${ensure-upstream}
                        git fetch ${lib.optionalString shallow "--depth 1"} ${upstream.name} "${upstream.ref}"
                        git fetch ${remoteName} "${branch}"
                      ''
                      + (
                        if shallow then
                          lib.concatLines [
                            ''
                              git switch --orphan _input-branches-temp
                              git checkout "${upstream.name}/${upstream.ref}" .
                              git add .
                              git commit --message "${shallowCommitMessage}"
                              git switch "${branch}"
                            ''
                            # If this is replaced with a naive `git rebase _input-branches-temp`,
                            # tests might still pass, but in actual usage a failure has been observed,
                            # which I have failed to reproduce in tests.
                            ''
                              git rebase --onto=_input-branches-temp "$(git rev-list --max-parents=0 HEAD)" HEAD
                              git branch --force "${branch}" HEAD
                              git switch "${branch}"
                              git branch --delete --force _input-branches-temp
                            ''
                          ]
                        else
                          ''
                            git switch "${branch}"
                            git rebase "${upstream.name}/${upstream.ref}"
                          ''
                      );
                  };

                  push-force = pkgs.writeShellApplication {
                    name = "${cmdPrefix.push-force}-${name}";
                    runtimeInputs = [ pkgs.git ];
                    text = ''
                      set -o xtrace
                      ${cdToplevel}
                      cd "${path_}"
                      ${ensure-upstream}
                      git push -f ${remoteName} "${branch}:${branch}"
                    '';
                  };
                }
              ))

              (lib.fold (cur: acc: {
                init = acc.init ++ (if cur.init != null then [ cur.init ] else [ ]);
                rebase = acc.rebase ++ [ cur.rebase ];
                push-force = acc.push-force ++ [ cur.push-force ];
              }) (lib.genAttrs [ "init" "rebase" "push-force" ] (_: [ ])))

              (commands: {
                inherit (commands) init rebase push-force;
                all = lib.concatLists (
                  with commands;
                  [
                    init
                    rebase
                    push-force
                  ]
                );
              })
            ];
          };
        };
    };
}
