{
  settings ? { },
  ...
}:
let
  claudeSettings = (settings.harnesses or { }).claude or { };
  tasksSupport = claudeSettings.tasks or false;
in
{
  name = "claude";
  outputDir = "claude";
  tasksSupport = tasksSupport;

  tools = {
    taskCreate = if tasksSupport then "TaskCreate" else null;
    askUserQuestion = "AskUserQuestion";
  };
  prose.questions.request = "use `AskUserQuestion`";

  renderArtifact =
    artifact:
    let
      permissionValue = if artifact.permission != null then artifact.permission else { };
      common = {
        outputPath =
          if artifact.kind == "instruction" && artifact.role == "main" then
            "CLAUDE.md"
          else if artifact.kind == "instruction" && artifact.role == "rule" then
            "rules/${artifact.key}.md"
          else if artifact.kind == "instruction" then
            "${artifact.key}.md"
          else if artifact.kind == "agent" then
            "agents/${artifact.name}.md"
          else if artifact.kind == "command" then
            "commands/${artifact.name}.md"
          else if artifact.kind == "skill" then
            "skills/${artifact.key}/SKILL.md"
          else if artifact.kind == "skillFile" then
            "skills/${artifact.skillKey}/${artifact.subPath}"
          else
            throw "Nixantic Claude renderer does not support artifact kind '${artifact.kind}'";
      };
      agent = {
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
          model = artifact.model;
          effort = artifact.effort;
          tools = permissionValue.tools or null;
          disallowedTools = permissionValue.disallowedTools or null;
          permissionMode = permissionValue.permissionMode or null;
        };
        frontmatterOrder = [
          "name"
          "description"
          "model"
          "effort"
          "tools"
          "disallowedTools"
          "permissionMode"
        ];
      };
      command = {
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
          "argument-hint" = artifact.argumentsHint;
          model = artifact.model;
          effort = artifact.effort;
          context = artifact.context;
          agent = artifact.agent;
          "allowed-tools" = artifact.allowedTools;
        };
        frontmatterOrder = [
          "name"
          "description"
          "argument-hint"
          "model"
          "effort"
          "context"
          "agent"
          "allowed-tools"
        ];
      };
      skill = {
        frontmatter = {
          name = artifact.name;
          description = artifact.description;
          model = artifact.model;
          effort = artifact.effort;
          context = artifact.context;
          agent = artifact.agent;
          "allowed-tools" = artifact.allowedTools;
          metadata = artifact.metadata;
          when_to_use = artifact.whenToUse;
          "disable-model-invocation" = artifact.disableModelInvocation;
          "user-invocable" = artifact.userInvocable;
        };
        frontmatterOrder = [
          "name"
          "description"
          "model"
          "effort"
          "context"
          "agent"
          "allowed-tools"
          "when_to_use"
          "disable-model-invocation"
          "user-invocable"
          "metadata"
        ];
      };
    in
    if artifact.verbatim then
      {
        inherit (common) outputPath;
        embed = artifact.content;
      }
    else
      common
      // (
      if artifact.kind == "instruction" || artifact.kind == "skillFile" then
        {
          frontmatter = { };
          frontmatterOrder = [ ];
        }
      else if artifact.kind == "agent" then
        agent
      else if artifact.kind == "command" then
        command
      else if artifact.kind == "skill" then
        skill
      else
        throw "Nixantic Claude renderer does not support artifact kind '${artifact.kind}'"
    );
}
