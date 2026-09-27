{
  nixantic.sources.codexexample.instructions = {
    # Rendered to the harness main file (codex/AGENTS.md). Codex has no
    # separate rule files by default; rules merge into AGENTS.md.
    "codex-main" = {
      role = "main";
      harnesses = [
        "codex"
      ];
      heading = "Example project";
      content = "This project demonstrates the nixantic source format for Codex.";
    };

    # Folded into AGENTS.md (rules.output defaults to "merge-main" for codex).
    "codex-styling" = {
      role = "rule";
      harnesses = [
        "codex"
      ];
      heading = "Styling rule";
      content = "Keep prose concise and imperative.";
    };
  };
}
