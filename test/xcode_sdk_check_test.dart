import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

XcodeInstallation _install(
  int major, [
  int minor = 0,
  XcodeChannel channel = XcodeChannel.release,
]) {
  return XcodeInstallation(
    version: XcodeVersion(
      major: major,
      minor: minor,
      raw: 'Xcode $major.$minor',
    ),
    channel: channel,
    bundlePath: channel == XcodeChannel.beta
        ? '/Applications/Xcode-beta.app'
        : '/Applications/Xcode.app',
  );
}

final _fixedRequirements = <AppleSdkRequirement>[
  AppleSdkRequirement(
    effectiveDate: DateTime.utc(2025, 4, 24),
    minXcodeMajor: 16,
    minSdkLabel: 'iOS 18 SDK',
  ),
  AppleSdkRequirement(
    effectiveDate: DateTime.utc(2026, 4, 28),
    minXcodeMajor: 26,
    minSdkLabel: 'iOS 26 SDK',
  ),
];

XcodeSdkCheck _check({
  required XcodeInstallation? installation,
  required DateTime now,
  Duration warnWindow = const Duration(days: 90),
}) {
  return XcodeSdkCheck(
    probe: () async => installation,
    now: () => now,
    requirements: _fixedRequirements,
    warnWindow: warnWindow,
  );
}

void main() {
  group('XcodeSdkCheck', () {
    test('passes when a release Xcode meets the current in-force minimum',
        () async {
      final result = await _check(
        installation: _install(26, 0),
        now: DateTime.utc(2026, 9, 6),
      ).run();
      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('Uploads accepted'));
      expect(result.detail, contains('TestFlight and App Store'));
      expect(result.detail, contains('Xcode 26+'));
    });

    test('fails when Xcode is below the current in-force minimum', () async {
      final result = await _check(
        installation: _install(16, 2),
        now: DateTime.utc(2026, 9, 6),
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('Uploads will be rejected'));
      expect(result.detail, contains('Xcode 16.2'));
      expect(result.detail, contains('Xcode 26+'));
      expect(result.detail, contains('2026-04-28'));
      expect(result.remediation, contains('Xcode 26'));
    });

    test('warns when the installed Xcode is a beta build', () async {
      final result = await _check(
        installation: _install(27, 0, XcodeChannel.beta),
        now: DateTime.utc(2026, 9, 7),
      ).run();
      expect(result.status, CheckStatus.warn);
      expect(result.detail, contains('beta build'));
      expect(result.detail, contains('✅ TestFlight'));
      expect(result.detail, contains('❌ App Store distribution'));
      expect(result.detail, contains('will be rejected'));
      expect(result.remediation, contains('RC'));
    });

    test('warns when an upcoming deadline is within the warn window', () async {
      final result = await _check(
        installation: _install(16, 2),
        now: DateTime.utc(2026, 3, 1),
      ).run();
      expect(result.status, CheckStatus.warn);
      expect(result.detail, contains('Uploads accepted today'));
      expect(result.detail, contains('will be rejected from 2026-04-28'));
      expect(result.detail, contains('days away'));
    });

    test('passes cleanly when a future deadline is beyond the warn window',
        () async {
      final result = await _check(
        installation: _install(16, 2),
        now: DateTime.utc(2025, 5, 1),
      ).run();
      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('Uploads accepted'));
    });

    test('fails when the probe returns null (xcodebuild missing/unparseable)',
        () async {
      final result = await _check(
        installation: null,
        now: DateTime.utc(2026, 9, 6),
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('Uploads cannot be verified'));
      expect(result.detail, contains('xcodebuild'));
      expect(result.remediation, contains('xcode-select'));
    });

    test('below-floor beta still fails (fail beats beta-warn)', () async {
      final result = await _check(
        installation: _install(16, 2, XcodeChannel.beta),
        now: DateTime.utc(2026, 9, 6),
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('Uploads will be rejected'));
    });
  });
}
