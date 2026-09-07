import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('appleSdkRequirements table', () {
    test('is non-empty', () {
      expect(appleSdkRequirements, isNotEmpty);
    });

    test('is sorted by effectiveDate ascending', () {
      for (var i = 1; i < appleSdkRequirements.length; i++) {
        final prev = appleSdkRequirements[i - 1].effectiveDate;
        final cur = appleSdkRequirements[i].effectiveDate;
        expect(cur.isAfter(prev), isTrue,
            reason:
                'Requirement at index $i ($cur) is not after index ${i - 1} ($prev)');
      }
    });

    test('every entry has a plausible Xcode major and non-empty SDK label', () {
      for (final req in appleSdkRequirements) {
        expect(req.minXcodeMajor, greaterThanOrEqualTo(15));
        expect(req.minSdkLabel, isNotEmpty);
      }
    });
  });
}
