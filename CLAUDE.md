# Nixantic

Nix framework for building agentic instructions for Claude Code, OpenCode and Pi. Consumers own their instruction sources; the framework renders them into per-harness configuration trees.

## Work on the source, not generated output

* Edit source under `flake.nix`, `modules/`, `framework/`, `checks/`, and `examples/`, plus the root docs.
* Never hand-edit rendered output; generated trees live under build results such as `result/claude/...` and `result/opencode/...`.

## Repo map

* `flake.nix`: public flake surface, exported packages, modules, checks, and the `examples` package.
* `modules/`: module API and renderer wiring (`core.nix`) plus the Home Manager and flake-parts install adapters.
* `framework/`: renderer, per-harness output layout (`framework/harnesses/`), and tests.
* `checks/default.nix`: repo validation, including README and `examples/` coverage.
* `examples/`: consumer-facing copy-paste fragments, validated by the `examples` check.
* `source-sets.nix`: source-root discovery and duplicate detection.

## Rules

* Keep the stable consumer surface at the module API exposed from the flake.
* Keep fixtures neutral and unpublished; consumers supply their instruction sources, so no built-in corpus.
* `_support/` and `tests/` under a source root are reserved and skipped by fragment discovery, and every discovered fragment exports `nixantic.sources`.
* When you change README examples, `examples/`, or exported behavior, keep README and `examples/` consistent and verify them against `flake.nix`, `modules/`, and `checks/default.nix`.
* Load the `mem-writing` skill before creating or editing instructions, agents, commands, skills, rules, `CLAUDE.md`, or `AGENTS.md`.

## Per-harness authoring notes

* Declared `arguments`, every harness: each one injects a `<Label>: $ARGUMENTS` line after the first body line; `argument-hint` derives from the explicit hint or lowercased labels (omitted when no arguments). `$1`/`$ARGUMENTS` in body text pass through verbatim
* pi
  * Prompt frontmatter is `description` + `argument-hint` only — without declared arguments, invocation text is silently dropped by the harness
  * A command with `asSkill` also emits a verbatim-derived skill that carries no argument lines or hint
  * Skills keep only `name` + `description`; `metadata` is dropped
* claude
  * Command frontmatter additionally supports `model`, `effort`, `tools`, `disallowed-tools`, `permission-mode`
* opencode
  * Command frontmatter drops `name`, `effort`, `allowed-tools`; `context = "fork"` renders as `subtask = true`
  * Skills keep only `name`, `description`, `metadata`
* codex
  * Commands render as Agent Skills (`skills/<name>/SKILL.md`) — the harness dropped custom prompts, so a command with `asSkill = true` fails the build
  * No `argument-hint` on any artifact; agent TOML bodies must not contain `"""`

Rendered output is pinned by `framework/tests/*.nix` — that is the executable spec when in doubt

## Verify

* `nix flake check --show-trace` validates the framework.
* Keep this file to steering and pointers; README and code carry the detail.
