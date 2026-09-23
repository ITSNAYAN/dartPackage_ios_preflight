import 'package:ios_preflight/ios_preflight.dart';
import 'package:test/test.dart';

void main() {
  group('flutterIosMinimums table', () {
    test('is non-empty', () {
      expect(flutterIosMinimums, isNotEmpty);
    });

    test('is sorted by sinceFlutter ascending (SemVer-lexical)', () {
      for (var i = 1; i < flutterIosMinimums.length; i++) {
        final prev = flutterIosMinimums[i - 1].sinceFlutter;
        final cur = flutterIosMinimums[i].sinceFlutter;
        expect(cur.compareTo(prev) > 0, isTrue,
            reason:
                'Entry at index $i ($cur) is not after index ${i - 1} ($prev)');
      }
    });

    test('every minIosTarget looks like a plausible iOS version', () {
      final pattern = RegExp(r'^\d+(?:\.\d+){0,2}$');
      for (final entry in flutterIosMinimums) {
        expect(pattern.hasMatch(entry.minIosTarget), isTrue,
            reason: 'Bad target: ${entry.minIosTarget}');
      }
    });
  });
}
