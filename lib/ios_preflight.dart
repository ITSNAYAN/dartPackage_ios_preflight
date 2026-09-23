/// Programmatic entry point for the ios_preflight CLI.
///
/// Most users should invoke this package via `dart run ios_preflight`.
library;

export 'src/checks/check.dart';
// hide the duplicate typedefs — they're already exported by info_plist_check.
export 'src/checks/deployment_target_check.dart'
    hide ProjectRootProbe, FileReader;
export 'src/checks/info_plist_check.dart';
export 'src/checks/signing_expiry_check.dart'
    hide ProjectRootProbe, FileReader, Clock;
export 'src/checks/xcode_sdk_check.dart';
export 'src/data/apple_sdk_requirements.dart';
export 'src/data/flutter_ios_minimums.dart';
export 'src/data/permission_plugins.dart';
export 'src/ios_preflight_base.dart';
export 'src/util/info_plist_reader.dart';
export 'src/util/mobileprovision_reader.dart';
export 'src/util/pbxproj_reader.dart';
export 'src/util/podfile_reader.dart';
export 'src/util/project_root.dart';
export 'src/util/signing_settings_reader.dart';
export 'src/util/pubspec_lock_reader.dart';
export 'src/util/xcode_version.dart';
