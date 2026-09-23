/// Extracts the iOS platform version from a `Podfile`.
///
/// A Flutter iOS Podfile declares its minimum platform like:
///
///     platform :ios, '13.0'
///
/// This function scans line by line for that declaration and returns the
/// version string (e.g. `"13.0"`), or `null` if:
///   - the declaration is missing entirely
///   - the only match is a commented-out line (starts with `#`)
///   - the value can't be extracted
///
/// The Podfile is a Ruby DSL, but we only care about one line — regex on
/// lines is enough. No need for a real Ruby parser.
String? parsePodfilePlatform(String podfileText) {
  final lines = podfileText.split('\n');
  final pattern = RegExp(
    r'''^\s*platform\s+:ios\s*,\s*['"]([\d.]+)['"]''',
  );
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}
