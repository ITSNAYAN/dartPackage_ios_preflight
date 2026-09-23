/// Extracts the app's iOS bundle identifier from `project.pbxproj`.
///
/// Real pbxproj files contain multiple `PRODUCT_BUNDLE_IDENTIFIER = ...;`
/// entries — one per (target, build-configuration) pair. The RunnerTests
/// target has its own bundle ID (something like `com.example.appTests`)
/// which we don't want. So we filter out anything ending in `Tests`.
///
/// Returns the first non-Tests bundle identifier found, or `null` when
/// none can be extracted. Deliberately forgiving — a missing bundle ID
/// isn't fatal to the whole check, we just skip the "match profiles to
/// this specific app" sub-step.
String? parseBundleIdentifier(String pbxprojText) {
  final pattern = RegExp(
    r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+)\s*;',
  );
  for (final match in pattern.allMatches(pbxprojText)) {
    final id = match.group(1)!;
    if (id.endsWith('Tests') || id.endsWith('.tests')) continue;
    return id;
  }
  return null;
}

/// Returns `true` if the project's release-adjacent configurations use
/// Xcode's automatic code-signing. Automatic signing means Xcode manages
/// provisioning profiles behind the scenes — profiles may not exist as
/// files on disk, so profile-expiry checking would be misleading.
///
/// Detection is intentionally permissive: if we see `CODE_SIGN_STYLE =
/// Automatic;` **anywhere** in the pbxproj, we return `true`. Users with
/// mixed Debug=Automatic / Release=Manual setups will get a skip — safer
/// than a false-fail on a legitimate mixed configuration.
bool detectsAutomaticSigning(String pbxprojText) {
  return RegExp(r'CODE_SIGN_STYLE\s*=\s*Automatic\s*;')
      .hasMatch(pbxprojText);
}
