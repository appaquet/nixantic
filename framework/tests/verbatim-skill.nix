{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  output = import ../output.nix { inherit pkgs lib; };
  harnesses = import ../harnesses {
    inherit lib;
    renderFrontmatter = builders.renderFrontmatter;
  };
  harnessNames = [
    "claude"
    "codex"
    "opencode"
    "pi"
  ];

  skillFile = ./fixtures/verbatim-skill/SKILL.md;
  authoredBytes = builtins.readFile skillFile;

  mkScope =
    harness:
    builders.makeScope {
      inherit harness;
      sources = {
        skills.packaged.main = {
          file = skillFile;
        };
      };
    };

  fileBackedSkill = harness: (mkScope harnesses.${harness}).skills.packaged;

  # A rendered package keeps verbatim skills out of post-processing entirely.
  postProcessedPackage = output.mkPackage {
    scopes = {
      claude = mkScope harnesses.claude;
    };
    postProcess = true;
  };
  postProcessedEntry = builtins.head postProcessedPackage.passthru.bom.entries.claude;

  contentBackedSkill =
    (builders.makeScope {
      harness = harnesses.claude;
      sources.skills.authored.main = {
        description = "Authored skill";
        content = "Body.";
      };
    }).skills.authored;

  bothSet = builtins.tryEval (
    (builders.makeScope {
      harness = harnesses.claude;
      sources.skills.dual.main = {
        description = "Dual";
        content = "Body.";
        file = skillFile;
      };
    }).skills.dual.outputPath
  );

  fileOnCommand = builtins.tryEval (
    (builders.makeScope {
      harness = harnesses.claude;
      sources.commands.packaged = {
        description = "Packaged command";
        file = skillFile;
      };
    }).commands.packaged.outputPath
  );

  cases = [
    {
      name = "file-backed skill renders the authored path on every harness";
      pass = lib.all (harness: (fileBackedSkill harness).outputPath == "skills/packaged/SKILL.md") harnessNames;
    }
    {
      name = "file-backed skill keeps its bytes unchanged on every harness";
      pass = lib.all (harness: (fileBackedSkill harness).embed == authoredBytes) harnessNames;
    }
    {
      name = "file-backed skill is marked raw on every harness";
      pass = lib.all (harness: (fileBackedSkill harness).raw) harnessNames;
    }
    {
      name = "post-processing leaves a verbatim skill untouched";
      pass = postProcessedEntry.content == authoredBytes && postProcessedEntry.relativePath == "skills/packaged/SKILL.md";
    }
    {
      name = "content-backed skills still get synthesized frontmatter";
      pass = contentBackedSkill.embed == "---\nname: \"authored\"\ndescription: \"Authored skill\"\n---\n\nBody.";
    }
    {
      name = "content and file are mutually exclusive";
      pass = !bothSet.success;
    }
    {
      name = "file is rejected on non-directory skills";
      pass = !fileOnCommand.success;
    }
  ];

  checkCase =
    case:
    if case.pass then
      true
    else
      throw "FAIL [${case.name}]";
in
{
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
}
