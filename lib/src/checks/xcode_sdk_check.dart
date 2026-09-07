import 'dart:io';

import '../data/apple_sdk_requirements.dart';
import '../util/xcode_version.dart';
import 'check.dart';

/// Probes the local machine for the installed Xcode. Returns `null` when
/// Xcode isn't found or its version can't be parsed.
typedef XcodeInstallationProbe = Future<XcodeInstallation?> Function();

/// Returns "now"; injected so tests can pin the clock relative to Apple's
/// deadline table.
typedef Clock = DateTime Function();

/// Checks whether the installed Xcode can upload builds to App Store Connect.
///
/// Two concerns are combined:
///   1. Does the Xcode major version meet Apple's current App Store Connect
///      minimum (data table: [appleSdkRequirements]).
///   2. Is it a *released* Xcode or a beta. App Store review submissions
///      only accept Release Candidate / GM builds; beta Xcodes work for
///      TestFlight only (and Apple retires older betas as new ones ship).
class XcodeSdkCheck extends Check {
  final XcodeInstallationProbe _probe;
  final Clock _now;
  final List<AppleSdkRequirement> _requirements;
  final Duration warnWindow;

  XcodeSdkCheck({
    XcodeInstallationProbe? probe,
    Clock? now,
    List<AppleSdkRequirement>? requirements,
    this.warnWindow = const Duration(days: 90),
  })  : _probe = probe ?? _defaultProbe,
        _now = now ?? DateTime.now,
        _requirements = requirements ?? appleSdkRequirements;

  @override
  String get id => 'xcode_sdk';

  @override
  String get title => 'App Store Connect upload — Xcode / SDK requirement';

  @override
  Future<CheckResult> run() async {
    final XcodeInstallation? installation;
    try {
      installation = await _probe();
    } on ProcessException catch (e) {
      return CheckResult.fail(
        title,
        detail:
            'Uploads cannot be verified — could not probe Xcode: ${e.message}',
        remediation:
            'Install Xcode from the Mac App Store, then run: '
            'sudo xcode-select --switch /Applications/Xcode.app',
      );
    }

    if (installation == null) {
      return CheckResult.fail(
        title,
        detail:
            'Uploads cannot be verified — `xcodebuild -version` was not found '
            'or produced unparseable output.',
        remediation:
            'Install Xcode from the Mac App Store, then run: '
            'sudo xcode-select --switch /Applications/Xcode.app',
      );
    }

    final version = installation.version;
    final channel = installation.channel;
    final today = _now();
    final sorted = [..._requirements]
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    AppleSdkRequirement? active;
    AppleSdkRequirement? upcoming;
    for (final req in sorted) {
      if (req.effectiveDate.isAfter(today)) {
        upcoming ??= req;
      } else {
        active = req;
      }
    }

    // 1. Hard fail: Xcode major is below the currently-enforced minimum.
    //    Dominates everything else — even a beta below floor is fail.
    if (active != null && version.major < active.minXcodeMajor) {
      final effective = _formatDate(active.effectiveDate);
      return CheckResult.fail(
        title,
        detail:
            'Uploads will be rejected. Xcode ${version.display} installed, but '
            'App Store Connect has required Xcode ${active.minXcodeMajor}+ '
            '(${active.minSdkLabel}) for uploads since $effective.',
        remediation:
            'Install Xcode ${active.minXcodeMajor} or later from the Mac App '
            'Store, then run: sudo xcode-select --switch /Applications/Xcode.app',
      );
    }

    // 2. Warn: Xcode is a beta build. TestFlight OK (while beta is current),
    //    but App Store review will reject. Dominates the upcoming-deadline
    //    warn because it describes a rejection risk *today*, not future.
    if (channel == XcodeChannel.beta) {
      return CheckResult.warn(
        title,
        detail:
            'Xcode ${version.display} is a beta build.\n'
            '  ✅ TestFlight: uploads accepted (while this beta is still '
            'current — Apple retires older betas as new ones ship)\n'
            '  ❌ App Store distribution: will be rejected (Apple requires a '
            'Release Candidate or GM build for review submissions)',
        remediation:
            'For App Store submissions, install the latest released Xcode from '
            'the Mac App Store or an RC from developer.apple.com/download, '
            'then run: sudo xcode-select --switch /Applications/Xcode.app',
      );
    }

    // 3. Warn: an upcoming deadline is within the warn window and the current
    //    Xcode won't meet it.
    if (upcoming != null && version.major < upcoming.minXcodeMajor) {
      final daysUntil = upcoming.effectiveDate.difference(today).inDays;
      if (daysUntil <= warnWindow.inDays) {
        final effective = _formatDate(upcoming.effectiveDate);
        return CheckResult.warn(
          title,
          detail:
              'Uploads accepted today, but will be rejected from $effective '
              '($daysUntil days away). Xcode ${version.display} installed; '
              'App Store Connect will require Xcode ${upcoming.minXcodeMajor}+ '
              '(${upcoming.minSdkLabel}).',
          remediation:
              'Upgrade to Xcode ${upcoming.minXcodeMajor} before $effective '
              'to keep submitting.',
        );
      }
    }

    // 4. Pass.
    final detail = active != null
        ? 'Uploads accepted (TestFlight and App Store). Xcode '
            '${version.display} meets App Store Connect\'s current requirement '
            '(Xcode ${active.minXcodeMajor}+, ${active.minSdkLabel}, effective '
            '${_formatDate(active.effectiveDate)}).'
        : 'Uploads accepted. Xcode ${version.display} installed; no App Store '
            'Connect Xcode minimum currently in force.';
    return CheckResult.pass(title, detail: detail);
  }

