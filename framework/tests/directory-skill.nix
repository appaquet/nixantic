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
  # A source that fails to build: if evaluation ever reads it, the cases below throw.
  lazySource = pkgs.runCommand "lazy-eval-proof" { } "exit 1";
  cases = [
    {
      name = "placeholder embed keeps key-based reference and output shape";
      pass = lib.all (
        scope:
        scope.skills.external.embed == ""
        && scope.skills.external.reference == "the `external` skill"
        && scope.skills.external.outputPath == "skills/external/SKILL.md"
      ) (builtins.attrValues scopes);
    }
    {
      name = "directory skills contribute no skillFiles to the scope";
      pass = lib.all (scope: scope.skillFiles == { }) (builtins.attrValues scopes);
    }
    {
      name = "selectors include or exclude the entire directory";
      pass = lib.all (
        name:
        builtins.attrNames filtered.${name}.skills == (if name == "pi" then [ "external" ] else [ ])
        && builtins.attrNames filtered.${name}.skillFiles == [ ]
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
      name = "evaluation never reads a build-failing source";
      pass =
        (builtins.tryEval (
          builtins.deepSeq (mkScope harnesses.claude { directory = lazySource; }).instructions true
        )).success
        && (builtins.tryEval (
          builtins.deepSeq
            (builders.mkPackage {
              scopes = {
                claude = mkScope harnesses.claude { directory = lazySource; };
              };
              postProcess = true;
            }).drvPath
            true
        )).success;
    }
    {
      name = "nested skill keys under a directory skill fail evaluation";
      pass =
        !(builtins.tryEval (
          builtins.deepSeq
            (builders.mkPackage {
              scopes = {
                claude = builders.makeScope {
                  harness = harnesses.claude;
                  sources.skills = {
                    a = { inherit directory; };
                    "a/b" = {
                      main.content = "Nested";
                    };
                  };
                };
              };
              postProcess = true;
            }).drvPath
            true
        )).success;
    }
  ];
  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]";
in
{
  inherit directory inventory package;
  allPass = builtins.all checkCase cases;
}
