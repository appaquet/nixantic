# @tintinweb/pi-subagents registers the `Agent`, `get_subagent_result`, and
# `steer_subagent` sub-agent tools; this adapter targets its `agents/*.md`
# frontmatter format.
let
  supportedPolicyKeys = [
    "allowedSubagents"
    "disallowedTools"
    "excludeExtensions"
    "extensions"
    "isolated"
    "isolation"
    "persistSession"
    "skills"
    "tools"
  ];
  validateStringList =
    field: value:
    if value == null then
      null
    else if builtins.isList value && builtins.all builtins.isString value then
      value
    else
      throw "Nixantic Pi tintinweb policy '${field}' must be a list of strings";
  validateInheritance =
    field: value:
    if value == null || builtins.isBool value then value else validateStringList field value;
  validateAllowedSubagents =
    value:
    if value == null || builtins.isBool value || value == "all" || value == "*" then
      value
    else
      validateStringList "allowedSubagents" value;
  validateBool =
    field: value:
    if value == null || builtins.isBool value then
      value
    else
      throw "Nixantic Pi tintinweb policy '${field}' must be a boolean";
  validatePolicy =
    policy:
    if policy == null then
      { }
    else if !builtins.isAttrs policy then
      throw "Nixantic Pi tintinweb agent policy must be an attrset"
    else
      let
        unknownKeys = builtins.filter (key: !(builtins.elem key supportedPolicyKeys)) (
          builtins.attrNames policy
        );
        isolation = policy.isolation or null;
      in
      assert
        unknownKeys == [ ]
        || throw "Nixantic Pi tintinweb agent policy has unsupported fields: ${builtins.concatStringsSep ", " unknownKeys}";
      assert
        isolation == null
        || isolation == false
        || builtins.elem isolation [
          "worktree"
          "off"
        ]
        || throw "Nixantic Pi tintinweb policy 'isolation' must be worktree, off, or false";
      {
        tools = validateStringList "tools" (policy.tools or null);
        disallowedTools = validateStringList "disallowedTools" (policy.disallowedTools or null);
        extensions = validateInheritance "extensions" (policy.extensions or null);
        excludeExtensions = validateStringList "excludeExtensions" (policy.excludeExtensions or null);
        skills = validateInheritance "skills" (policy.skills or null);
        allowedSubagents = validateAllowedSubagents (policy.allowedSubagents or null);
        persistSession = validateBool "persistSession" (policy.persistSession or null);
        isolated = validateBool "isolated" (policy.isolated or null);
        inherit isolation;
      };
in
{
  supportedPolicyFields = supportedPolicyKeys;
  capabilities = {
    launch = "Agent";
    result = "get_subagent_result";
    steer = "steer_subagent";
  };

  renderAgentArtifact =
    artifact:
    let
      # Every tintinweb policy field is optional, and validatePolicy returns an empty
      # attrset when none is authored, so the frontmatter reads each one with `or null`.
      policy = validatePolicy artifact.permission;
      thinking = artifact.effort;
      # The plugin defaults file-based agents to replace, so an undeclared mode becomes
      # the append behavior authored sources expect.
      promptMode = if (artifact.promptMode or null) == null then "append" else artifact.promptMode;
    in
    assert
      thinking == null
      || builtins.elem thinking [
        "off"
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
      ]
      || throw "Nixantic Pi tintinweb thinking must be off, minimal, low, medium, high, or xhigh";
    {
      outputPath = "agents/${artifact.name}.md";
      frontmatter = {
        name = artifact.name;
        description = artifact.description;
        tools = policy.tools or null;
        disallowed_tools = policy.disallowedTools or null;
        extensions = policy.extensions or null;
        exclude_extensions = policy.excludeExtensions or null;
        skills = policy.skills or null;
        allowed_subagents = policy.allowedSubagents or null;
        prompt_mode = promptMode;
        model = artifact.model;
        inherit thinking;
        persist_session = policy.persistSession or null;
        isolated = policy.isolated or null;
        isolation = policy.isolation or null;
      };
      frontmatterOrder = [
        "name"
        "description"
        "tools"
        "disallowed_tools"
        "extensions"
        "exclude_extensions"
        "skills"
        "allowed_subagents"
        "prompt_mode"
        "model"
        "thinking"
        "persist_session"
        "isolated"
        "isolation"
      ];
    };
}
