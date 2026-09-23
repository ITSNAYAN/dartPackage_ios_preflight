import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('parseBundleIdentifier', () {
    test('extracts the first non-Tests bundle identifier', () {
      const pbx = r'''
      buildSettings = {
        PRODUCT_BUNDLE_IDENTIFIER = com.example.myapp;
      };
      buildSettings = {
        PRODUCT_BUNDLE_IDENTIFIER = com.example.myappTests;
      };
''';
      expect(parseBundleIdentifier(pbx), 'com.example.myapp');
    });

    test('skips *Tests bundle IDs and returns the app one', () {
      const pbx = r'''
        PRODUCT_BUNDLE_IDENTIFIER = com.example.appTests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
''';
      expect(parseBundleIdentifier(pbx), 'com.example.app');
    });

    test('returns null when no bundle identifier is present', () {
      expect(parseBundleIdentifier('no bundle here'), isNull);
    });

    test('returns null for empty input', () {
      expect(parseBundleIdentifier(''), isNull);
    });
  });

  group('detectsAutomaticSigning', () {
    test('returns true when any block declares Automatic', () {
      expect(detectsAutomaticSigning('CODE_SIGN_STYLE = Automatic;'), isTrue);
    });

    test('returns false when only Manual is present', () {
      expect(detectsAutomaticSigning('CODE_SIGN_STYLE = Manual;'), isFalse);
    });

    test('returns false when no code-sign-style setting is present', () {
      expect(detectsAutomaticSigning('unrelated content'), isFalse);
    });

    test('detects mixed Automatic + Manual as automatic (permissive skip)',
        () {
      const pbx = r'''
        CODE_SIGN_STYLE = Manual;
        CODE_SIGN_STYLE = Automatic;
''';
      expect(detectsAutomaticSigning(pbx), isTrue);
    });
  });
}
