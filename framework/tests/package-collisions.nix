{ pkgs, lib }:

/*
  Output package assembly tests — exercise the destination-uniqueness guard in
  output.nix mkPackage, which catches two files resolving to the same harness
  destination before symlinkJoin reports an opaque clash, and the directory
  skill prefix guard, which catches any file resolving into a directory
  skill's opaque skills/<key>/ subtree.
*/

let
  output = import ../output.nix { inherit pkgs lib; };

  mkScope =
    {
      instructions,
      skillFiles ? { },
      skills ? { },
      harnessOutputDir ? "claude",
    }:
    {
      harness.outputDir = harnessOutputDir;
      inherit instructions skillFiles skills;
    };

  uniqueResult = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = mkScope {
        instructions = {
          "skills/demo/SKILL" = {
            kind = "skill";
            embed = "Skill main body";
            outputPath = "skills/demo/SKILL.md";
          };
        };
        skillFiles = {
          "skills/demo/refs/data" = {
            kind = "skillFile";
            embed = "Bundled data";
            outputPath = "skills/demo/refs/data.md";
          };
        };
      };
    }).drvPath
  );

  collidingResult = builtins.tryEval (
    (output.mkPackage {
      scopes.claude = mkScope {
        instructions = {
          "skills/demo/SKILL" = {
            kind = "skill";
            embed = "Skill main body";
            outputPath = "skills/demo/SKILL.md";
          };
        };
        skillFiles = {
          "skills/demo/SKILL" = {
            kind = "skillFile";
            embed = "Sub-file colliding with the skill main file";
            outputPath = "skills/demo/SKILL.md";
          };
        };
      };
    }).drvPath
  );
  # Codex commands render into skills/<name>/SKILL.md, so a slash key that lands
  # under a directory skill's subtree must fail the prefix guard, not just the
  # exact-destination guard.
  prefixCollidingResult = builtins.tryEval (
    (output.mkPackage {
      scopes.codex = mkScope {
        harnessOutputDir = "codex";
        instructions = {
          "external/sub" = {
            kind = "command";
            embed = "Command rendered as a codex skill";
            outputPath = "skills/external/sub/SKILL.md";
          };
        };
        skills = {
          external = {
            sourceDirectory = toString ./fixtures/directory-skill;
          };
        };
      };
    }).drvPath
  );

  cases = [
    {
      name = "distinct destinations assemble";
      pass = uniqueResult.success;
      detail = "expected files with distinct destinations to assemble into a package";
    }
    {
      name = "duplicate destination fails before symlinkJoin";
      pass = !collidingResult.success;
      detail = "expected a sub-file colliding with a skill main file to fail with a destination collision";
    }
    {
      name = "codex command inside a directory skill subtree fails";
      pass = !prefixCollidingResult.success;
      detail = "expected a slash-key command rendered under a directory skill's skills/<key>/ subtree to fail with a prefix collision";
    }
  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
