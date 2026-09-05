import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  test('exposes a version string matching pubspec', () {
    expect(iosPreflightVersion, '0.1.0');
  });
}
