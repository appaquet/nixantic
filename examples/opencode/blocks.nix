{
  nixantic.sources.example.blocks = {
    # Blocks are never rendered on their own; other sources reference
    # them via scope.blocks.<key>.embed or .reference.
    conventions = {
      heading = "Project conventions";
      content = "Keep fragments self-contained and changes small enough to review.";
    };
  };
}
