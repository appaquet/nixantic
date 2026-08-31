{
  nixantic.sources.example.commands = {
    # Commands render to slash commands for claude and opencode, and to
    # prompt templates (prompts/<name>.md) for pi.
    "run-checks" = {
      description = "Run the project checks and report the result.";
      harnesses = [
        "opencode"
      ];
      content = "Run `just check` and report pass or fail per check.";
    };

    # A { scope } function value can reference other sources in its
    # content. asSkill also renders this as skills/review/SKILL.md.
    review =
      { scope }:
      {
        description = "Review the working tree for scope drift.";
        harnesses = [
          "opencode"
        ];

        # Render this command as an OpenCode skill too.
        asSkill = true;

        # scope.blocks.<key>.embed inlines the block
        # .reference would emit "(See: <heading>)" instead.
        content = ''
          Summarize the diff, flag scope drift, and list follow-ups.

          ${scope.blocks.conventions.embed}
        '';
      };
  };
}
