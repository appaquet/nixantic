{
  nixantic.sources.codexexample.blocks = {
    # Blocks are never rendered on their own; other sources reference
    # them via scope.blocks.<key>.embed or .reference.
    "codex-conventions" = {
      heading = "Project conventions";
      content = "Keep fragments self-contained and changes small enough to review.";
    };
  };
}
