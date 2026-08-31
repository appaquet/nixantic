# Nixantic

Nix framework for building agentic instructions for Claude Code, OpenCode and Pi.

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

A copy-paste OpenCode example lives in `examples/opencode`. Copy those fragments into your source tree, then set `nixantic.sourceRoots = [ ./nixantic-sources ];` in the Home Manager module below.

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
