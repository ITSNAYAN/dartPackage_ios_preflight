import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('permissionPlugins mapping', () {
    test('is non-empty', () {
      expect(permissionPlugins, isNotEmpty);
    });

    test('every declared key looks like an iOS usage-description key', () {
      final validPrefixes = ['NS', 'NFC'];
      for (final entry in permissionPlugins.entries) {
        for (final key in entry.value) {
          expect(
            validPrefixes.any((p) => key.startsWith(p)),
            isTrue,
            reason: 'Plugin ${entry.key} declares suspicious plist key "$key"',
          );
          expect(
            key.endsWith('UsageDescription'),
            isTrue,
            reason: 'Plugin ${entry.key} declares "$key" which does not '
                'follow the NSXxxUsageDescription convention',
          );
        }
      }
    });

    test('dynamic plugins declare empty required-keys lists', () {
      expect(permissionPlugins['permission_handler'], isEmpty);
      expect(permissionPlugins['permission_handler_apple'], isEmpty);
    });
  });
}
