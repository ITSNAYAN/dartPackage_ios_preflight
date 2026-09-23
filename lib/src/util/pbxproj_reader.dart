/// Extracts the `IPHONEOS_DEPLOYMENT_TARGET` value from every build
/// configuration in a `project.pbxproj` file.
///
/// A pbxproj file (the raw serialized form of an `.xcodeproj`) contains
/// blocks like:
///
///     XCBuildConfiguration = {
///       ...
///       buildSettings = {
///         IPHONEOS_DEPLOYMENT_TARGET = 13.0;
///         ...
///       };
///       name = Debug;
///     };
///
/// One block per configuration (typically Debug / Release / Profile), and
/// per target (Runner, RunnerTests). Multiple hits are common and expected.
///
/// Returns a list of raw hits (each carrying the config name and version),
/// preserving duplicates so callers can detect inter-config disagreement.
/// Returns an empty list if no matches are found.
class DeploymentTargetHit {
  /// The `name = Xxx;` string associated with the containing block
  /// (typically `"Debug"`, `"Release"`, or `"Profile"`). May be `null` if
  /// the parser couldn't confidently pair the setting with a name.
  final String? configName;

  /// The deployment target string (e.g. `"13.0"`).
  final String version;

  const DeploymentTargetHit({required this.configName, required this.version});

  @override
  String toString() =>
      'DeploymentTargetHit(${configName ?? '?'} → $version)';
}

List<DeploymentTargetHit> parseDeploymentTargets(String pbxprojText) {
  final result = <DeploymentTargetHit>[];
  // Match: IPHONEOS_DEPLOYMENT_TARGET = <version>;
  // The value is unquoted in real pbxproj files.
  final targetPattern = RegExp(
    r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([\d.]+)\s*;',
  );
  // Match: name = <ident>; used to identify which XCBuildConfiguration
  // block a setting belongs to. The block that a setting lives in ends
  // with a `};` and its `name = ...;` typically sits on the last line
  // of that block.
  final namePattern = RegExp(r'name\s*=\s*([A-Za-z0-9_-]+)\s*;');

  // Strategy: for each IPHONEOS_DEPLOYMENT_TARGET hit, scan the next ~800
  // chars for the first `name = X;`. In a real pbxproj file the block layout
  // is: `buildSettings = { ... IPHONEOS_DEPLOYMENT_TARGET ... }; name = X; };`
  // — meaning the block's `name` sits just past the buildSettings closer,
  // still comfortably inside the 800-char window. First hit wins, so we
  // never cross into the next XCBuildConfiguration block.
  for (final match in targetPattern.allMatches(pbxprojText)) {
    final version = match.group(1)!;
    final searchStart = match.end;
    final searchEnd = searchStart + 800 > pbxprojText.length
        ? pbxprojText.length
        : searchStart + 800;
    final tail = pbxprojText.substring(searchStart, searchEnd);
    final nameMatch = namePattern.firstMatch(tail);
    result.add(DeploymentTargetHit(
      configName: nameMatch?.group(1),
      version: version,
    ));
  }
  return result;
}
