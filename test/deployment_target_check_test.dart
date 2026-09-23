import 'dart:io';

import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

/// Creates a temp Flutter-project skeleton so `inspectProjectRoot` succeeds.
Directory _fakeProjectDir() {
  final tmp = Directory.systemTemp.createTempSync('ios_preflight_dt_');
  File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
  File('${tmp.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
  Directory('${tmp.path}/ios/Runner').createSync(recursive: true);
  File('${tmp.path}/ios/Runner/Info.plist').writeAsStringSync('<plist/>\n');
  Directory('${tmp.path}/ios/Runner.xcodeproj').createSync(recursive: true);
  return tmp;
}

DeploymentTargetCheck _check({
  required String rootPath,
  required String podfile,
  required String pbxproj,
  String? flutterVersion = '3.24.0',
}) {
  return DeploymentTargetCheck(
    projectRoot: () => rootPath,
    flutterVersion: () async => flutterVersion,
    readFile: (path) async {
      if (path.endsWith('/ios/Podfile')) return podfile;
      if (path.endsWith('/project.pbxproj')) return pbxproj;
      throw FileSystemException('unexpected read: $path');
    },
    flutterMinimums: const [
      FlutterIosMinimum(sinceFlutter: '3.16.0', minIosTarget: '12.0'),
      FlutterIosMinimum(sinceFlutter: '3.24.0', minIosTarget: '13.0'),
    ],
  );
}

/// A helper to write both real files to disk so the check's `existsSync`
/// gates pass. Only needed for tests that actually want the file to exist.
void _placeFiles(
  Directory dir, {
  String? podfile,
  String? pbxproj,
}) {
  if (podfile != null) {
    File('${dir.path}/ios/Podfile').writeAsStringSync(podfile);
  }
  if (pbxproj != null) {
    File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
        .writeAsStringSync(pbxproj);
  }
}

const _pbxprojAll13 = r'''
    97C147031CF9000F007C117D /* Debug */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        IPHONEOS_DEPLOYMENT_TARGET = 13.0;
      };
      name = Debug;
    };
    97C147041CF9000F007C117D /* Release */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        IPHONEOS_DEPLOYMENT_TARGET = 13.0;
      };
      name = Release;
    };
    97C147051CF9000F007C117D /* Profile */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        IPHONEOS_DEPLOYMENT_TARGET = 13.0;
      };
      name = Profile;
    };
''';

const _pbxprojMixedConfigs = r'''
    a /* Debug */ = {
      buildSettings = { IPHONEOS_DEPLOYMENT_TARGET = 13.0; };
      name = Debug;
    };
    b /* Release */ = {
      buildSettings = { IPHONEOS_DEPLOYMENT_TARGET = 14.0; };
      name = Release;
    };
''';

const _pbxprojAll11 = r'''
    a /* Debug */ = {
      buildSettings = { IPHONEOS_DEPLOYMENT_TARGET = 11.0; };
      name = Debug;
    };
''';

void main() {
  group('DeploymentTargetCheck', () {
    late Directory tmp;

    setUp(() => tmp = _fakeProjectDir());
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('skips when directory is not a Flutter iOS project', () async {
      final barren = Directory.systemTemp.createTempSync('barren_');
      addTearDown(() => barren.deleteSync(recursive: true));

      final result = await DeploymentTargetCheck(
        projectRoot: () => barren.path,
        flutterVersion: () async => '3.24.0',
        readFile: (_) async => '',
      ).run();

      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('Skipped'));
    });

    test('skips when Podfile has no platform declaration', () async {
      _placeFiles(tmp,
          podfile: "# platform :ios, '13.0'\n", pbxproj: _pbxprojAll13);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "# platform :ios, '13.0'\n",
        pbxproj: _pbxprojAll13,
      ).run();
      expect(result.status, CheckStatus.skip);
      expect(result.detail, contains('no `platform :ios'));
    });

    test('fails when pbxproj file is missing', () async {
      _placeFiles(tmp, podfile: "platform :ios, '13.0'\n");
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '13.0'\n",
        pbxproj: '',
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('project.pbxproj not found'));
    });

    test('fails when pbxproj has no IPHONEOS_DEPLOYMENT_TARGET lines',
        () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '13.0'\n", pbxproj: '/* empty */');
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '13.0'\n",
        pbxproj: '/* empty */',
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('no IPHONEOS_DEPLOYMENT_TARGET'));
    });

    test('fails when a target is below Flutter\'s current minimum', () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '11.0'\n", pbxproj: _pbxprojAll11);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '11.0'\n",
        pbxproj: _pbxprojAll11,
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('below Flutter'));
      expect(result.detail, contains('iOS 13.0'));
    });

    test('fails when Podfile disagrees with pbxproj', () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '14.0'\n", pbxproj: _pbxprojAll13);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '14.0'\n",
        pbxproj: _pbxprojAll13,
      ).run();
      expect(result.status, CheckStatus.fail);
      expect(result.detail, contains('Podfile and Xcode project disagree'));
      expect(result.detail, contains('iOS 14.0'));
      expect(result.detail, contains('iOS 13.0'));
    });

    test('warns when pbxproj configs disagree with each other', () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '13.0'\n", pbxproj: _pbxprojMixedConfigs);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '13.0'\n",
        pbxproj: _pbxprojMixedConfigs,
      ).run();
      expect(result.status, CheckStatus.warn);
      expect(result.detail, contains('Xcode build configurations disagree'));
      expect(result.detail, contains('Debug'));
      expect(result.detail, contains('Release'));
    });

    test('passes when everything agrees at/above Flutter minimum', () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '13.0'\n", pbxproj: _pbxprojAll13);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '13.0'\n",
        pbxproj: _pbxprojAll13,
      ).run();
      expect(result.status, CheckStatus.pass);
      expect(result.detail, contains('iOS 13.0'));
      expect(result.detail, contains('Flutter'));
    });

    test('passes without Flutter-floor note when Flutter is not installed',
        () async {
      _placeFiles(tmp,
          podfile: "platform :ios, '13.0'\n", pbxproj: _pbxprojAll13);
      final result = await _check(
        rootPath: tmp.path,
        podfile: "platform :ios, '13.0'\n",
        pbxproj: _pbxprojAll13,
        flutterVersion: null,
      ).run();
      expect(result.status, CheckStatus.pass);
      expect(result.detail, isNot(contains('Flutter')));
    });
  });
}
