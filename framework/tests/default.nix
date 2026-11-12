{ pkgs, lib }:

let
  frontmatter = import ./frontmatter.nix;
  agents = import ./agents.nix { inherit pkgs lib; };
  artifactRendering = import ./artifact-rendering.nix { inherit pkgs lib; };
  dualOutput = import ./dual-output.nix { inherit pkgs lib; };
  postProcess = import ./post-process.nix { inherit pkgs lib; };
  verbatimSkill = import ./verbatim-skill.nix { inherit pkgs lib; };
  directorySkill = import ./directory-skill.nix { inherit pkgs lib; };
  optionSources = import ./option-sources.nix { inherit pkgs lib; };
  sourceSets = import ./source-sets.nix { inherit pkgs lib; };
  installFiles = import ./install-files.nix { inherit pkgs lib; };
  packageCollisions = import ./package-collisions.nix { inherit pkgs lib; };
  settings = import ./settings.nix { inherit pkgs lib; };
  capabilities = import ./capabilities.nix { inherit pkgs lib; };
  tasks = import ./tasks.nix { inherit pkgs lib; };
  pi = import ./pi.nix { inherit pkgs lib; };
  opencode = import ./opencode.nix { inherit pkgs lib; };
  codex = import ./codex.nix { inherit pkgs lib; };
  ruleOutput = import ./rule-output.nix { inherit pkgs lib; };

  cases = [
    {
      name = "frontmatter";
      result = frontmatter.allPass;
    }
    {
      name = "agents";
      result = agents.allPass;
    }
    {
      name = "artifact-rendering";
      result = artifactRendering.allPass;
    }
    {
      name = "dual-output";
      result = dualOutput.allPass;
    }
    {
      name = "post-process";
      result = postProcess.allPass;
    }
    {
      name = "verbatim-skill";
      result = verbatimSkill.allPass;
    }
    {
      name = "directory-skill";
      result = directorySkill.allPass;
    }
    {
      name = "option-sources";
      result = optionSources.allPass;
    }
    {
      name = "source-sets";
      result = sourceSets.allPass;
    }
    {
      name = "install-files";
      result = installFiles.allPass;
    }
    {
      name = "package-collisions";
      result = packageCollisions.allPass;
    }
    {
      name = "settings";
      result = settings.allPass;
    }
    {
      name = "capabilities";
      result = capabilities.allPass;
    }
    {
      name = "tasks";
      result = tasks.allPass;
    }
    {
      name = "pi";
      result = pi.allPass;
    }
    {
      name = "opencode";
      result = opencode.allPass;
    }
    {
      name = "codex";
      result = codex.allPass;
    }
    {
      name = "rule-output";
      result = ruleOutput.allPass;
    }
  ];

  checkCase = case: if case.result then true else throw "FAIL [${case.name}]";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;

  # Package-level assertions on built render output; the flake check builds
  # them through framework/checks.nix.
  packageChecks = [
    pi.packageCheck
    codex.packageCheck
    ruleOutput.packageCheck
    verbatimSkill.packageCheck
  ];
in
{
  inherit allPass packageChecks;
}
