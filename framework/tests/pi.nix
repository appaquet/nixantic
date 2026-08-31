{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  output = import ../output.nix { inherit pkgs lib; };
  pi = import ../harnesses/pi.nix { inherit lib; };
  scope = builders.makeScope {
    harness = pi;
    settings.harnesses.pi.rules.output = "merge-main";
    sources = {
      blocks.intro = {
        content = "Intro line from block";
      };
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
        content = "Agent body";
        model.pi = {
          model = "provider/model";
          effort = "high";
        };
        permission.pi = {
          tools = [
            "read"
            "bash"
          ];
          disallowedTools = [ "write" ];
          extensions = [ "ext:tasks" ];
          excludeExtensions = [ "ext:unsafe" ];
          skills = false;
          allowedSubagents = [ "explorer" ];
          persistSession = true;
          isolated = true;
          isolation = "worktree";
        };
      };
      commands.demo = {
        description = "Run demo";
        content = "Goal: run the demo for $1.\n\nThe prompt keeps $1 for positional use.";
        arguments = [ { label = "Question"; } ];
        asSkill = {
          pi = true;
        };
      };
      commands.think = {
        description = "Think deeply";
        content = "Goal: reason about the problem.";
        arguments = [
          {
            label = "Problem";
            hint = "[problem or context]";
          }
        ];
      };
      commands.blocky =
        { scope }:
        {
          description = "Block-led command";
          content = "${scope.blocks.intro.body}\n\nRest of the body.";
          arguments = [ { label = "Target"; } ];
        };
      skills.authored-demo = {
        main = {
          description = "Demo skill";
          content = "Skill body";
          metadata = {
            ignored = "by-pi";
          };
        };
        files."refs/example.md" = {
          kind = "md";
          content = "Support";
        };
      };
    };
  };
  invalidPolicy = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.agents.invalid = {
        description = "Invalid";
        content = "Agent body";
        permission.pi.permissionMode = "bypassPermissions";
      };
    }).agents.invalid.embed
  );
  invalidPolicyValue = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.agents.invalid = {
        description = "Invalid";
        content = "Agent body";
        permission.pi.persistSession = "yes";
      };
    }).agents.invalid.embed
  );
  invalidArgumentLabel = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.commands.invalid = {
        description = "Invalid";
        content = "Body";
        arguments = [ { label = ""; } ];
      };
    }).commands.invalid.embed
  );
  invalidArgumentType = builtins.tryEval (
    (builders.makeScope {
      harness = pi;
      sources.commands.invalid = {
        description = "Invalid";
        content = "Body";
        arguments = [ { label = 1; } ];
      };
    }).commands.invalid.embed
  );
  overriddenScope = builders.makeScope {
    harness = pi;
    sources.commands.demo = {
      description = "Run demo";
      content = "Body";
      outputPath = "custom/prompt.md";
    };
  };
  package = output.mkPackage { scopes.pi = scope; };
  bomEntries = package.passthru.bom.entries.pi;

  cases = [
    {
      name = "Pi renders native context, prompt, skill, and support-file paths";
      pass =
        scope.instructions.main.outputPath == "AGENTS.md"
        && scope.commands.demo.outputPath == "prompts/demo.md"
        && scope.skills."authored-demo".outputPath == "skills/authored-demo/SKILL.md"
        &&
          scope.skillFiles."skills/authored-demo/refs/example.md".outputPath
          == "skills/authored-demo/refs/example.md"
        && scope.extraSkillsFromCommands."skills/demo/SKILL".outputPath == "skills/demo/SKILL.md";
      detail = "expected Pi-native destinations and merged rules in AGENTS.md";
    }
    {
      name = "Pi command renders declared arguments after the first content line";
      pass =
        scope.commands.demo.embed
        ==
          "---\ndescription: \"Run demo\"\nargument-hint: \"[question]\"\n---\n\nGoal: run the demo for $1.\nQuestion: $ARGUMENTS\n\nThe prompt keeps $1 for positional use.";
      detail = "expected the argument line after the first content line and a derived argument hint";
    }
    {
      name = "Pi argument hint override renders verbatim";
      pass =
        scope.commands.think.embed
        ==
          "---\ndescription: \"Think deeply\"\nargument-hint: \"[problem or context]\"\n---\n\nGoal: reason about the problem.\nProblem: $ARGUMENTS";
      detail = "expected the explicit per-argument hint to replace the derived one";
    }
    {
      name = "Pi command argument injection runs on final block-interpolated content";
      pass =
        scope.commands.blocky.embed
        ==
          "---\ndescription: \"Block-led command\"\nargument-hint: \"[target]\"\n---\n\nIntro line from block\nTarget: $ARGUMENTS\n\nRest of the body.";
      detail = "expected the argument line after the first line of the interpolated block content";
    }
    {
      name = "Pi derived skill renders the command content verbatim";
      pass =
        scope.extraSkillsFromCommands."skills/demo/SKILL".embed
        ==
          "---\nname: \"demo\"\ndescription: \"Run demo\"\n---\n\nGoal: run the demo for $1.\n\nThe prompt keeps $1 for positional use."
        &&
          scope.instructions."skills/demo/SKILL".embed
          ==
          "---\nname: \"demo\"\ndescription: \"Run demo\"\n---\n\nGoal: run the demo for $1.\n\nThe prompt keeps $1 for positional use.";
      detail = "expected no argument line and no argument hint in the command-derived skill";
    }
    {
      name = "Pi authored skills render the Agent Skills metadata subset";
      pass =
        scope.skills."authored-demo".embed
        == "---\nname: \"authored-demo\"\ndescription: \"Demo skill\"\n---\n\nSkill body";
      detail = "expected name and description only, without Claude/OpenCode metadata";
    }
    {
      name = "Pi keeps authored entry paths and logical BOM kinds";
      pass =
        overriddenScope.commands.demo.outputPath == "custom/prompt.md"
        && builtins.any (
          entry: entry.relativePath == "prompts/demo.md" && entry.category == "commands"
        ) bomEntries
        && builtins.any (
          entry: entry.relativePath == "skills/demo/SKILL.md" && entry.category == "skills"
        ) bomEntries
        && builtins.any (
          entry:
          entry.relativePath == "skills/authored-demo/refs/example.md" && entry.category == "skillSubfiles"
        ) bomEntries;
      detail = "expected common authored-path precedence and logical kinds to survive Pi-native paths";
    }
    {
      name = "tintinweb agents render plugin path and ordered snake_case policy fields";
      pass =
        scope.agents.reviewer.outputPath == "agents/reviewer.md"
        &&
          scope.agents.reviewer.embed
          == "---\nname: \"reviewer\"\ndescription: \"Review code\"\ntools: [\"read\", \"bash\"]\ndisallowed_tools: [\"write\"]\nextensions: [\"ext:tasks\"]\nexclude_extensions: [\"ext:unsafe\"]\nskills: false\nallowed_subagents: [\"explorer\"]\nmodel: \"provider/model\"\nthinking: \"high\"\npersist_session: true\nisolated: true\nisolation: \"worktree\"\n---\n\nAgent body";
      detail = "expected the tintinweb agent schema in its declared field order";
    }
    {
      name = "tintinweb rejects unsupported policy fields";
      pass = !invalidPolicy.success && !invalidPolicyValue.success;
      detail = "expected unsupported fields and invalid values to fail instead of being silently ignored";
    }
    {
      name = "Pi rejects invalid command argument labels";
      pass = !invalidArgumentLabel.success && !invalidArgumentType.success;
      detail = "expected empty and non-string argument labels to fail instead of rendering";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
