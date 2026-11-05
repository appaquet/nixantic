# Nixantic

Nix framework for building agentic instructions for Claude Code, OpenCode, Codex and Pi.

## Features

* Declare your agent instructions, commands, skills and agents once, and render them for multiple
  harnesses with their own formats and conventions.
* Allow referencing between instructions, commands, skills, and agents, and validate those
  references at generation time.
* Reusable instruction blocks (XML or literal) with validated references at generation time, with
  ability to inject them automatically into workflows.
* Conditional content based on harnesses, version control (jj or git) or your own parameters.
* Bill of Materials (BOM) output for each harness, with a breakdown of token usage.
* Home manager plugin to reference generated files and install them into your harness directories.

## Usage

```nix
{
  inputs.nixantic.url = "github:appaquet/nixantic";
  inputs.nixantic.inputs.nixpkgs.follows = "nixpkgs";
}
```

A fragment file exports its sources under `nixantic.sources`, grouped by owner name. A main instruction and a command look like this:

```nix
# nixantic-sources/project.nix
{
  nixantic.sources = {
    project.instructions.main = {
      role = "main";
      heading = "Project instructions";
      content = "Follow this project's conventions.";
    };
    project.commands."run-checks" = {
      description = "Run the project checks.";
      content = "Run `just check` and report the result.";
    };
  };
}
```

Copy-paste examples live in `examples/opencode` and `examples/codex`. Copy those fragments into your source tree, then set `nixantic.sourceRoots = [ ./nixantic-sources ];` in the Home Manager module below.

To render the example fragments without setting anything up, run:

```sh
nix build github:appaquet/nixantic#examples
```

The rendered trees land in `./result/opencode` and `./result/codex`. The opencode tree has `AGENTS.md`, `commands/`, `rules/`, `skills/`; the codex tree has `AGENTS.md` and `skills/` (commands and skills render to the same place, rules merge into `AGENTS.md`). To build for another system, use `#packages.<system>.examples`.

### External skills

Supply an authored `SKILL.md` with `skills.<key>.main.file`, or supply a complete skill root with `directory`:

```nix
nixantic.sources.external.skills.example = {
  directory = "${skillSource}/skills/example";
  # Optional selectors apply to the complete directory:
  harnesses = [ "claude" "codex" "opencode" "pi" ];
  when = { scope }: scope.settings.versionControl.mode == "jj";
};
```

Consumers fetch and pin `skillSource`; Nixantic does not download skills. The directory must contain a regular `SKILL.md` at its root. Its declaration key determines `skills/<key>/` in each selected harness, so choose a key matching the upstream skill name. `directory` cannot be combined with `main`, `files`, or other authored fields except `harnesses` and `when`.

Directory skills copy the complete source tree unchanged, including nested and binary assets and executable bits. `.nix` companions are data, not imported fragments. Symlinks and special files are rejected. Keep dependencies and license packaging in the consumer configuration. Source inventory may realize a fetched derivation during evaluation, as with a file-backed main skill.

Post-processing does not apply to directory skills. Existing authored skills and `main.file` declarations retain their behavior. The BOM inventories every file, counts UTF-8 text at build time, and labels non-UTF-8 or NUL-containing assets `not counted (binary)` rather than including them in token totals. See `examples/opencode/skills.nix` for a complete local example.

The Home Manager module discovers every fragment file under `nixantic.sourceRoots` and renders a package of harness trees. Symlink the files you want into your harness directories:

```nix
let instructions = config.nixantic.instructions.rendered; in {
  imports = [ inputs.nixantic.homeManagerModules.default ];
  nixantic.sourceRoots = [ ./nixantic-sources ];
  nixantic.versionControl.mode = "jj";

  home.file = {
    ".claude/CLAUDE.md".source = "${instructions.package}/claude/CLAUDE.md";
    ".claude/commands".source = "${instructions.package}/claude/commands";
    ".config/opencode/AGENTS.md".source = "${instructions.package}/opencode/AGENTS.md";
    ".config/opencode/commands".source = "${instructions.package}/opencode/commands";
    ".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
    ".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  };
}
```

Licensed under MIT. See `LICENSE`.
