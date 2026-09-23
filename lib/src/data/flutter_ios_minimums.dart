/// One entry in Flutter's own iOS deployment target policy: from
/// [sinceFlutter] onward, every Flutter iOS project must target at least
/// [minIosTarget].
class FlutterIosMinimum {
  final String sinceFlutter;
  final String minIosTarget;

  const FlutterIosMinimum({
    required this.sinceFlutter,
    required this.minIosTarget,
  });
}

/// Bundled mirror of Flutter's own iOS deployment target requirements.
///
/// Keep sorted ascending by [FlutterIosMinimum.sinceFlutter] — the check
/// treats the last entry whose Flutter version is ≤ the installed Flutter as
/// the currently-enforced minimum.
///
/// Update this list whenever Flutter bumps its iOS floor (announced in
/// Flutter release notes). Grows via community PRs, same principle as
/// [appleSdkRequirements].
final List<FlutterIosMinimum> flutterIosMinimums = <FlutterIosMinimum>[
  FlutterIosMinimum(sinceFlutter: '3.16.0', minIosTarget: '12.0'),
  FlutterIosMinimum(sinceFlutter: '3.24.0', minIosTarget: '13.0'),
];
