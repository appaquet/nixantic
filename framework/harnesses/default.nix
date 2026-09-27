/*
  A harness defines platform-specific rendering and behavior for a given AI coding agent.

  Constructors pass all authored fields to the harness. Each harness decides which fields it cares
  about and how to use them.

  For each harness, we define:
  {
    name = "platform";
    outputDir = "platform";

    tools = {
      taskCreate = "platform-task-tool";
    };

    # Receives a normalized artifact and returns exactly these renderer-owned
    # values. Shared code serializes ordered frontmatter and authored overrides.
    renderArtifact = artifact: {
      outputPath = "relative/path.md";
      frontmatter = { name = artifact.name; };
      frontmatterOrder = [ "name" ];
    };

    # Alternatively a renderer may return { outputPath, embed }: the harness
    # owns the final file bytes verbatim, so shared code skips frontmatter
    # assembly and post-processing for that entry.
  }
*/

{
  renderFrontmatter,
  lib,
  settings ? { },
}:
{
  claude = import ./claude.nix { inherit renderFrontmatter; };
  codex = import ./codex.nix { inherit lib renderFrontmatter; };
  opencode = import ./opencode.nix { inherit renderFrontmatter; };
  pi = import ./pi { inherit lib settings; };
}
