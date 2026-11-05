{
  package,
  pkgs,
  lib,
  testResult,
}:

# Generic check derivation for the renderer. Output assertions belong with the
# consumer that owns those sources.

let
  tooling = import ./builders.nix { inherit pkgs lib; };
  bomRendererPython = pkgs.python3.withPackages (_: [ pkgs.python3Packages.tiktoken ]);
  sourceSets = import ../source-sets.nix;
  harnesses = import ./harnesses {
    inherit lib;
    renderFrontmatter = tooling.renderFrontmatter;
  };
  missingVendoredEncodingManifest = pkgs.writeText "missing-vendored-encoding-manifest.json" (
    builtins.toJSON {
      harness = "claude";
      encoding = "cl100k_base";
      encodingPath = "/definitely/missing-cl100k_base.tiktoken";
      encodingHash = "223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7";
      entries = [ ];
    }
  );

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
        nativeBuildInputs = [
          pkgs.nodejs
          pkgs.python3
        ];
      }
      ''
        for harness in claude codex opencode pi; do
          skill=${directoryFixture.package}/"$harness"/skills/external
          diff -r ${directoryFixture.directory} "$skill"
          test -x "$skill/read-sibling.cjs"
          test "$(node "$skill/read-sibling.cjs")" = 'sibling data.'
        done
        python3 - ${directoryFixture.package} <<'PY'
        import pathlib
        import sys

        for harness in ("claude", "codex", "opencode", "pi"):
            report = (pathlib.Path(sys.argv[1]) / harness / "BOM.md").read_text()
            rows = report.split("## Per-file rows\n", 1)[1].split("## Root/main", 1)[0]
            files = [line.split("|")[1:-1] for line in rows.splitlines() if line.startswith("| ")]
            values = {cells[1].strip(): cells[2].strip() for cells in files[2:]}
            assert values["skills/external/data.bin"] == "not counted (binary)", values
            counted = sum(int(value) for value in values.values() if value.isdecimal())
            total = report.split("## Harness total\n", 1)[1].split("## Category totals", 1)[0]
            assert f"| {len(values)} | {counted} |" in total, total
            assert sum(name.startswith("skills/external/") for name in values) == 6, values
        PY
        touch "$out"
      '';

  renderedPackageCheck = pkgs.runCommand "rendered-package-check" { } ''
    test -f ${renderedPackage}/claude/CLAUDE.md
    test -f ${renderedPackage}/claude/BOM.md
    test -f ${renderedPackage}/claude/commands/safe-command.md
    test ! -e ${renderedPackage}/claude/skills/safe-command/SKILL.md
    test -f ${renderedPackage}/opencode/AGENTS.md
    test -f ${renderedPackage}/opencode/BOM.md
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
    test -f ${renderedPackage}/codex/BOM.md
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
    grep -F '# Instruction BOM: claude' ${renderedPackage}/claude/BOM.md
    grep -F 'Estimated token counts using tiktoken encoding `cl100k_base`' ${renderedPackage}/claude/BOM.md
    grep -F 'not provider-authoritative context billing' ${renderedPackage}/claude/BOM.md
    grep -F '| Generated instructions | 1 |' ${renderedPackage}/claude/BOM.md
    grep -F '| Commands | 1 |' ${renderedPackage}/claude/BOM.md
    grep -F '| Skills | 2 |' ${renderedPackage}/opencode/BOM.md
    grep -F '| Skill subfiles | 1 |' ${renderedPackage}/opencode/BOM.md
    grep -F '| skills/safe-skill/refs/example.md |' ${renderedPackage}/opencode/BOM.md
    grep -F '## Root/main instruction summary' ${renderedPackage}/claude/BOM.md
    grep -F '## Per-command file-cost' ${renderedPackage}/claude/BOM.md
    ! grep -F '| BOM.md |' ${renderedPackage}/claude/BOM.md
    touch $out
  '';

  missingVendoredEncodingCheck =
    pkgs.runCommand "missing-vendored-encoding-check"
      {
        nativeBuildInputs = [ bomRendererPython ];
      }
      ''
        err="$TMPDIR/missing-vendored-encoding.err"
        python ${./render-bom.py} ${missingVendoredEncodingManifest} "$TMPDIR/BOM.md" 2>"$err" && {
          echo "FAIL: missing vendored encoding asset should have failed" >&2
          exit 1
        }
        grep -F 'Missing local tiktoken encoding asset for BOM generation' "$err" || {
          echo "FAIL: missing vendored encoding asset failed for an unexpected reason" >&2
          cat "$err" >&2
          exit 1
        }
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
pkgs.runCommand "nixantic-instructions-check" { } ''
  : ${testResult}
  : ${badRefCheck}
  : ${missingVendoredEncodingCheck}
  : ${renderedPackageCheck}
  : ${directoryPackageCheck}
  : ${codexAgentTomlCheck}
  : ${package}
  touch $out
''
