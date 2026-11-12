{ pkgs, lib }:

let
  builders = import ../builders.nix { inherit pkgs lib; };
  harnesses = import ../harnesses {
    inherit lib;
    renderFrontmatter = builders.renderFrontmatter;
  };
  directory = ./fixtures/directory-skill;
  inventory = [
    "SKILL.md"
    "data.bin"
    "data.json"
    "data.nix"
    "read-sibling.cjs"
    "refs/guide.md"
  ];
  mkScope =
    harness: declaration:
    builders.makeScope {
      inherit harness;
      sources.skills.external = declaration;
    };
  scopes = lib.mapAttrs (_: harness: mkScope harness { inherit directory; }) harnesses;
  package = builders.mkPackage {
    inherit scopes;
    postProcess = true;
  };
  rejected =
    declaration:
    !(builtins.tryEval (builtins.deepSeq (mkScope harnesses.claude declaration).instructions true))
    .success;
  filtered = lib.mapAttrs (
    _: harness:
    mkScope harness {
      inherit directory;
      harnesses = [ "pi" ];
      when = { scope }: scope.harness.name == "pi";
    }
  ) harnesses;
  collision = builtins.tryEval (
    (builders.mkPackage {
      scopes.claude = builders.makeScope {
        harness = harnesses.claude;
        sources = {
          skills.external = { inherit directory; };
          instructions.collision = {
            content = "Conflicting asset";
            outputPath = "skills/external/data.json";
          };
        };
      };
    }).drvPath
  );
  cases = [
    {
      name = "directory main retains its bytes and key-based reference";
      pass = lib.all (
        scope:
        scope.skills.external.embed == builtins.readFile (directory + "/SKILL.md")
        && scope.skills.external.reference == "the `external` skill"
        && scope.skills.external.outputPath == "skills/external/SKILL.md"
      ) (builtins.attrValues scopes);
    }
    {
      name = "companions are inventoried without importing Nix or reading binary strings";
      pass = lib.all (
        scope:
        builtins.attrNames scope.skillFiles
        == map (name: "skills/external/${name}") (builtins.tail inventory)
      ) (builtins.attrValues scopes);
    }
    {
      name = "selectors include or exclude the entire directory";
      pass = lib.all (
        name:
        builtins.attrNames filtered.${name}.skills == (if name == "pi" then [ "external" ] else [ ])
        &&
          builtins.length (builtins.attrNames filtered.${name}.skillFiles) == (if name == "pi" then 5 else 0)
      ) (builtins.attrNames harnesses);
    }
    {
      name = "false predicate excludes directory even on an allowed harness";
      pass =
        (mkScope harnesses.pi {
          inherit directory;
          when = _: false;
        }).skills == { };
    }
    {
      name = "directory conflicts with authored main or companion declarations";
      pass =
        rejected {
          inherit directory;
          main.content = "No";
        }
        && rejected {
          inherit directory;
          files = { };
        };
    }
    {
      name = "directory requires a regular root SKILL.md";
      pass = rejected { directory = ./fixtures; };
    }
    {
      name = "symlink companions are rejected instead of followed";
      pass = rejected { directory = ./fixtures/directory-skill-link; };
    }
    {
      name = "directory assets participate in destination collision checks";
      pass = !collision.success;
    }
  ];
  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]";
in
{
  inherit directory inventory package;
  allPass = builtins.all checkCase cases;
}
