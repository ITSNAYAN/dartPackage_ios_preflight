import 'dart:io';

import '../util/mobileprovision_reader.dart';
import '../util/project_root.dart';
import '../util/signing_settings_reader.dart';
import 'check.dart';

/// Returns the project root to inspect. Defaults to `Directory.current.path`.
typedef ProjectRootProbe = String Function();

/// Reads a file's contents as a string. Injected so tests can supply
/// in-memory fixtures without touching the disk.
typedef FileReader = Future<String> Function(String path);

/// Returns "now"; injected so tests can pin the clock relative to fixture
/// profile expiration dates.
typedef Clock = DateTime Function();

/// Warns when installed provisioning profiles that match this app's bundle
/// ID are expired or expiring soon.
///
/// Scoped to **provisioning profile expiry only** in this release. Code
/// signing certificate expiry is planned for a follow-up release — it
/// requires nested shell-outs to `security find-certificate` and
/// `openssl x509 -enddate` which are fragile enough to deserve their own
/// isolated implementation.
///
/// Precedence (top wins):
///   1. Not a Flutter iOS project → skip
///   2. Xcode automatic signing detected → skip (Xcode manages profiles)
///   3. No matching profile found for the app's bundle ID → skip with note
///   4. Any matching profile expired → fail
///   5. Any matching profile expiring within [warnWindow] → warn
///   6. All matching profiles valid + beyond warn window → pass
class SigningExpiryCheck extends Check {
  final ProjectRootProbe _rootProbe;
  final FileReader _readFile;
  final ProfilesDirectoryLister _profilesLister;
  final ProfileDecoder? _decoder;
  final Clock _now;
  final Duration warnWindow;

  SigningExpiryCheck({
    ProjectRootProbe? projectRoot,
    FileReader? readFile,
    ProfilesDirectoryLister? profilesLister,
    ProfileDecoder? decoder,
    Clock? now,
    this.warnWindow = const Duration(days: 30),
  })  : _rootProbe = projectRoot ?? _defaultRoot,
        _readFile = readFile ?? _defaultReadFile,
        _profilesLister = profilesLister ?? defaultProfilesLister,
        _decoder = decoder,
        _now = now ?? DateTime.now;

  @override
  String get id => 'signing_expiry';

  @override
  String get title => 'Provisioning profile expiry';

  @override
  Future<CheckResult> run() async {
    final project = inspectProjectRoot(_rootProbe());
    if (project is NotAFlutterIosProject) {
      return CheckResult.skip(title, detail: '${project.reason} Skipped.');
    }
    project as FlutterProject;

    if (!File(project.pbxprojPath).existsSync()) {
      return CheckResult.skip(
        title,
        detail: 'project.pbxproj not found — cannot resolve bundle ID or '
            'signing style. Skipped.',
      );
    }

    final String pbxprojText;
    try {
      pbxprojText = await _readFile(project.pbxprojPath);
    } on FileSystemException {
      return CheckResult.skip(
        title,
        detail: 'Could not read project.pbxproj. Skipped.',
      );
    }

    // 2. Skip if Xcode automatic signing is in use.
    if (detectsAutomaticSigning(pbxprojText)) {
      return CheckResult.skip(
        title,
        detail: 'Xcode automatic signing detected (CODE_SIGN_STYLE = '
            'Automatic) — profiles are managed by Xcode and may not exist '
            'as files on disk. Skipped.',
      );
    }

    final bundleId = parseBundleIdentifier(pbxprojText);
    if (bundleId == null) {
      return CheckResult.skip(
        title,
        detail: 'Could not resolve app bundle identifier from '
            'project.pbxproj. Skipped.',
      );
    }

    // 3. List and decode every profile on disk.
    final profilePaths = await _profilesLister();
    if (profilePaths.isEmpty) {
      return CheckResult.skip(
        title,
        detail: 'No provisioning profiles found in the local Xcode profiles '
            'directory. Skipped (may be a CI environment).',
      );
    }

    final profiles = <ProvisioningProfile>[];
    for (final path in profilePaths) {
      final parsed = await readProvisioningProfile(path, decoder: _decoder);
      if (parsed != null) profiles.add(parsed);
    }

    // 4. Filter to profiles matching this app.
    final matching =
        profiles.where((p) => p.matchesBundleId(bundleId)).toList();
    if (matching.isEmpty) {
      return CheckResult.skip(
        title,
        detail: 'No installed provisioning profile matches this app '
            '($bundleId). Skipped — either you signed with automatic '
            'signing, or profiles have not been downloaded yet.',
      );
    }

    // 5. Bucket by expiry state.
    final today = _now();
    final expired = <ProvisioningProfile>[];
    final expiringSoon = <_ExpirationHit>[];
    final healthy = <_ExpirationHit>[];
    for (final p in matching) {
      final exp = p.expirationDate;
      if (exp == null) continue;
      final delta = exp.difference(today);
      if (delta.isNegative) {
        expired.add(p);
      } else if (delta <= warnWindow) {
        expiringSoon
            .add(_ExpirationHit(profile: p, daysUntil: delta.inDays));
      } else {
        healthy.add(_ExpirationHit(profile: p, daysUntil: delta.inDays));
      }
    }

    // 6. Fail on expired.
    if (expired.isNotEmpty) {
      return CheckResult.fail(
        title,
        detail: _formatExpired(expired, today),
        remediation: 'Regenerate the profile at developer.apple.com, then in '
            'Xcode: Preferences → Accounts → Download Manual Profiles.',
      );
    }

    // 7. Warn on soon-to-expire.
    if (expiringSoon.isNotEmpty) {
      return CheckResult.warn(
        title,
        detail: _formatExpiringSoon(expiringSoon),
        remediation:
            'Renew the profile at developer.apple.com before it expires, '
            'then re-download in Xcode.',
      );
    }

    // 8. Pass.
    healthy.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    final nearest = healthy.first;
    return CheckResult.pass(
      title,
      detail: '${matching.length} matching '
          'profile${matching.length == 1 ? '' : 's'} for $bundleId — all '
          'valid for at least ${nearest.daysUntil} '
          'day${nearest.daysUntil == 1 ? '' : 's'}.',
    );
  }

  String _formatExpired(List<ProvisioningProfile> expired, DateTime today) {
    final buf = StringBuffer(
      '${expired.length} expired provisioning '
      'profile${expired.length == 1 ? '' : 's'}:',
    );
    for (final p in expired) {
      final exp = p.expirationDate!;
      final daysAgo = today.difference(exp).inDays;
      buf.write('\n  ❌ ${p.name ?? p.fileName} — expired '
          '${_formatDate(exp)} ($daysAgo '
          'day${daysAgo == 1 ? '' : 's'} ago)');
    }
    return buf.toString();
  }

  String _formatExpiringSoon(List<_ExpirationHit> hits) {
    final buf = StringBuffer(
      '${hits.length} matching '
      'profile${hits.length == 1 ? '' : 's'} expiring within '
      '${warnWindow.inDays} days:',
    );
    for (final h in hits) {
      buf.write('\n  ⚠️  ${h.profile.name ?? h.profile.fileName} — expires '
          '${_formatDate(h.profile.expirationDate!)} '
          '(${h.daysUntil} day${h.daysUntil == 1 ? '' : 's'})');
    }
    return buf.toString();
  }
}

class _ExpirationHit {
  final ProvisioningProfile profile;
  final int daysUntil;
  const _ExpirationHit({required this.profile, required this.daysUntil});
}

String _defaultRoot() => Directory.current.path;

Future<String> _defaultReadFile(String path) => File(path).readAsString();

String _formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$y-$m-$dd';
}
