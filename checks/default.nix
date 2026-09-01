# Flake-level integration check: module API eval, home-manager mapping, flake-parts
# consumer, and BOM assertions. Includes the renderer unit tests in framework/tests.

{
  pkgs,
  lib,
  coreModule,
  homeManagerModule,
  home-manager,
  flake-parts,
  nixpkgs,
  flakePartsModule,
  examplesPackage,
}:

let
  neutralSources = {
    fixture = {
      blocks.shared = {
        heading = "Neutral shared block";
        content = "Fixture block content";
        injectReferenceIntoCommands = true;
      };
      instructions = {
        main = {
          role = "main";
          heading = "Neutral framework fixture";
          content = "Consumer-supplied main instructions";
        };
        rule = {
          role = "rule";
          heading = "Neutral rule";
          content = "Consumer-supplied rule";
        };
        vcs =
          { scope }:
          {
            heading = "Neutral version control";
            content = scope.forSetting "versionControl.mode" {
              jj = "Neutral jj conditional";
              git = "Neutral git conditional";
            };
            harnesses = [ "claude" ];
            outputPath = "custom/vcs.md";
          };
      };
      agents.reviewer = {
        description = "Review neutral content";
        content = "Review the supplied content";
        permission.pi.allowedSubagents = false;
      };
      commands.inspect = {
        description = "Inspect neutral content";
        content = "Inspect the supplied path";
        arguments = [ { label = "Path"; } ];
        asSkill = true;
      };
      skills.reference = {
        main = {
          description = "Neutral reference skill";
          content = "Use the neutral reference";
          asCommand = true;
        };
        files."refs/example.md" = {
          kind = "md";
          content = "Neutral skill subfile";
        };
      };
    };
  };

  sourceModule = {
    nixantic.sources = neutralSources;
  };
  evalCore =
    modules:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [ coreModule ] ++ modules;
    };
  jjCore = evalCore [ sourceModule ];
  gitCore = evalCore [
    sourceModule
    { nixantic.versionControl.mode = "git"; }
  ];

  fakeClaude = pkgs.writeShellScriptBin "fake-claude" ''
    printf '%s\n%s\n' "$CLAUDE_CONFIG_DIR" "$*" > "$NIX_BUILD_TOP/claude-wrapper-result"
  '';
  fakeOpenCode = pkgs.writeShellScriptBin "fake-opencode" ''
    printf '%s\n%s\n' "$OPENCODE_CONFIG_DIR" "$*" > "$NIX_BUILD_TOP/opencode-wrapper-result"
  '';
  wrapperCore = evalCore [
    sourceModule
    {
      nixantic.instructions.wrappers.claude.executable = "${fakeClaude}/bin/fake-claude";
      nixantic.instructions.wrappers.opencode.executable = "${fakeOpenCode}/bin/fake-opencode";
    }
  ];
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      homeManagerModule
      sourceModule
      {
        home = {
          username = "nixantic";
          homeDirectory = "/home/nixantic";
          stateVersion = "24.11";
        };
        nixantic.instructions.install.files = [
          {
            harness = "claude";
            source = "CLAUDE.md";
            target = ".claude/CLAUDE.md";
          }
          {
            harness = "opencode";
            source = "AGENTS.md";
            target = ".config/opencode/AGENTS.md";
          }
          {
            harness = "pi";
            source = "AGENTS.md";
            target = ".pi/agent/AGENTS.md";
          }
          {
            harness = "pi";
            source = "agents/reviewer.md";
            target = ".pi/agent/agents/reviewer.md";
          }
        ];
        nixantic.instructions.wrappers.install = true;
      }
    ];
  };

  flakeConsumer =
    flake-parts.lib.mkFlake
      {
        inputs = {
          self.inputs = { inherit nixpkgs flake-parts; };
          inherit nixpkgs flake-parts;
        };
      }
      {
        systems = [ pkgs.system ];
        imports = [ flakePartsModule ];
        perSystem = { ... }: {
          nixantic = {
            enable = true;
            packageName = "neutral-consumer";
            checkName = "neutral-consumer";
            modules = [ sourceModule ];
          };
        };
      };
  frameworkCheck = import ../framework/checks.nix {
    inherit pkgs lib;
    package = jjCore.config.nixantic.instructions.package;
    testResult =
      let
        tests = import ../framework/tests { inherit pkgs lib; };
      in
      if tests.allPass then "pass" else throw "Nixantic instruction tests failed";
  };
