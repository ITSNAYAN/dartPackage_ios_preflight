import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('XcodeVersion.tryParse', () {
    test('parses major.minor with build line', () {
      final v = XcodeVersion.tryParse('Xcode 16.2\nBuild version 16C5032a\n');
      expect(v, isNotNull);
      expect(v!.major, 16);
      expect(v.minor, 2);
      expect(v.patch, isNull);
      expect(v.build, '16C5032a');
      expect(v.display, '16.2');
    });

    test('parses major-only version', () {
      final v = XcodeVersion.tryParse('Xcode 26\n');
      expect(v, isNotNull);
      expect(v!.major, 26);
      expect(v.minor, 0);
      expect(v.display, '26.0');
    });

    test('parses major.minor.patch', () {
      final v = XcodeVersion.tryParse('Xcode 15.4.1\n');
      expect(v, isNotNull);
      expect(v!.major, 15);
      expect(v.minor, 4);
      expect(v.patch, 1);
      expect(v.display, '15.4.1');
    });

    test('returns null for non-Xcode output', () {
      expect(XcodeVersion.tryParse(''), isNull);
      expect(XcodeVersion.tryParse('command not found\n'), isNull);
      expect(XcodeVersion.tryParse('Xcode is great\n'), isNull);
    });
  });
}
