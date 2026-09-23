import 'dart:io';

import '../data/flutter_ios_minimums.dart';
import '../util/pbxproj_reader.dart';
import '../util/podfile_reader.dart';
import '../util/project_root.dart';
import 'check.dart';

/// Returns the project root to inspect. Defaults to `Directory.current.path`.
typedef ProjectRootProbe = String Function();

/// Reads a file's contents as a string. Injected so tests can supply
/// in-memory fixtures without touching the disk.
typedef FileReader = Future<String> Function(String path);

/// Returns the installed Flutter version string (e.g. `"3.24.0"`), or `null`
/// if Flutter isn't installed / can't be probed. Injected so tests supply a
/// fixed version without shelling out.
typedef FlutterVersionProbe = Future<String?> Function();

/// Verifies that `ios/Podfile` and every `IPHONEOS_DEPLOYMENT_TARGET` line
/// in `ios/Runner.xcodeproj/project.pbxproj` agree, and that all of them
/// are at or above Flutter's current iOS floor.
///
/// Precedence (top wins):
///   1. Podfile missing/unparseable → skip with note
///   2. pbxproj missing/unparseable → fail (broken project structure)
///   3. Any target below Flutter's known minimum → fail
///   4. Podfile target ≠ pbxproj targets → fail
///   5. pbxproj configs disagree with each other → warn
///   6. All consistent + above floor → pass
class DeploymentTargetCheck extends Check {
  final ProjectRootProbe _rootProbe;
  final FileReader _readFile;
  final FlutterVersionProbe _flutterVersion;
  final List<FlutterIosMinimum> _flutterMinimums;

  DeploymentTargetCheck({
    ProjectRootProbe? projectRoot,
    FileReader? readFile,
    FlutterVersionProbe? flutterVersion,
    List<FlutterIosMinimum>? flutterMinimums,
  })  : _rootProbe = projectRoot ?? _defaultRoot,
        _readFile = readFile ?? _defaultReadFile,
        _flutterVersion = flutterVersion ?? _defaultFlutterVersion,
        _flutterMinimums = flutterMinimums ?? flutterIosMinimums;

  @override
  String get id => 'deployment_target';

  @override
  String get title => 'Deployment target consistency';

