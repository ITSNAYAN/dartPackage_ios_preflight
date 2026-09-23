import 'dart:convert';
import 'dart:io';

/// Decodes a `.mobileprovision` file to its inner plist as JSON. Default
/// implementation pipes `security cms -D -i <path>` through `plutil -convert
/// json` — both are macOS built-ins. Injected so tests can supply canned
/// JSON without touching the filesystem or subprocesses.
typedef ProfileDecoder = Future<String?> Function(String profilePath);

/// Parsed representation of one provisioning profile.
class ProvisioningProfile {
  /// File name (basename) — used purely for human-readable output.
  final String fileName;

  /// The profile's user-facing name (e.g. "iOS Team Provisioning Profile:
  /// com.example.app"). May be `null` if the field is missing.
  final String? name;

  /// The `application-identifier` from the profile's entitlements, which
  /// looks like `TEAMID.com.example.app` or `TEAMID.com.example.*` for
  /// wildcard profiles. Used to match a profile to a bundle ID.
  final String? applicationIdentifier;

  /// The profile's expiry timestamp.
  final DateTime? expirationDate;

  const ProvisioningProfile({
    required this.fileName,
    this.name,
    this.applicationIdentifier,
    this.expirationDate,
  });

  /// Returns true if the profile is authorised for the given [bundleId].
  /// Handles wildcard profiles (`com.example.*` matches `com.example.foo`).
  bool matchesBundleId(String bundleId) {
    final id = applicationIdentifier;
    if (id == null) return false;
    // Strip the leading `TEAMID.` prefix.
    final dot = id.indexOf('.');
    if (dot == -1) return false;
    final appPart = id.substring(dot + 1);
    if (appPart == bundleId) return true;
    if (appPart.endsWith('.*')) {
      final prefix = appPart.substring(0, appPart.length - 2);
      return bundleId == prefix || bundleId.startsWith('$prefix.');
    }
    return false;
  }
}

/// Reads a single `.mobileprovision` file and returns a parsed
/// [ProvisioningProfile], or `null` when decoding fails.
Future<ProvisioningProfile?> readProvisioningProfile(
  String profilePath, {
  ProfileDecoder? decoder,
}) async {
  final effectiveDecoder = decoder ?? _defaultDecoder;
  final json = await effectiveDecoder(profilePath);
  if (json == null) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;

  return ProvisioningProfile(
    fileName: profilePath.split('/').last,
    name: decoded['Name'] is String ? decoded['Name'] as String : null,
    applicationIdentifier: _extractApplicationIdentifier(decoded),
    expirationDate: _extractExpirationDate(decoded),
  );
}

/// Lists every `.mobileprovision` file in the standard Xcode profiles
/// directory. Default: `~/Library/MobileDevice/Provisioning Profiles/`.
/// Returns an empty list if the directory doesn't exist (e.g. on CI).
typedef ProfilesDirectoryLister = Future<List<String>> Function();

Future<List<String>> defaultProfilesLister() async {
  final home = Platform.environment['HOME'];
  if (home == null) return const [];
  final dir = Directory('$home/Library/MobileDevice/Provisioning Profiles');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mobileprovision'))
      .map((f) => f.path)
      .toList();
}

// —————— internals ——————

String? _extractApplicationIdentifier(Map<Object?, Object?> plist) {
  final entitlements = plist['Entitlements'];
  if (entitlements is Map) {
    final id = entitlements['application-identifier'];
    if (id is String) return id;
  }
  return null;
}

DateTime? _extractExpirationDate(Map<Object?, Object?> plist) {
  final raw = plist['ExpirationDate'];
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

Future<String?> _defaultDecoder(String profilePath) async {
  // Chain: `security cms -D -i <path>` produces an XML plist on stdout;
  // pipe that into `plutil -convert json -o - -` (the trailing `-` reads
  // from stdin) to get JSON we can `jsonDecode`.
  try {
    final cms = await Process.run(
      'security',
      ['cms', '-D', '-i', profilePath],
    );
    if (cms.exitCode != 0) return null;
    final cmsOut = cms.stdout;
    if (cmsOut is! String) return null;

    // plutil doesn't happily read from stdin without a trick — write to a
    // temp file and hand plutil the path. Slower but robust.
    final tmp = await File(
      '${Directory.systemTemp.path}/ios_preflight_profile_${DateTime.now().microsecondsSinceEpoch}.plist',
    ).writeAsString(cmsOut);
    try {
      final json = await Process.run(
        'plutil',
        ['-convert', 'json', '-o', '-', tmp.path],
      );
      if (json.exitCode != 0) return null;
      final jsonOut = json.stdout;
      return jsonOut is String ? jsonOut : null;
    } finally {
      try {
        tmp.deleteSync();
      } catch (_) {
        // Best effort — leaking a temp file is preferable to crashing.
      }
    }
  } on ProcessException {
    return null;
  }
}
