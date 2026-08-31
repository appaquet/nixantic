{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  opencode = (import ../harnesses { renderFrontmatter = builders.renderFrontmatter; }).opencode;
  scope = builders.makeScope {
    harness = opencode;
    sources = {
      commands.demo = {
        description = "Run demo";
        content = "Goal: run the demo for $1.\n\nThe prompt keeps $1 for positional use.";
        arguments = [ { label = "Question"; } ];
        asSkill = {
          opencode = true;
        };
      };
    };
  };

  cases = [
    {
      name = "OpenCode command emits argument-hint frontmatter from declared arguments";
      pass =
        scope.commands.demo.embed
        == "---\ndescription: \"Run demo\"\nargument-hint: \"[question]\"\n---\n\nGoal: run the demo for $1.\nQuestion: $ARGUMENTS\n\nThe prompt keeps $1 for positional use.";
      detail = "expected the derived argument hint and the injected argument line";
    }
    {
      name = "OpenCode derived skill renders the command content verbatim";
      pass =
        scope.extraSkillsFromCommands."skills/demo/SKILL".embed
        == "---\nname: \"demo\"\ndescription: \"Run demo\"\n---\n\nGoal: run the demo for $1.\n\nThe prompt keeps $1 for positional use.";
      detail = "expected no argument hint and no argument line in the command-derived skill";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
