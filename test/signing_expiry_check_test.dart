import 'dart:convert';
import 'dart:io';

import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

/// Creates a temp Flutter-project skeleton so `inspectProjectRoot` succeeds.
Directory _fakeProjectDir() {
  final tmp = Directory.systemTemp.createTempSync('ios_preflight_sign_');
  File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
  File('${tmp.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
  Directory('${tmp.path}/ios/Runner').createSync(recursive: true);
  File('${tmp.path}/ios/Runner/Info.plist').writeAsStringSync('<plist/>\n');
  Directory('${tmp.path}/ios/Runner.xcodeproj').createSync(recursive: true);
  return tmp;
}

String _pbxproj({
  required String bundleId,
  bool automatic = false,
}) {
  final signStyle = automatic ? 'Automatic' : 'Manual';
  return '''
  buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = $bundleId;
    CODE_SIGN_STYLE = $signStyle;
  };
''';
}

String _profileJson({
  required String appId,
  required DateTime expiry,
  String name = 'iOS Team Profile',
}) {
  return jsonEncode({
    'Name': name,
    'ExpirationDate': expiry.toUtc().toIso8601String(),
    'Entitlements': {'application-identifier': appId},
  });
}

/// Wires a check to fixture inputs: pbxproj text in the tmp project, and a
/// map of profilePath → JSON body served by the decoder typedef.
SigningExpiryCheck _check({
  required Directory tmp,
  required String pbxproj,
  Map<String, String> profileJsons = const {},
  DateTime? now,
  Duration warnWindow = const Duration(days: 30),
}) {
  File('${tmp.path}/ios/Runner.xcodeproj/project.pbxproj')
      .writeAsStringSync(pbxproj);

  return SigningExpiryCheck(
    projectRoot: () => tmp.path,
    profilesLister: () async => profileJsons.keys.toList(),
    decoder: (path) async => profileJsons[path],
    now: () => now ?? DateTime.utc(2026, 9, 10),
    warnWindow: warnWindow,
  );
}

void main() {
  group('SigningExpiryCheck', () {
    late Directory tmp;

    setUp(() => tmp = _fakeProjectDir());
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('skips when directory is not a Flutter iOS project', () async {
      final barren = Directory.systemTemp.createTempSync('barren_');
      addTearDown(() => barren.deleteSync(recursive: true));
      final result = await SigningExpiryCheck(
        projectRoot: () => barren.path,
        profilesLister: () async => const [],
        decoder: (_) async => null,
      ).run();
      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('Skipped'));
    });

    test('skips when Xcode automatic signing is enabled', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app', automatic: true),
      ).run();
      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('automatic signing'));
    });

    test('skips when no profiles are installed', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: const {},
      ).run();
      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('No provisioning profiles found'));
    });

    test('skips when installed profiles do not match this app', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/other.mobileprovision': _profileJson(
            appId: 'ABC123.com.other.app',
            expiry: DateTime.utc(2027, 1, 1),
          ),
        },
      ).run();
      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('No installed provisioning profile'));
    });

    test('fails when a matching profile is expired', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/expired.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.app',
            expiry: DateTime.utc(2026, 8, 22),
            name: 'com.example.app iOS Distribution',
          ),
        },
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('expired'));
      expect(result.detail, contains('com.example.app iOS Distribution'));
      expect(result.detail, contains('2026-08-22'));
    });

    test('warns when a matching profile is expiring within warn window',
        () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/soon.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.app',
            expiry: DateTime.utc(2026, 10, 2),
            name: 'com.example.app Development',
          ),
        },
      ).run();
      expect(result.status, CheckStatus.warn);
      expect(result.detail, contains('expiring within 30 days'));
      expect(result.detail, contains('2026-10-02'));
    });

    test('passes when a matching profile is comfortably in the future',
        () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/healthy.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.app',
            expiry: DateTime.utc(2027, 3, 14),
          ),
        },
      ).run();
      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('1 matching profile'));
      expect(result.detail, contains('com.example.app'));
    });

    test('wildcard profile matches the app and passes', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/wild.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.*',
            expiry: DateTime.utc(2027, 3, 14),
          ),
        },
      ).run();
      expect(result.status, CheckStatus.pass);
    });

    test('expired dominates soon-to-expire (fail beats warn)', () async {
      final result = await _check(
        tmp: tmp,
        pbxproj: _pbxproj(bundleId: 'com.example.app'),
        profileJsons: {
          '/fake/expired.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.app',
            expiry: DateTime.utc(2026, 8, 22),
            name: 'expired one',
          ),
          '/fake/soon.mobileprovision': _profileJson(
            appId: 'ABC123.com.example.app',
            expiry: DateTime.utc(2026, 10, 2),
            name: 'soon one',
          ),
        },
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('expired one'));
    });
  });
}
