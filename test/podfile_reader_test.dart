import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('parsePodfilePlatform', () {
    test('extracts version from single-quoted declaration', () {
      const podfile = '''
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
''';
      expect(parsePodfilePlatform(podfile), '13.0');
    });

    test('extracts version from double-quoted declaration', () {
      expect(parsePodfilePlatform('platform :ios, "12.0"\n'), '12.0');
    });

    test('handles extra whitespace around tokens', () {
      expect(parsePodfilePlatform("   platform   :ios ,   '14.5'\n"), '14.5');
    });

    test('supports patch versions like 13.0.1', () {
      expect(parsePodfilePlatform("platform :ios, '13.0.1'\n"), '13.0.1');
    });

    test('ignores a commented-out platform line', () {
      const podfile = '''
# platform :ios, '9.0'
source 'https://cdn.cocoapods.org/'
''';
      expect(parsePodfilePlatform(podfile), isNull);
    });

    test('picks the first uncommented declaration when both exist', () {
      const podfile = '''
# platform :ios, '9.0'
platform :ios, '13.0'
''';
      expect(parsePodfilePlatform(podfile), '13.0');
    });

    test('returns null when no platform line exists', () {
      expect(parsePodfilePlatform("source 'https://cdn.cocoapods.org/'\n"),
          isNull);
    });

    test('returns null for empty input', () {
      expect(parsePodfilePlatform(''), isNull);
    });
  });
}