  static Future<XcodeInstallation?> _defaultProbe() async {
    XcodeVersion? version;
    try {
      final result = await Process.run('xcodebuild', ['-version']);
      if (result.exitCode != 0) return null;
      final stdout = result.stdout;
      if (stdout is! String) return null;
      version = XcodeVersion.tryParse(stdout);
    } on ProcessException {
      return null;
    }
    if (version == null) return null;

    final bundlePath = await _resolveBundlePath();
    final channel = bundlePath != null
        ? await _detectChannel(bundlePath)
        : XcodeChannel.unknown;

    return XcodeInstallation(
      version: version,
      channel: channel,
      bundlePath: bundlePath,
    );
  }

  /// Returns the path to the active Xcode.app bundle, e.g.
  /// `/Applications/Xcode.app`, by asking `xcode-select -p` for the developer
  /// dir and stripping the trailing `/Contents/Developer`.
  static Future<String?> _resolveBundlePath() async {
    try {
      final result = await Process.run('xcode-select', ['-p']);
      if (result.exitCode != 0) return null;
      final stdout = result.stdout;
      if (stdout is! String) return null;
      final devDir = stdout.trim();
      final marker = '.app/';
      final idx = devDir.indexOf(marker);
      if (idx == -1) return null;
      return devDir.substring(0, idx + '.app'.length);
    } on ProcessException {
      return null;
    }
  }

  /// Reads `<bundle>/Contents/Resources/LicenseInfo.plist`'s `licenseType`
  /// field via `plutil -extract`. Apple's installer sets this to `Beta` for
  /// beta builds and `Release`/`GM` for shipping builds — authoritative even
  /// if the user renames the app bundle. Falls back to a path-name heuristic
  /// if the plist read fails.
  static Future<XcodeChannel> _detectChannel(String bundlePath) async {
    final licenseInfoPath = '$bundlePath/Contents/Resources/LicenseInfo.plist';
    try {
      final result = await Process.run(
        'plutil',
        ['-extract', 'licenseType', 'raw', licenseInfoPath],
      );
      if (result.exitCode == 0 && result.stdout is String) {
        final value = (result.stdout as String).trim().toLowerCase();
        if (value.contains('beta')) return XcodeChannel.beta;
        if (value.isNotEmpty) return XcodeChannel.release;
      }
    } on ProcessException {
      // fall through to bundle-name heuristic
    }

    final bundleName = bundlePath.split('/').last.toLowerCase();
    if (bundleName.contains('beta')) return XcodeChannel.beta;
    if (bundleName.endsWith('.app')) return XcodeChannel.release;
    return XcodeChannel.unknown;
  }
}

String _formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$y-$m-$dd';
}
