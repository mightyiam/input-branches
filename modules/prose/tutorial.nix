{
  perSystem.prose.chapters.tutorial = {
    title = "Tutorial";
    contents = [
      {
        markdown =
          # markdown
          ''
            Let's create a blank Git repo.
          '';
      }
      {
        command = {
          path_ = "git";
          args = [
            "init"
            "project"
          ];
          stderr.includes = "Initialized git repository in something something";
        };
      }
    ];
  };
}
