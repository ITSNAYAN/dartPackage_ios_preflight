import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('readInfoPlist', () {
    test('extracts every string-valued top-level key', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => '''
{
  "CFBundleIdentifier": "com.example.app",
  "NSCameraUsageDescription": "We need the camera",
  "NSPhotoLibraryUsageDescription": ""
}
''',
      );
      expect(result['CFBundleIdentifier'], 'com.example.app');
      expect(result['NSCameraUsageDescription'], 'We need the camera');
      expect(result['NSPhotoLibraryUsageDescription'], '');
    });

    test('preserves empty strings (present-but-empty vs absent)', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => '{"NSCameraUsageDescription": ""}',
      );
      expect(result.containsKey('NSCameraUsageDescription'), isTrue);
      expect(result['NSCameraUsageDescription'], '');
    });

    test('drops non-string top-level values silently', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => '''
{
  "NSCameraUsageDescription": "ok",
  "UIRequiredDeviceCapabilities": ["nfc"],
  "LSRequiresIPhoneOS": true,
  "CFBundleVersion": 42
}
''',
      );
      expect(result.keys, ['NSCameraUsageDescription']);
    });

    test('returns empty map when runner returns null', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => null,
      );
      expect(result, isEmpty);
    });

    test('returns empty map when runner output is not valid JSON', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => 'not json at all',
      );
      expect(result, isEmpty);
    });

    test('returns empty map when runner output is not a JSON object', () async {
      final result = await readInfoPlist(
        '/fake/Info.plist',
        runner: (_) async => '[]',
      );
      expect(result, isEmpty);
    });
  });
}
