/// A single App Store Connect submission requirement: from [effectiveDate]
/// onward, every uploaded build must be produced with at least Xcode
/// [minXcodeMajor] (which ships with [minSdkLabel]).
class AppleSdkRequirement {
  final DateTime effectiveDate;
  final int minXcodeMajor;
  final String minSdkLabel;

  const AppleSdkRequirement({
    required this.effectiveDate,
    required this.minXcodeMajor,
    required this.minSdkLabel,
  });
}

/// Bundled table of Apple's App Store Connect Xcode/SDK requirements, mirrored
/// from https://developer.apple.com/news/upcoming-requirements/.
///
/// Keep sorted by [AppleSdkRequirement.effectiveDate] ascending. Update this
/// list whenever Apple announces a new deadline; the check uses "most recent
/// past entry" as the currently-enforced minimum and "next future entry" for
/// the upcoming-deadline warning.
final List<AppleSdkRequirement> appleSdkRequirements = <AppleSdkRequirement>[
  AppleSdkRequirement(
    effectiveDate: DateTime.utc(2025, 4, 24),
    minXcodeMajor: 16,
    minSdkLabel: 'iOS 18 SDK',
  ),
  AppleSdkRequirement(
    effectiveDate: DateTime.utc(2026, 4, 28),
    minXcodeMajor: 26,
    minSdkLabel: 'iOS 26 SDK',
  ),
];
