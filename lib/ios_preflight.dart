/// Programmatic entry point for the ios_preflight CLI.
///
/// Most users should invoke this package via `dart run ios_preflight`.
library;

export 'src/checks/check.dart';
export 'src/checks/xcode_sdk_check.dart';
export 'src/data/apple_sdk_requirements.dart';
export 'src/ios_preflight_base.dart';
export 'src/util/xcode_version.dart';
