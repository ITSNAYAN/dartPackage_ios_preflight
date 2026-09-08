import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

const _sample = '''
packages:
  image_picker:
    dependency: "direct main"
    description:
      name: image_picker
      url: "https://pub.dev"
    source: hosted
    version: "1.1.2"
  image_picker_ios:
    dependency: transitive
    description:
      name: image_picker_ios
      url: "https://pub.dev"
    source: hosted
    version: "0.8.12"
  http:
    dependency: "direct main"
    version: "1.2.0"
sdks:
  dart: ">=3.11.0 <4.0.0"
''';

void main() {
  group('parsePubspecLock', () {
    test('extracts every package with name, version, dependency kind', () {
      final packages = parsePubspecLock(_sample);
      expect(packages, hasLength(3));

      final ip = packages.firstWhere((p) => p.name == 'image_picker');
      expect(ip.version, '1.1.2');
      expect(ip.dependency, 'direct main');

      final ipIos = packages.firstWhere((p) => p.name == 'image_picker_ios');
      expect(ipIos.version, '0.8.12');
      expect(ipIos.dependency, 'transitive');
    });

    test('includes transitive deps, not just direct ones', () {
      final packages = parsePubspecLock(_sample);
      final names = packages.map((p) => p.name).toSet();
      expect(names, contains('image_picker_ios'));
    });

    test('returns empty list for malformed YAML', () {
      expect(parsePubspecLock('!!not: [valid: yaml'), isEmpty);
    });

    test('returns empty list when `packages:` key is missing', () {
      expect(parsePubspecLock('sdks:\n  dart: "3.0.0"\n'), isEmpty);
    });

    test('returns empty list for empty input', () {
      expect(parsePubspecLock(''), isEmpty);
    });

    test('skips entries missing a version string', () {
      const partial = '''
packages:
  broken:
    dependency: transitive
  ok:
    dependency: transitive
    version: "1.0.0"
''';
      final packages = parsePubspecLock(partial);
      expect(packages.map((p) => p.name), ['ok']);
    });
  });
}
