import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

const _sample = r'''
/* Begin XCBuildConfiguration section */
    97C147031CF9000F007C117D /* Debug */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        ALWAYS_SEARCH_USER_PATHS = NO;
        IPHONEOS_DEPLOYMENT_TARGET = 12.0;
        SDKROOT = iphoneos;
      };
      name = Debug;
    };
    97C147041CF9000F007C117D /* Release */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        IPHONEOS_DEPLOYMENT_TARGET = 13.0;
        SDKROOT = iphoneos;
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
/* End XCBuildConfiguration section */
''';

void main() {
  group('parseDeploymentTargets', () {
    test('extracts a hit per configuration with the config name', () {
      final hits = parseDeploymentTargets(_sample);
      expect(hits, hasLength(3));

      final byName = {for (final h in hits) h.configName: h.version};
      expect(byName['Debug'], '12.0');
      expect(byName['Release'], '13.0');
      expect(byName['Profile'], '13.0');
    });

    test('preserves duplicates so mismatch detection is possible', () {
      final hits = parseDeploymentTargets(_sample);
      final versions = hits.map((h) => h.version).toList();
      expect(versions, containsAll(['12.0', '13.0', '13.0']));
    });

    test('returns empty list when no target lines present', () {
      const empty = r'''
    97C147031CF9000F007C117D /* Debug */ = {
      isa = XCBuildConfiguration;
      buildSettings = {
        ALWAYS_SEARCH_USER_PATHS = NO;
      };
      name = Debug;
    };
''';
      expect(parseDeploymentTargets(empty), isEmpty);
    });

    test('handles a single lone target line without a name pairing', () {
      const partial = 'IPHONEOS_DEPLOYMENT_TARGET = 11.0;';
      final hits = parseDeploymentTargets(partial);
      expect(hits, hasLength(1));
      expect(hits.first.version, '11.0');
      // config name should be null since there is no `name = X;` after it
      expect(hits.first.configName, isNull);
    });

    test('returns empty list for empty input', () {
      expect(parseDeploymentTargets(''), isEmpty);
    });
  });
}
