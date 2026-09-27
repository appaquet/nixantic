{
  nixantic.sources.codexexample.commands = {
    # Commands render to Agent Skills for codex
    # (skills/<name>/SKILL.md); custom prompts were removed.
    "codex-run-checks" = {
      description = "Run the project checks and report the result.";
      harnesses = [
        "codex"
      ];
      content = "Run `just check` and report pass or fail per check.";
    };

    # A { scope } function value can reference other sources in its
    # content. There is no asSkill twin: the command already is the
    # skill, and one would collide on skills/<name>/SKILL.md.
    "codex-review" =
      { scope }:
      {
        description = "Review the working tree for scope drift.";
        harnesses = [
          "codex"
        ];

        # scope.blocks.<key>.embed inlines the block
        # .reference would emit "(See: <heading>)" instead.
        content = ''
          Summarize the diff, flag scope drift, and list follow-ups.

          ${scope.blocks."codex-conventions".embed}
        '';
      };
  };
}
