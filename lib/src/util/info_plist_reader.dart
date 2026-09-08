import 'dart:convert';
import 'dart:io';

/// Runs `plutil` (or equivalent) and returns its stdout as a String.
/// Injected so tests can supply canned JSON without shelling out.
typedef PlutilRunner = Future<String?> Function(String plistPath);

/// Reads an `Info.plist` file and returns a map of every top-level key whose
/// value is a string, to that string.
///
/// Non-string values (arrays, dicts, booleans, numbers) are intentionally
/// dropped — every iOS usage-description key is a `<string>`, so anything
/// else is not our concern.
///
/// Empty strings are preserved in the returned map so the caller can
/// distinguish "key present but empty" (Apple still rejects these) from
/// "key not present at all".
///
/// Delegates plist parsing to `plutil -convert json -o - <path>` (a macOS
/// built-in). This handles both XML and binary plists transparently, which
/// matters because some tooling produces binary Info.plists.
Future<Map<String, String>> readInfoPlist(
  String path, {
  PlutilRunner? runner,
}) async {
  final effectiveRunner = runner ?? _defaultRunner;
  final json = await effectiveRunner(path);
  if (json == null) return const {};

  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};

  final result = <String, String>{};
  decoded.forEach((key, value) {
    if (key is String && value is String) {
      result[key] = value;
    }
  });
  return result;
}

Future<String?> _defaultRunner(String plistPath) async {
  try {
    final result = await Process.run(
      'plutil',
      ['-convert', 'json', '-o', '-', plistPath],
    );
    if (result.exitCode != 0) return null;
    final stdout = result.stdout;
    if (stdout is! String) return null;
    return stdout;
  } on ProcessException {
    return null;
  }
}