  @override
  Future<CheckResult> run() async {
    final project = inspectProjectRoot(_rootProbe());
    if (project is NotAFlutterIosProject) {
      return CheckResult.skip(title, detail: '${project.reason} Skipped.');
    }
    project as FlutterProject;

    // 1. Read Podfile
    String? podfilePlatform;
    if (File(project.podfilePath).existsSync()) {
      try {
        final podfileText = await _readFile(project.podfilePath);
        podfilePlatform = parsePodfilePlatform(podfileText);
      } on FileSystemException {
        podfilePlatform = null;
      }
    }
    if (podfilePlatform == null) {
      return CheckResult.skip(
        title,
        detail: 'ios/Podfile has no `platform :ios, ...` line (or file is '
            'missing/commented). Skipping deployment target consistency.',
      );
    }

    // 2. Read pbxproj
    if (!File(project.pbxprojPath).existsSync()) {
      return CheckResult.fail(
        title,
        detail: 'ios/Runner.xcodeproj/project.pbxproj not found — project '
            'structure is broken.',
      );
    }
    final String pbxprojText;
    try {
      pbxprojText = await _readFile(project.pbxprojPath);
    } on FileSystemException catch (e) {
      return CheckResult.fail(
        title,
        detail: 'Could not read project.pbxproj: ${e.message}',
      );
    }
    final pbxHits = parseDeploymentTargets(pbxprojText);
    if (pbxHits.isEmpty) {
      return CheckResult.fail(
        title,
        detail:
            'project.pbxproj contains no IPHONEOS_DEPLOYMENT_TARGET entries.',
        remediation:
            'Open ios/Runner.xcodeproj in Xcode → project settings → set the '
            'Deployment Target for every build configuration.',
      );
    }

    // 3. Determine Flutter's current minimum (best-effort — skip that
    //    sub-check if Flutter isn't installed).
    final flutterVersion = await _flutterVersion();
    final flutterFloor =
        flutterVersion != null ? _floorFor(flutterVersion) : null;

    // 4. Fail if any target < Flutter floor.
    if (flutterFloor != null) {
      final belowFloor = <String>[];
      if (_versionLessThan(podfilePlatform, flutterFloor.minIosTarget)) {
        belowFloor.add('Podfile → iOS $podfilePlatform');
      }
      for (final hit in pbxHits) {
        if (_versionLessThan(hit.version, flutterFloor.minIosTarget)) {
          belowFloor.add(
            'project.pbxproj (${hit.configName ?? 'unnamed'}) → iOS ${hit.version}',
          );
        }
      }
      if (belowFloor.isNotEmpty) {
        return CheckResult.fail(
          title,
          detail: 'Deployment target below Flutter '
              '$flutterVersion\'s minimum (iOS '
              '${flutterFloor.minIosTarget}, since Flutter '
              '${flutterFloor.sinceFlutter}):\n'
              '${belowFloor.map((s) => '  ❌ $s').join('\n')}',
          remediation:
              'Update all deployment targets to at least iOS '
              '${flutterFloor.minIosTarget}.',
        );
      }
    }

    // 5. Fail if Podfile disagrees with pbxproj.
    final pbxVersions = pbxHits.map((h) => h.version).toSet();
    if (!pbxVersions.contains(podfilePlatform)) {
      final lines = <String>[
        '  ❌ ios/Podfile → iOS $podfilePlatform',
        ...pbxHits.map((h) =>
            '  ❌ project.pbxproj (${h.configName ?? 'unnamed'}) → iOS ${h.version}'),
      ];
      return CheckResult.fail(
        title,
        detail:
            'Podfile and Xcode project disagree on the iOS deployment target:\n'
            '${lines.join('\n')}',
        remediation:
            'Reconcile by either editing ios/Podfile to `platform :ios, '
            '\'${pbxVersions.first}\'` or bumping IPHONEOS_DEPLOYMENT_TARGET '
            'in ios/Runner.xcodeproj/project.pbxproj to $podfilePlatform across '
            'every build configuration.',
      );
    }

    // 6. Warn if pbxproj configs disagree with each other.
    if (pbxVersions.length > 1) {
      final lines = pbxHits.map((h) =>
          '  ⚠️  ${h.configName ?? 'unnamed'} → iOS ${h.version}');
      return CheckResult.warn(
        title,
        detail: 'Xcode build configurations disagree on the deployment '
            'target:\n${lines.join('\n')}',
        remediation:
            'Aligns builds locally, but Release-only mismatches cause CI '
            'failures. Set IPHONEOS_DEPLOYMENT_TARGET to the same value '
            '($podfilePlatform) across every build configuration.',
      );
    }

    // 7. Pass.
    final floorNote = flutterFloor != null
        ? ' and Flutter\'s current minimum (iOS ${flutterFloor.minIosTarget} '
            'since Flutter ${flutterFloor.sinceFlutter})'
        : '';
    return CheckResult.pass(
      title,
      detail: 'iOS $podfilePlatform across Podfile, all pbxproj '
          'configurations$floorNote.',
    );
  }

  /// Returns the most-recent Flutter iOS minimum whose `sinceFlutter` is
  /// ≤ [installedFlutterVersion]. Returns `null` if the table has no
  /// entry that low.
  FlutterIosMinimum? _floorFor(String installedFlutterVersion) {
    FlutterIosMinimum? floor;
    final sorted = [..._flutterMinimums]
      ..sort((a, b) => a.sinceFlutter.compareTo(b.sinceFlutter));
    for (final entry in sorted) {
      if (_versionLessOrEqual(entry.sinceFlutter, installedFlutterVersion)) {
        floor = entry;
      }
    }
    return floor;
  }
}

String _defaultRoot() => Directory.current.path;

Future<String> _defaultReadFile(String path) => File(path).readAsString();

Future<String?> _defaultFlutterVersion() async {
  try {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode != 0) return null;
    final stdout = result.stdout;
    if (stdout is! String) return null;
    // First line: `Flutter 3.24.0 • channel stable • ...`
    final match =
        RegExp(r'^Flutter\s+([\d.]+)').firstMatch(stdout.split('\n').first);
    return match?.group(1);
  } on ProcessException {
    return null;
  }
}

/// Compares two dotted numeric versions component-wise (e.g. "12.0" vs "13.0").
/// Missing components are treated as 0.
bool _versionLessThan(String a, String b) => _compareVersions(a, b) < 0;

bool _versionLessOrEqual(String a, String b) => _compareVersions(a, b) <= 0;

int _compareVersions(String a, String b) {
  final aParts = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final bParts = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < len; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av < bv) return -1;
    if (av > bv) return 1;
  }
  return 0;
}
