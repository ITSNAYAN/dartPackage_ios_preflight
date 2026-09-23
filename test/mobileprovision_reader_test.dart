import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

const _validProfile = '''
{
  "Name": "iOS Team Provisioning Profile: com.example.myapp",
  "ExpirationDate": "2027-03-14T12:34:56Z",
  "Entitlements": {
    "application-identifier": "ABCDE12345.com.example.myapp"
  }
}
''';

const _wildcardProfile = '''
{
  "Name": "iOS Team Wildcard",
  "ExpirationDate": "2027-01-01T00:00:00Z",
  "Entitlements": {
    "application-identifier": "ABCDE12345.com.example.*"
  }
}
''';

void main() {
  group('readProvisioningProfile', () {
    test('parses name, expiration date, and application-identifier',
        () async {
      final p = await readProvisioningProfile(
        '/fake/profile.mobileprovision',
        decoder: (_) async => _validProfile,
      );
      expect(p, isNotNull);
      expect(p!.fileName, 'profile.mobileprovision');
      expect(p.name, contains('com.example.myapp'));
      expect(p.applicationIdentifier, 'ABCDE12345.com.example.myapp');
      expect(p.expirationDate, DateTime.utc(2027, 3, 14, 12, 34, 56));
    });

    test('returns null when decoder returns null', () async {
      final p = await readProvisioningProfile(
        '/fake/x.mobileprovision',
        decoder: (_) async => null,
      );
      expect(p, isNull);
    });

    test('returns null when decoder output is not valid JSON', () async {
      final p = await readProvisioningProfile(
        '/fake/x.mobileprovision',
        decoder: (_) async => 'not json',
      );
      expect(p, isNull);
    });

    test('returns null when decoder output is not a JSON object', () async {
      final p = await readProvisioningProfile(
        '/fake/x.mobileprovision',
        decoder: (_) async => '[]',
      );
      expect(p, isNull);
    });

    test('handles missing ExpirationDate / entitlements gracefully',
        () async {
      final p = await readProvisioningProfile(
        '/fake/x.mobileprovision',
        decoder: (_) async => '{"Name": "no fields"}',
      );
      expect(p, isNotNull);
      expect(p!.name, 'no fields');
      expect(p.expirationDate, isNull);
      expect(p.applicationIdentifier, isNull);
    });
  });

  group('ProvisioningProfile.matchesBundleId', () {
    test('exact match returns true', () async {
      final p = await readProvisioningProfile(
        '/fake/p.mobileprovision',
        decoder: (_) async => _validProfile,
      );
      expect(p!.matchesBundleId('com.example.myapp'), isTrue);
    });

    test('non-matching bundle id returns false', () async {
      final p = await readProvisioningProfile(
        '/fake/p.mobileprovision',
        decoder: (_) async => _validProfile,
      );
      expect(p!.matchesBundleId('com.example.other'), isFalse);
    });

    test('wildcard profile matches any bundle under the prefix', () async {
      final p = await readProvisioningProfile(
        '/fake/p.mobileprovision',
        decoder: (_) async => _wildcardProfile,
      );
      expect(p!.matchesBundleId('com.example.anything'), isTrue);
      expect(p.matchesBundleId('com.example.myapp'), isTrue);
      expect(p.matchesBundleId('com.other.app'), isFalse);
    });

    test('missing application-identifier returns false', () async {
      final p = await readProvisioningProfile(
        '/fake/p.mobileprovision',
        decoder: (_) async => '{"Name": "empty"}',
      );
      expect(p!.matchesBundleId('anything'), isFalse);
    });
  });
}
