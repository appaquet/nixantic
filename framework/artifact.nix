{ lib, renderFrontmatter }:

let
  isSafeRelativePath =
    path:
    builtins.isString path
    && path != ""
    && !(lib.hasPrefix "/" path)
    && builtins.all (part: part != "" && part != "." && part != "..") (lib.splitString "/" path);

  validateOutputPath =
    source: path:
    if isSafeRelativePath path then
      path
    else
      throw "Nixantic ${source} must be a non-empty safe relative path";

  duplicateKeys =
    values:
    builtins.filter (value: builtins.length (builtins.filter (other: other == value) values) > 1) (
      lib.unique values
    );

  validateRendererResult =
    result:
    let
      resultKeys = builtins.attrNames result;
      frontmatterShapeKeys = [
        "frontmatter"
        "frontmatterOrder"
        "outputPath"
      ];
      embedShapeKeys = [
        "embed"
        "outputPath"
      ];
      hasFrontmatter =
        builtins.hasAttr "frontmatter" result || builtins.hasAttr "frontmatterOrder" result;
      hasEmbed = builtins.hasAttr "embed" result;
      order = result.frontmatterOrder or null;
      duplicateOrder = if builtins.isList order then duplicateKeys order else [ ];
    in
    if hasFrontmatter && hasEmbed then
      throw "Nixantic artifact renderer result must provide either the frontmatter shape or embed, not both"
    else if !hasFrontmatter && !hasEmbed then
      throw "Nixantic artifact renderer must return outputPath plus frontmatter with frontmatterOrder, or outputPath plus embed"
    else if hasEmbed then
      if resultKeys != embedShapeKeys then
        throw "Nixantic artifact renderer embed result must return exactly outputPath and embed"
      else if !builtins.isString result.embed then
        throw "Nixantic artifact renderer embed must be a string"
      else
        result // { outputPath = validateOutputPath "artifact renderer outputPath" result.outputPath; }
    else if resultKeys != frontmatterShapeKeys then
      throw "Nixantic artifact renderer must return exactly outputPath, frontmatter, and frontmatterOrder"
    else if !builtins.isAttrs result.frontmatter then
      throw "Nixantic artifact renderer frontmatter must be an attrset"
    else if !builtins.isList order || !builtins.all builtins.isString order then
      throw "Nixantic artifact renderer frontmatterOrder must be a list of frontmatter keys"
    else if duplicateOrder != [ ] then
      throw "Nixantic artifact renderer frontmatterOrder contains duplicate keys: ${builtins.concatStringsSep ", " duplicateOrder}"
    else if lib.sort builtins.lessThan order != (builtins.attrNames result.frontmatter) then
      throw "Nixantic artifact renderer frontmatterOrder must contain every frontmatter key exactly once"
    else
      result // { outputPath = validateOutputPath "artifact renderer outputPath" result.outputPath; };

  renderArtifact =
    harness: artifact:
    let
      result = validateRendererResult (harness.renderArtifact artifact);
      outputPath =
        if artifact.authoredOutputPath != null then
          validateOutputPath "authored outputPath" artifact.authoredOutputPath
        else
          result.outputPath;
      # Raw entries are harness-owned final bytes (e.g. Codex agent TOML) and
      # skip frontmatter assembly; frontmatter entries are assembled from the
      # declared frontmatter order plus the authored content.
      embeddedContent =
        if result ? embed then
          result.embed
        else
          let
            frontmatter = renderFrontmatter (
              map (key: {
                label = key;
                value = result.frontmatter.${key};
              }) result.frontmatterOrder
            );
          in
          if frontmatter == "" then artifact.content else "${frontmatter}\n${artifact.content}";
    in
    {
      inherit outputPath;
      kind = artifact.kind;
      role = artifact.role or null;
      raw = result ? embed;
      embed = embeddedContent;
    };
in
{
  inherit isSafeRelativePath validateRendererResult renderArtifact;
}
