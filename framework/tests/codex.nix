{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  output = import ../output.nix { inherit pkgs lib; };
  codex = (import ../harnesses { renderFrontmatter = builders.renderFrontmatter; }).codex;
  scope = builders.makeScope {
    harness = codex;
    settings.harnesses.codex.rules.output = "merge-main";
    sources = {
      instructions.main = {
        role = "main";
        heading = "Main";
        content = "Main body";
      };
      instructions.rule = {
        role = "rule";
        heading = "Rule";
        content = "Rule body";
      };
      agents.reviewer = {
        description = "Review code";
        content = "Agent body.";
        model.codex = {
          model = "provider/model";
          effort = "high";
        };
      };
      agents.planner = {
        description = "Plan work";
        content = "Plan body";
      };
      commands.demo = {
        description = "Run demo";
        content = "Goal: run the demo.";
      };
      skills.authored-demo = {
        main = {
          description = "Demo skill";
          content = "Skill body";
        };
        files."refs/example.md" = {
          kind = "md";
          content = "Support";
        };
      };
    };
  };
  # A command and its asSkill companion render to the same codex skill file,
  # so package assembly must refuse the collision.
  collision = builtins.tryEval (
    (output.mkPackage {
      scopes.codex = builders.makeScope {
        harness = codex;
        sources.commands.demo = {
          description = "Run demo";
          content = "Body";
          asSkill = true;
        };
      };
    }).drvPath
  );
  postProcessed = output.mkPackage {
    scopes.codex = scope;
    postProcess = true;
  };
  postProcessedAgent = builtins.head (
    builtins.filter (
      entry: entry.relativePath == "agents/reviewer.toml"
    ) postProcessed.passthru.bom.entries.codex
  );

  cases = [
    {
      name = "Codex renders the main instruction with merged rules to AGENTS.md";
      pass =
        scope.instructions.main.outputPath == "AGENTS.md"
        && scope.instructions.main.embed == "# Main\n\nMain body\n\nRule body"
        && !(builtins.hasAttr "rule" scope.instructions);
      detail = "expected role main to select AGENTS.md and merge-main to fold the rule body into it";
    }
    {
      name = "Codex agents render standalone TOML through the embed contract";
      pass =
        scope.agents.reviewer.outputPath == "agents/reviewer.toml"
        && scope.agents.reviewer.raw
        &&
          scope.agents.reviewer.embed
          == "name = \"reviewer\"\ndescription = \"Review code\"\ndeveloper_instructions = \"\"\"\nAgent body.\n\"\"\"\nmodel = \"provider/model\"\nmodel_reasoning_effort = \"high\""
        && scope.agents.planner.outputPath == "agents/planner.toml"
        &&
          scope.agents.planner.embed
          == "name = \"planner\"\ndescription = \"Plan work\"\ndeveloper_instructions = \"\"\"\nPlan body\n\"\"\"";
      detail = "expected quoted header fields, a multiline literal instructions string, and model fields only when set";
    }
    {
      name = "Codex commands and skills render Agent Skills with name and description frontmatter";
      pass =
        scope.commands.demo.outputPath == "skills/demo/SKILL.md"
        &&
          scope.commands.demo.embed
          == "---\nname: \"demo\"\ndescription: \"Run demo\"\n---\n\nGoal: run the demo."
        && scope.skills."authored-demo".outputPath == "skills/authored-demo/SKILL.md"
        &&
          scope.skills."authored-demo".embed
          == "---\nname: \"authored-demo\"\ndescription: \"Demo skill\"\n---\n\nSkill body";
      detail = "expected the name plus description frontmatter subset and the authored body";
    }
    {
      name = "Codex skill sub-files render under the skill directory without frontmatter";
      pass =
        scope.skillFiles."skills/authored-demo/refs/example.md".outputPath
        == "skills/authored-demo/refs/example.md"
        && scope.skillFiles."skills/authored-demo/refs/example.md".embed == "Support";
      detail = "expected the authored-relative sub-file path and the raw sub-file content";
    }
    {
      name = "Codex embed entries skip post-processing";
      pass = postProcessedAgent.content == scope.agents.reviewer.embed;
      detail = "expected harness-owned TOML bytes to survive postProcess untouched, including the trailing period";
    }
    {
      name = "Codex rejects a command and asSkill skill that resolve to the same skill file";
      pass = !collision.success;
      detail = "expected the shared skills/<name>/SKILL.md destination to fail package assembly";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
