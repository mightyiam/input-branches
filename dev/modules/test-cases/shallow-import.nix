{ baseDir, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inputName = "dummy";

      expectedGitmodules = pkgs.writeText ".gitmodules" ''
        [submodule "${baseDir}/${inputName}"]
        ''\tpath = ${baseDir}/${inputName}
        ''\turl = ./.
      '';

      dummyInputUrl = "/build/dummy-input";
    in
    {
      testCases = [
        {
          title = "shallow-import";
          module =
            pkgs.writeText "module.nix"
              # nix
              ''
                { lib, inputs, ... }:
                {
                  input-branches.inputs.dummy = {
                    upstream = {
                      url = "${dummyInputUrl}";
                      ref = "master";
                    };
                    shallow = true;
                  };
                  perSystem =
                    psArgs@{ pkgs, ... }:
                    {
                      packages.default = pkgs.symlinkJoin {
                        name = "commands";
                        paths = psArgs.config.input-branches.commands.all;
                      };
                    };

                  flake.dummy = lib.readFile (inputs.dummy + "/content");
                }
              '';

          script = pkgs.writeShellApplication {
            name = "script";
            runtimeInputs = [ pkgs.jq ];
            text = ''
              set -o xtrace

              actual_content=$(nix eval --raw .#dummy)
              expect_content="original"
              if [ "$actual_content" != "$expect_content" ]; then
                declare -p actual_content
                declare -p expect_content
                exit 1
              fi

              upstream_rev=$( (
                cd ../dummy-input
                git commit --quiet --allow-empty --message "additional"
                git rev-parse HEAD
              ))

              nix flake update ${inputName}

              result=$(nix build --no-link --print-out-paths)
              "$result/bin/input-branch-init-dummy"

              expect_commit_message="squashed upstream $upstream_rev"

              actual_commit_message="$( (
                cd ${baseDir}/${inputName}
                git log -1 --pretty=%B
              ))"

              if [ "$actual_commit_message" != "$expect_commit_message" ]; then
                declare -p actual_commit_message
                declare -p expect_commit_message
                exit 1
              fi

              sed --in-place 's#"git+file:///build/dummy-input"#"./${baseDir}/${inputName}"#' flake.nix

              git add .
              git commit -m'input-branch'
              "$result/bin/input-branch-push-force-dummy"
              git push

              if ! diff_output=$(diff --unified ${expectedGitmodules} .gitmodules); then
                  echo "$diff_output"
                  exit 1
              fi

              actual_remotes=$( (
                cd ${baseDir}/${inputName}
                git remote --verbose
              ))
              expect_remotes="\
              origin''\t/build/./origin/. (fetch)
              origin''\t/build/./origin/. (push)
              upstream''\t${dummyInputUrl} (fetch)
              upstream''\t${dummyInputUrl} (push)"

              if [ "$actual_remotes" != "$expect_remotes" ]; then
                declare -p actual_remotes
                declare -p expect_remotes
                exit 1
              fi

              actual_refs=$( (
                cd ${baseDir}/${inputName}
                git show-ref --abbrev=4 | cut -d' ' -f2
              ))
              expect_refs="\
              refs/heads/inputs/main/dummy
              refs/heads/main
              refs/remotes/origin/HEAD
              refs/remotes/origin/inputs/main/dummy
              refs/remotes/origin/main"

              if [ "$actual_refs" != "$expect_refs" ]; then
                declare -p actual_refs
                declare -p expect_refs
                exit 1
              fi

              actual_origin_fetch_refspec=$( (
                cd ${baseDir}/${inputName}
                git config --get remote.origin.fetch
              ))
              expect_origin_fetch_refspec='+refs/heads/*:refs/remotes/origin/*'

              if [ "$actual_origin_fetch_refspec" != "$expect_origin_fetch_refspec" ]; then
                declare -p actual_origin_fetch_refspec
                declare -p expect_origin_fetch_refspec
                exit 1
              fi

              actual_upstream_fetch_refspec=$( (
                cd ${baseDir}/${inputName}
                git config --get remote.upstream.fetch
              ))
              expect_upstream_fetch_refspec='+refs/heads/*:refs/remotes/upstream/*'

              if [ "$actual_upstream_fetch_refspec" != "$expect_upstream_fetch_refspec" ]; then
                declare -p actual_upstream_fetch_refspec
                declare -p expect_upstream_fetch_refspec
                exit 1
              fi

              actual_checked_out_branch=$( (
                cd ${baseDir}/${inputName}
                git branch --show-current
              ))
              expect_checked_out_branch="inputs/main/dummy"

              if [ "$actual_checked_out_branch" != "$expect_checked_out_branch" ]; then
                declare -p actual_checked_out_branch
                declare -p expect_checked_out_branch
                exit 1
              fi

              submodule_commit_count=$( (
                cd ${baseDir}/${inputName}
                git log --oneline | wc --lines
              ))

              if [ "$submodule_commit_count" -ne 1 ]; then
                declare -p submodule_commit_count
                exit 1
              fi

              submodule_rev=$( (
                cd ${baseDir}/${inputName}
                git rev-parse HEAD
              ))

              if [ "$submodule_rev" == "$upstream_rev" ]; then
                declare -p submodule_rev
                exit 1
              fi

              new_submodule_content="altered"

              (
                cd ${baseDir}/${inputName}
                echo -n "$new_submodule_content" > content
                git add content
                git commit --quiet --message "change"
              )

              git add .
              git commit --message "inputs/dummy change"
              "$result/bin/input-branch-push-force-dummy"
              git push

              actual_submodule_content=$(nix eval --raw .#dummy)
              expect_submodule_content="$new_submodule_content"

              if [ "$actual_submodule_content" != "$expect_submodule_content" ]; then
                declare -p actual_submodule_content
                declare -p expect_submodule_content
                exit 1
              fi

              result=$(nix build --no-link --print-out-paths)
              "$result/bin/input-branch-rebase-dummy"
              git add inputs/dummy
              git commit --message "inputs/dummy rebase"
              "$result/bin/input-branch-push-force-dummy"
              git push

              submodule_commit_count=$( (
                cd ${baseDir}/${inputName}
                git log --oneline | wc --lines
              ))

              if [ "$submodule_commit_count" -ne 2 ]; then
                declare -p submodule_commit_count
                exit 1
              fi

              expect_first_commit_message="squashed upstream $upstream_rev"

              actual_first_commit_message="$( (
                cd ${baseDir}/${inputName}
                git log HEAD~ -1 --pretty=%B
              ))"

              if [ "$actual_first_commit_message" != "$expect_first_commit_message" ]; then
                declare -p actual_first_commit_message
                declare -p expect_first_commit_message
                exit 1
              fi

              actual_submodule_content=$(nix eval --raw .#dummy)
              expect_submodule_content="$new_submodule_content"

              if [ "$actual_submodule_content" != "$expect_submodule_content" ]; then
                declare -p actual_submodule_content
                declare -p expect_submodule_content
                exit 1
              fi

              new_submodule_rev=$( (
                cd ${baseDir}/${inputName}
                git rev-parse HEAD
              ))

              git fetch origin
              new_origin_rev=$(git rev-parse origin/inputs/main/${inputName})

              if [ "$new_submodule_rev" != "$new_origin_rev" ]; then
                declare -p new_submodule_rev
                declare -p new_origin_rev
                exit 1
              fi

              declare out
              touch "$out"
            '';
          };
        }
      ];
    };
}
