{
  perSystem.prose.chapters.tutorial = [
    # markdown
    ''
      Let's create a blank Git repo.
    ''
    {
      cmd = "git";
      args = [
        "init"
        "project"
      ];
      stderr = ''Initialized blank git repository in project'';
    }
  ];
}
