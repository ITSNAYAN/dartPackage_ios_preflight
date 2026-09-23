import 'dart:io';

/// Result of inspecting a candidate Flutter project root.
sealed class ProjectRoot {
  const ProjectRoot();
}

/// Every expected file was found.
class FlutterProject extends ProjectRoot {
  final String rootPath;
  final String pubspecLockPath;
  final String infoPlistPath;
  final String podfilePath;
  final String pbxprojPath;

  const FlutterProject({
    required this.rootPath,
    required this.pubspecLockPath,
    required this.infoPlistPath,
    required this.podfilePath,
    required this.pbxprojPath,
  });
}

/// The directory isn't a Flutter iOS project; the caller should skip.
class NotAFlutterIosProject extends ProjectRoot {
  final String reason;
  const NotAFlutterIosProject(this.reason);
}

/// Inspects [directoryPath] and returns whether it looks like a Flutter iOS
/// project ready to be preflight-checked.
///
/// Requires all of: `pubspec.yaml`, `pubspec.lock`, `ios/Runner/Info.plist`.
/// Missing `pubspec.lock` in particular means `flutter pub get` hasn't been
/// run — no reliable install picture, so we skip rather than false-fail.
ProjectRoot inspectProjectRoot(String directoryPath) {
  final pubspecYaml = '$directoryPath/pubspec.yaml';
  final pubspecLock = '$directoryPath/pubspec.lock';
  final infoPlist = '$directoryPath/ios/Runner/Info.plist';
  final podfile = '$directoryPath/ios/Podfile';
  final pbxproj = '$directoryPath/ios/Runner.xcodeproj/project.pbxproj';

  if (!File(pubspecYaml).existsSync()) {
    return const NotAFlutterIosProject(
      'pubspec.yaml not found — not a Dart/Flutter project directory.',
    );
  }
  if (!File(pubspecLock).existsSync()) {
    return const NotAFlutterIosProject(
      'pubspec.lock not found — run `flutter pub get` first.',
    );
  }
  if (!File(infoPlist).existsSync()) {
    return const NotAFlutterIosProject(
      'ios/Runner/Info.plist not found — not a Flutter iOS project '
      '(or the iOS platform folder is missing).',
    );
  }

  return FlutterProject(
    rootPath: directoryPath,
    pubspecLockPath: pubspecLock,
    infoPlistPath: infoPlist,
    podfilePath: podfile,
    pbxprojPath: pbxproj,
  );
}