in
{
  framework = frameworkCheck;
  claude-wrapper = wrapperCore.config.nixantic.instructions.wrapperChecks.claude;
  opencode-wrapper = wrapperCore.config.nixantic.instructions.wrapperChecks.opencode;
  git-claude-wrapper = gitCore.config.nixantic.instructions.wrapperChecks.claude;
  git-opencode-wrapper = gitCore.config.nixantic.instructions.wrapperChecks.opencode;
  configured-consumer = jjCore.config.nixantic.instructions.check;
  examples =
    let
      package = examplesPackage;
    in
    pkgs.runCommand "nixantic-examples-check" { } ''
      test -f ${package}/opencode/AGENTS.md
      grep -F 'This project demonstrates the nixantic source format' ${package}/opencode/AGENTS.md
      test -f ${package}/opencode/rules/styling.md
      grep -F 'Keep prose concise and imperative' ${package}/opencode/rules/styling.md
      test -f ${package}/opencode/commands/run-checks.md
      grep -F 'description: "Run the project checks and report the result."' ${package}/opencode/commands/run-checks.md
      test -f ${package}/opencode/commands/review.md
      grep -F '## Project conventions' ${package}/opencode/commands/review.md
      grep -F 'Keep fragments self-contained' ${package}/opencode/commands/review.md
      test -f ${package}/opencode/skills/review/SKILL.md
      grep -F 'name: "review"' ${package}/opencode/skills/review/SKILL.md
      grep -F '## Project conventions' ${package}/opencode/skills/review/SKILL.md
      ! grep -q 'Project conventions' ${package}/opencode/commands/run-checks.md
      test ! -e ${package}/claude/CLAUDE.md
      test ! -e ${package}/claude/rules/styling.md
      test ! -e ${package}/claude/commands/run-checks.md
      test ! -e ${package}/claude/commands/review.md
      test ! -e ${package}/claude/skills/review/SKILL.md
      test ! -e ${package}/pi/AGENTS.md
      test ! -e ${package}/pi/rules/styling.md
      test ! -e ${package}/pi/prompts/run-checks.md
      test ! -e ${package}/pi/prompts/review.md
      test ! -e ${package}/pi/skills/review/SKILL.md
      touch $out
    '';
  framework-contract = pkgs.runCommand "nixantic-framework-contract" { } ''
    test -f ${jjCore.config.nixantic.instructions.package}/claude/CLAUDE.md
    test -f ${jjCore.config.nixantic.instructions.package}/opencode/AGENTS.md
    test -f ${jjCore.config.nixantic.instructions.package}/pi/AGENTS.md
    test -f ${jjCore.config.nixantic.instructions.package}/pi/agents/reviewer.md
    test -f ${jjCore.config.nixantic.instructions.package}/pi/skills/reference/refs/example.md
    test -f ${jjCore.config.nixantic.instructions.package}/claude/custom/vcs.md
    test ! -e ${jjCore.config.nixantic.instructions.package}/opencode/custom/vcs.md
    grep -F 'Consumer-supplied rule' ${jjCore.config.nixantic.instructions.package}/pi/AGENTS.md
    grep -F 'allowed_subagents: false' ${jjCore.config.nixantic.instructions.package}/pi/agents/reviewer.md
    grep -F '(See: Neutral shared block)' ${jjCore.config.nixantic.instructions.package}/claude/commands/inspect.md
    grep -F 'argument-hint: "[path]"' ${jjCore.config.nixantic.instructions.package}/claude/commands/inspect.md
    grep -F 'argument-hint: "[path]"' ${jjCore.config.nixantic.instructions.package}/opencode/commands/inspect.md
    grep -F 'Path: $ARGUMENTS' ${jjCore.config.nixantic.instructions.package}/pi/prompts/inspect.md
    test -f ${jjCore.config.nixantic.instructions.package}/pi/skills/inspect/SKILL.md
    ! grep -F 'Path: $ARGUMENTS' ${jjCore.config.nixantic.instructions.package}/pi/skills/inspect/SKILL.md
    test -f ${jjCore.config.nixantic.instructions.package}/opencode/skills/inspect/SKILL.md
    ! grep -F 'argument-hint' ${jjCore.config.nixantic.instructions.package}/opencode/skills/inspect/SKILL.md
    grep -F 'Neutral jj conditional' ${jjCore.config.nixantic.instructions.package}/claude/custom/vcs.md
    grep -F 'Consumer-supplied main instructions' ${gitCore.config.nixantic.instructions.package}/claude/CLAUDE.md
    grep -F 'Neutral git conditional' ${gitCore.config.nixantic.instructions.package}/claude/custom/vcs.md
    touch $out
  '';
  wrapper-execution = pkgs.runCommand "nixantic-wrapper-execution" { } ''
    ${wrapperCore.config.nixantic.instructions.wrappers.packages.claude}/bin/nixantic-claude first second
    ${wrapperCore.config.nixantic.instructions.wrappers.packages.opencode}/bin/nixantic-opencode third
    grep -F '${wrapperCore.config.nixantic.instructions.package}/claude' claude-wrapper-result
    grep -F 'first second' claude-wrapper-result
    grep -F '${wrapperCore.config.nixantic.instructions.package}/opencode' opencode-wrapper-result
    grep -F 'third' opencode-wrapper-result
    touch $out
  '';
  home-manager-smoke = home.activationPackage;
  flake-parts-smoke = flakeConsumer.packages.${pkgs.system}.neutral-consumer;
}
