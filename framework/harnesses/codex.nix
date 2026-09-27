# Codex renders the corpus to a single AGENTS.md, Agent Skills (reusable
# commands became skills; custom prompts were removed in codex 0.117), and
# standalone agent TOML files. Agent TOML is not frontmatter + markdown, so
# the agent path returns an embed and the harness owns the final bytes.
{ lib, ... }: {
  name = "codex";
  outputDir = "codex";

  # Built-in Codex tool names: update_plan maintains the session todo list
  # and experimental_request_user_input asks the user a structured question.
  tools = {
    taskCreate = "update_plan";
    askUserQuestion = "experimental_request_user_input";
  };
  prose.questions.request = "use `experimental_request_user_input`";

  renderArtifact =
    artifact:
    let
      # JSON string escaping is a valid TOML basic-string escape.
      tomlString = value: builtins.toJSON value;
      agentToml =
        if builtins.match ".*\"\"\".*" artifact.content != null then
          throw "Nixantic Codex agent '${artifact.name}' content cannot contain triple quotes"
        else
          builtins.concatStringsSep "\n" (
            [
              "name = ${tomlString artifact.name}"
              "description = ${tomlString artifact.description}"
              "developer_instructions = \"\"\""
            ]
            ++ lib.splitString "\n" artifact.content
            ++ [ "\"\"\"" ]
            ++ (if artifact.model != null then [ "model = ${tomlString artifact.model}" ] else [ ])
            ++ (
              if artifact.effort != null then
                [ "model_reasoning_effort = ${tomlString artifact.effort}" ]
              else
                [ ]
            )
          );
      common = {
        outputPath =
          if artifact.kind == "instruction" && artifact.role == "main" then
            "AGENTS.md"
          else if artifact.kind == "instruction" && artifact.role == "rule" then
            "rules/${artifact.key}.md"
          else if artifact.kind == "instruction" then
            "${artifact.key}.md"
          else if artifact.kind == "agent" then
            "agents/${artifact.name}.toml"
          else if artifact.kind == "command" then
            "skills/${artifact.name}/SKILL.md"
          else if artifact.kind == "skill" then
            "skills/${artifact.key}/SKILL.md"
          else if artifact.kind == "skillFile" then
            "skills/${artifact.skillKey}/${artifact.subPath}"
          else
            throw "Nixantic Codex renderer does not support artifact kind '${artifact.kind}'";
      };
    in
    common
    // (
      if artifact.kind == "agent" then
        { embed = agentToml; }
      else if artifact.kind == "command" || artifact.kind == "skill" then
        {
          frontmatter = {
            name = artifact.name;
            description = artifact.description;
          };
          frontmatterOrder = [
            "name"
            "description"
          ];
        }
      else
        {
          frontmatter = { };
          frontmatterOrder = [ ];
        }
    );
}
