import 'dart:io';

import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('inspectProjectRoot', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ios_preflight_root_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('reports NotAFlutterIosProject when pubspec.yaml is missing', () {
      final result = inspectProjectRoot(tmp.path);
      expect(result, isA<NotAFlutterIosProject>());
      expect((result as NotAFlutterIosProject).reason, contains('pubspec.yaml'));
    });

    test('reports NotAFlutterIosProject when pubspec.lock is missing', () {
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
      final result = inspectProjectRoot(tmp.path);
      expect(result, isA<NotAFlutterIosProject>());
      expect((result as NotAFlutterIosProject).reason,
          contains('pubspec.lock'));
    });

    test('reports NotAFlutterIosProject when ios/Runner/Info.plist is missing',
        () {
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
      File('${tmp.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
      final result = inspectProjectRoot(tmp.path);
      expect(result, isA<NotAFlutterIosProject>());
      expect((result as NotAFlutterIosProject).reason, contains('Info.plist'));
    });

    test('returns FlutterProject with all three paths when all present', () {
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
      File('${tmp.path}/pubspec.lock').writeAsStringSync('packages: {}\n');
      Directory('${tmp.path}/ios/Runner').createSync(recursive: true);
      File('${tmp.path}/ios/Runner/Info.plist').writeAsStringSync('<plist/>\n');

      final result = inspectProjectRoot(tmp.path);
      expect(result, isA<FlutterProject>());
      final project = result as FlutterProject;
      expect(project.rootPath, tmp.path);
      expect(project.pubspecLockPath, endsWith('/pubspec.lock'));
      expect(project.infoPlistPath, endsWith('/ios/Runner/Info.plist'));
    });
  });
}
