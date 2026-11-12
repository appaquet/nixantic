{
  package,
  pkgs,
  lib,
  testResult,
  packageChecks ? [ ],
}:

# Generic check derivation for the renderer. Output assertions belong with the
# consumer that owns those sources.

let
  tooling = import ./builders.nix { inherit pkgs lib; };
  sourceSets = import ../source-sets.nix;
  harnesses = import ./harnesses {
    inherit lib;
    renderFrontmatter = tooling.renderFrontmatter;
  };

  renderedPackageSources = tooling.normalizeSourceDeclarations (
    sourceSets.resolveSources { sourceRoots = [ ./tests/fixtures/rendered-package ]; }
  );
  renderedPackageScopes = lib.mapAttrs (
    _: harness:
    tooling.makeScope {
      inherit harness;
      sources = renderedPackageSources.sources;
    }
  ) harnesses;
  renderedPackage = tooling.mkPackage {
    scopes = renderedPackageScopes;
    postProcess = false;
  };

  directoryFixture = import ./tests/directory-skill.nix { inherit pkgs lib; };
  directoryPackageCheck =
    pkgs.runCommand "directory-skill-package-check"
      {
        nativeBuildInputs = [ pkgs.nodejs ];
      }
      ''
        for harness in claude codex opencode pi; do
          skill=${directoryFixture.package}/"$harness"/skills/external
          diff -r ${directoryFixture.directory} "$skill"
          test -x "$skill/read-sibling.cjs"
          test "$(node "$skill/read-sibling.cjs")" = 'sibling data.'
        done
        touch "$out"
      '';

  renderedPackageCheck = pkgs.runCommand "rendered-package-check" { } ''
    test -f ${renderedPackage}/claude/CLAUDE.md
    test -f ${renderedPackage}/claude/commands/safe-command.md
    test ! -e ${renderedPackage}/claude/skills/safe-command/SKILL.md
    test -f ${renderedPackage}/opencode/AGENTS.md
    test -f ${renderedPackage}/opencode/.gitignore
    test -f ${renderedPackage}/opencode/commands/safe-command.md
    test -f ${renderedPackage}/opencode/skills/safe-command/SKILL.md
    test -f ${renderedPackage}/opencode/skills/safe-skill/SKILL.md
    test -f ${renderedPackage}/opencode/skills/safe-skill/refs/example.md
    test -f ${renderedPackage}/pi/AGENTS.md
    test -f ${renderedPackage}/pi/prompts/safe-command.md
    test -f ${renderedPackage}/pi/skills/safe-command/SKILL.md
    test -f ${renderedPackage}/pi/skills/safe-skill/SKILL.md
    test -f ${renderedPackage}/pi/skills/safe-skill/refs/example.md
    test -f ${renderedPackage}/codex/AGENTS.md
    test -f ${renderedPackage}/codex/skills/safe-command/SKILL.md
    test -f ${renderedPackage}/codex/skills/safe-skill/SKILL.md
    test -f ${renderedPackage}/codex/skills/safe-skill/refs/example.md
    grep -F '# Rendered Package Codex' ${renderedPackage}/codex/AGENTS.md
    grep -F 'description: "Run: safely # not a YAML comment"' ${renderedPackage}/codex/skills/safe-command/SKILL.md
    grep -F 'Path: $ARGUMENTS' ${renderedPackage}/codex/skills/safe-command/SKILL.md
    grep -F 'name: "safe-skill"' ${renderedPackage}/codex/skills/safe-skill/SKILL.md
    ! grep -F 'argument-hint' ${renderedPackage}/codex/skills/safe-command/SKILL.md

    grep -F 'description: "Run: safely # not a YAML comment"' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'argument-hint: "[path:with:colon]"' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'allowed-tools: ["Bash(command: test)", "Read # docs"]' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'Command body.' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'Path: $ARGUMENTS' ${renderedPackage}/claude/commands/safe-command.md
    grep -F '# Rendered Package OpenCode' ${renderedPackage}/opencode/AGENTS.md
    grep -F '# Rendered Package Pi' ${renderedPackage}/pi/AGENTS.md
    grep -F 'description: "Run: safely # not a YAML comment"' ${renderedPackage}/pi/prompts/safe-command.md
    grep -F 'argument-hint: "[path:with:colon]"' ${renderedPackage}/pi/prompts/safe-command.md
    grep -F 'Path: $ARGUMENTS' ${renderedPackage}/pi/prompts/safe-command.md
    cmp ${renderedPackage}/pi/skills/safe-command/SKILL.md <(printf '%s\n' '---' 'name: "safe-command"' 'description: "Run: safely # not a YAML comment"' '---' "" 'Command body.')
    cmp ${renderedPackage}/opencode/skills/safe-command/SKILL.md <(printf '%s\n' '---' 'name: "safe-command"' 'description: "Run: safely # not a YAML comment"' '---' "" 'Command body.')
    grep -F 'name: "safe-skill"' ${renderedPackage}/pi/skills/safe-skill/SKILL.md
    test ! -s ${renderedPackage}/opencode/.gitignore
    grep -F 'Bundled reference body.' ${renderedPackage}/opencode/skills/safe-skill/refs/example.md
    touch $out
  '';

  codexAgentToml =
    let
      agent =
        (tooling.makeScope {
          harness = harnesses.codex;
          settings.harnesses.codex.rules.output = "merge-main";
          sources.agents.reviewer = {
            description = "Review neutral content";
            content = "Review the supplied content";
            model.codex = {
              model = "provider/model";
              effort = "high";
            };
          };
        }).agents.reviewer;
    in
    agent.embed;

  codexAgentTomlFile = pkgs.writeText "codex-agent-toml" codexAgentToml;

  codexAgentTomlCheck =
    pkgs.runCommand "nixantic-codex-agent-toml-check"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        python3 -c "
        import sys
        import tomllib

        data = tomllib.load(open(sys.argv[1], 'rb'))
        assert data['name'] == 'reviewer', data
        assert data['description'] == 'Review neutral content', data
        assert data['developer_instructions'] == 'Review the supplied content\n', data
        assert data['model'] == 'provider/model', data
        assert data['model_reasoning_effort'] == 'high', data
        " ${codexAgentTomlFile}
        touch $out
      '';

  badRefCheck =
    pkgs.runCommand "bad-block-reference-check"
      {
        nativeBuildInputs = [ pkgs.nix ];
      }
      ''
        export HOME="$TMPDIR/home"
        export XDG_STATE_HOME="$TMPDIR/state"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export NIX_STATE_DIR="$TMPDIR/nix-state"
        mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$NIX_STATE_DIR/profiles"

        expr='(import ${./tests/fixtures/bad-block-reference.nix} { scope = { blocks = {}; }; }).content'
        err="$TMPDIR/bad-ref-check-err"
        nix-instantiate --eval --strict --option use-xdg-base-directories true -E "$expr" 2>"$err" && {
          echo "FAIL: nonexistent block reference should have failed evaluation" >&2
          exit 1
        }
        grep -q 'nonexistent' "$err" || {
          echo "FAIL: nonexistent block reference failed for an unexpected reason" >&2
          cat "$err" >&2
          exit 1
        }
        touch $out
      '';
in
let
  checkLines = builtins.concatStringsSep "\n" (map (c: "  : ${c}") packageChecks);
in
pkgs.runCommand "nixantic-instructions-check" { } ''
  : ${testResult}
  : ${badRefCheck}
  : ${renderedPackageCheck}
  : ${directoryPackageCheck}
  : ${codexAgentTomlCheck}
  ${checkLines}
  : ${package}
  touch $out
''
