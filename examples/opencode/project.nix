{
  nixantic.sources.example.instructions = {
    # Rendered to the harness main file (CLAUDE.md for claude, AGENTS.md for opencode and pi).
    main = {
      role = "main";
      harnesses = [
        "opencode"
      ];
      heading = "Example project";
      content = "This project demonstrates the nixantic source format for OpenCode.";
    };

    # Rendered to rules/<key>.md.
    styling = {
      role = "rule";
      harnesses = [
        "opencode"
      ];
      heading = "Styling rule";
      content = "Keep prose concise and imperative.";
    };
  };
}
