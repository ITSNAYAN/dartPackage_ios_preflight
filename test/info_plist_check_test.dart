import 'dart:convert';
import 'dart:io';

import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

/// Creates a temporary directory with the three files inspectProjectRoot
/// requires, so [InfoPlistCheck] enters its real code path (instead of skip).
/// Contents of pubspec.lock / Info.plist come from the test's own fakes —
/// these files just have to *exist*.
Directory _fakeProjectDir() {
  final tmp = Directory.systemTemp.createTempSync('ios_preflight_check_');
  File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
  File('${tmp.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
  Directory('${tmp.path}/ios/Runner').createSync(recursive: true);
  File('${tmp.path}/ios/Runner/Info.plist').writeAsStringSync('<plist/>\n');
  return tmp;
}

InfoPlistCheck _check({
  required String rootPath,
  required String lockYaml,
  required Map<String, String> plistKeys,
  Map<String, List<String>>? mapping,
}) {
  return InfoPlistCheck(
    projectRoot: () => rootPath,
    readFile: (path) async => lockYaml,
    plutil: (_) async => jsonEncode(plistKeys),
    mapping: mapping,
  );
}

const _lockWithImagePicker = '''
packages:
  image_picker:
    dependency: "direct main"
    version: "1.1.2"
  http:
    dependency: "direct main"
    version: "1.2.0"
''';

const _lockWithNoPermissions = '''
packages:
  http:
    dependency: "direct main"
    version: "1.2.0"
''';

const _lockWithPermissionHandler = '''
packages:
  permission_handler:
    dependency: "direct main"
    version: "11.0.0"
''';

const _testMapping = <String, List<String>>{
  'image_picker': [
    'NSCameraUsageDescription',
    'NSPhotoLibraryUsageDescription',
  ],
  'permission_handler': [],
};

void main() {
  group('InfoPlistCheck', () {
    late Directory tmp;

    setUp(() => tmp = _fakeProjectDir());
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('skips when directory is not a Flutter iOS project', () async {
      final barren = Directory.systemTemp.createTempSync('barren_');
      addTearDown(() => barren.deleteSync(recursive: true));

      final result = await InfoPlistCheck(
        projectRoot: () => barren.path,
        readFile: (_) async => '',
        plutil: (_) async => '{}',
      ).run();

      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('Skipped'));
    });

    test('passes with note when no known permission plugins are installed',
        () async {
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: _lockWithNoPermissions,
        plistKeys: const {'CFBundleIdentifier': 'com.example.app'},
        mapping: _testMapping,
      ).run();

      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('No known permission-requiring plugins'));
    });

    test('passes when every required key is present and non-empty', () async {
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: _lockWithImagePicker,
        plistKeys: const {
          'NSCameraUsageDescription': 'We need the camera to take photos',
          'NSPhotoLibraryUsageDescription': 'We need the library to pick media',
        },
        mapping: _testMapping,
      ).run();

      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('2 required usage description keys'));
    });

    test('fails when a required key is missing', () async {
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: _lockWithImagePicker,
        plistKeys: const {
          'NSCameraUsageDescription': 'We need the camera',
        },
        mapping: _testMapping,
      ).run();

      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('1 missing'));
      expect(result.detail, contains('NSPhotoLibraryUsageDescription'));
      expect(result.detail, contains('image_picker 1.1.2'));
      expect(result.remediation, contains('non-empty'));
    });

    test('fails when a required key is present but empty', () async {
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: _lockWithImagePicker,
        plistKeys: const {
          'NSCameraUsageDescription': '',
          'NSPhotoLibraryUsageDescription': '   ',
        },
        mapping: _testMapping,
      ).run();

      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('2 missing'));
      expect(result.detail, contains('NSCameraUsageDescription'));
      expect(result.detail, contains('NSPhotoLibraryUsageDescription'));
    });

    test('flags dynamic plugins with a manual-verify note (pass case)',
        () async {
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: _lockWithPermissionHandler,
        plistKeys: const {},
        mapping: _testMapping,
      ).run();

      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('Manually verify'));
      expect(result.detail, contains('permission_handler 11.0.0'));
    });

    test(
        'attributes a missing key to every plugin that requires it '
        '(federated plugins)', () async {
      const federatedLock = '''
packages:
  image_picker:
    dependency: "direct main"
    version: "1.1.2"
  image_picker_ios:
    dependency: transitive
    version: "0.8.12"
''';
      final result = await _check(
        rootPath: tmp.path,
        lockYaml: federatedLock,
        plistKeys: const {},
        mapping: const {
          'image_picker': ['NSCameraUsageDescription'],
          'image_picker_ios': ['NSCameraUsageDescription'],
        },
      ).run();

      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('image_picker 1.1.2'));
      expect(result.detail, contains('image_picker_ios 0.8.12'));
    });
  });
}
