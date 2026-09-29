{ pkgs, lib }:

# Per-harness tasks capability: a harness exposes its task tool name only when
# the tasks flag is on; claude defaults off (in-context tracking), opencode and
# codex default on.

let
  builders = import ../builders.nix { inherit pkgs lib; };
  renderFrontmatter = builders.renderFrontmatter;

  importHarness =
    {
      file,
      extra ? { },
      settings ? { },
    }:
    import (../${file}) ({ renderFrontmatter = renderFrontmatter; } // extra // { inherit settings; });

  claudeDefault = importHarness { file = "harnesses/claude.nix"; };
  claudeOn = importHarness {
    file = "harnesses/claude.nix";
    settings = {
      harnesses.claude.tasks = true;
    };
  };
  opencodeDefault = importHarness { file = "harnesses/opencode.nix"; };
  codexDefault = importHarness {
    file = "harnesses/codex.nix";
    extra = { inherit lib; };
  };
  codexOff = importHarness {
    file = "harnesses/codex.nix";
    extra = { inherit lib; };
    settings = {
      harnesses.codex.tasks = false;
    };
  };
  piDefault = importHarness {
    file = "harnesses/pi/default.nix";
    extra = { inherit lib; };
  };
  piNone = importHarness {
    file = "harnesses/pi/default.nix";
    extra = { inherit lib; };
    settings = {
      harnesses.pi.tasks = "none";
    };
  };

  cases = [
    {
      name = "claude task tool is null by default and present when enabled";
      pass = claudeDefault.tools.taskCreate == null && claudeOn.tools.taskCreate == "TaskCreate";
      detail = "expected claude taskCreate to be null by default and TaskCreate when the tasks flag is on";
    }
    {
      name = "opencode and codex task tools are present by default";
      pass =
        opencodeDefault.tools.taskCreate == "todowrite" && codexDefault.tools.taskCreate == "update_plan";
      detail = "expected opencode and codex taskCreate to be present by default";
    }
    {
      name = "disabling a harness tasks flag nulls its task tool";
      pass = codexOff.tools.taskCreate == null;
      detail = "expected codex taskCreate to be null when the tasks flag is off";
    }
    {
      name = "tasksSupport mirrors task tool presence per harness and setting";
      pass =
        claudeDefault.tasksSupport == (claudeDefault.tools.taskCreate != null)
        && claudeOn.tasksSupport == (claudeOn.tools.taskCreate != null)
        && opencodeDefault.tasksSupport == (opencodeDefault.tools.taskCreate != null)
        && codexDefault.tasksSupport == (codexDefault.tools.taskCreate != null)
        && codexOff.tasksSupport == (codexOff.tools.taskCreate != null)
        && piDefault.tasksSupport == (piDefault.tools.taskCreate != null)
        && piNone.tasksSupport == (piNone.tools.taskCreate != null);
      detail = "expected tasksSupport to equal (tools.taskCreate != null) for every harness/setting";
    }
    {
      name = "tasksSupport follows the per-harness default and flag";
      pass =
        claudeDefault.tasksSupport == false
        && opencodeDefault.tasksSupport == true
        && codexDefault.tasksSupport == true
        && piDefault.tasksSupport == true
        && claudeOn.tasksSupport == true
        && codexOff.tasksSupport == false
        && piNone.tasksSupport == false;
      detail = "expected claude off by default, opencode/codex/pi on, and the flag/adapter to flip it";
    }

  ];

  checkCase = case: if case.pass then true else throw "FAIL [${case.name}]: ${case.detail}";
  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
