{ pkgs, lib }:

/*
  Output assembly — converts processed scope instruction maps into Nix
  derivations. mkFile wraps individual files, mkPackage assembles all scopes
  into a single symlink-joined package. postProcessContent cleans up
  agent-generated markdown before writing.
*/

let

  # postProcessContent :: string -> string
  #   Cleans up generated markdown output. Applied when mkPackage is called
  #   with postProcess = true. Two transformations run in order, line by line:
  #
  #   1. Strip exactly one trailing `.` from every line that ends in `.`.
  #      This is intentionally broad: it normalizes generated prose so a line
  #      ending in `.` renders without it ("foo." -> "foo", "foo.." -> "foo.",
  #      lone "." -> "").
  #   2. Drop blank lines, whitespace-only lines, and lone `.` sentinel lines
  #      (agents sometimes emit a bare `.` as a no-op output marker).
  postProcessContent =
    text:
    let
      stripTrailingDot =
        line:
        if builtins.match ".*\\.$" line != null then
          builtins.substring 0 (builtins.stringLength line - 1) line
        else
          line;
      stripped = map stripTrailingDot (lib.splitString "\n" text);
      nonEmpty = builtins.filter (
        line: line != "." && null == builtins.match "^[[:space:]]*$" line
      ) stripped;
    in
    builtins.concatStringsSep "\n" nonEmpty;

  # mkFile :: dir -> path -> filename -> content -> derivation
  #   Creates a single output file via pkgs.writeTextFile.
  #   Places file at `/<dir>/<filename>` in the derivation tree.
  #   Derivation name: `<dir>-<path>` with `/` replaced by `-`.
  #
  #   dir      — harness outputDir (e.g. "claude", "opencode")
  #   path     — instruction key (e.g. "commands/my-cmd")
  #   filename — destination filename (e.g. "my-cmd.md")
  #   content  — file body (processed markdown)
  mkFile =
    dir: path: filename: content:
    pkgs.writeTextFile {
      name = builtins.replaceStrings [ "/" ] [ "-" ] "${dir}-${path}";
      text = content;
      destination = "/${dir}/${filename}";
    };

  # mkPackage :: { scopes, postProcess ? false } -> derivation
  #   Assembles all harness scopes into a single symlinkJoin package.
  #
  #   For each scope, processes two instruction sources:
  #     scope.instructions — primary instructions (authored, agents, commands, skills)
  #     scope.skillFiles   — skill sub-files (.md and .nix)
  #
  #   Filename resolution (per instruction):
  #     Uses instr.outputPath if non-null, otherwise defaults to "<key>.md".
  #
  #   postProcess: when true, applies postProcessContent to every file's embed
  #     before writing. Useful for agent-to-human output where agents may emit
  #     blank lines or `.` sentinels. Raw (harness-owned) entries skip this step.
  mkPackage =
    {
      scopes,
      postProcess ? false,
    }:
    let
      process = if postProcess then postProcessContent else (x: x);
      resolveFilename =
        path: item: if item ? outputPath && item.outputPath != null then item.outputPath else "${path}.md";
      classifyEntry =
        kind:
        if kind == "skillFile" then
          "skillSubfiles"
        else if kind == "agent" then
          "agents"
        else if kind == "command" then
          "commands"
        else if kind == "skill" then
          "skills"
        else if kind == "instruction" || kind == "supportFile" then
          "instructions"
        else
          throw "Nixantic output artifact has unsupported logical kind '${kind}'";
      mkEntry =
        scope: source: path: item:
        let
          harnessName = scope.harness.name or scope.harness.outputDir;
          filename = resolveFilename path item;
          sourceBacked = item ? sourcePath;
          content =
            if sourceBacked then
              null
            else if item.raw or false then
              item.embed
            else
              process item.embed;
        in
        {
          inherit content source;
          inherit harnessName;
          harnessDir = scope.harness.outputDir;
          relativePath = filename;
          destination = "${scope.harness.outputDir}/${filename}";
          category = classifyEntry item.kind;
          file =
            if sourceBacked then
              mkSkillDirectory scope.harness.outputDir item.skillKey item.sourceDirectory
            else
              mkFile scope.harness.outputDir path filename content;
        }
        // lib.optionalAttrs sourceBacked { sourcePath = toString item.sourcePath; };
      mkRootFileEntry =
        scope: relativePath: content:
        let
          harnessName = scope.harness.name or scope.harness.outputDir;
        in
        {
          inherit content harnessName;
          source = "supportFile";
          kind = "supportFile";
          harnessDir = scope.harness.outputDir;
          inherit relativePath;
          destination = "${scope.harness.outputDir}/${relativePath}";
          category = "instructions";
          file = mkFile scope.harness.outputDir relativePath relativePath content;
        };
      # Each entry tracks its final destination path so collisions can be caught
      # with a clear diagnostic. Without this guard, two files resolving to the
      # same destination (e.g. a skill sub-file whose path equals an
      # instruction's outputPath) only surface as an opaque symlinkJoin clash.
      fileEntries = lib.concatLists (
        lib.mapAttrsToList (
          _: scope:
          (lib.mapAttrsToList (mkEntry scope "instruction") scope.instructions)
          ++ (lib.mapAttrsToList (mkEntry scope "skillFile") (scope.skillFiles or { }))
          ++ (lib.mapAttrsToList (mkRootFileEntry scope) (scope.harness.rootFiles or { }))
        ) scopes
      );

      duplicateDestinations =
        let
          destinations = map (entry: entry.destination) fileEntries;
          grouped = lib.groupBy (destination: destination) destinations;
        in
        builtins.filter (destination: builtins.length grouped.${destination} > 1) (
          builtins.attrNames grouped
        );

      allFiles = lib.unique (map (entry: entry.file) fileEntries);
    in
    assert
      duplicateDestinations == [ ]
      || throw "Multiple nixantic files resolve to the same destination: ${builtins.concatStringsSep ", " duplicateDestinations}";
    pkgs.symlinkJoin {
      name = "nixantic-instructions";
      paths = allFiles;
    };

  # A shared source tree keeps executable assets and sibling-relative lookups intact.
  mkSkillDirectory =
    harnessDir: skillKey: sourceDirectory:
    pkgs.runCommand (builtins.replaceStrings [ "/" ] [ "-" ] "${harnessDir}-skill-${skillKey}") { } ''
      destination="$out"/${lib.escapeShellArg "${harnessDir}/skills/${skillKey}"}
      mkdir -p "$destination"
      cp -R ${lib.escapeShellArg "${sourceDirectory}/."} "$destination/"
    '';

in
{
  inherit
    postProcessContent
    mkFile
    mkPackage
    ;
}
