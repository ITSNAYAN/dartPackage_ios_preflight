import 'dart:io';

import '../data/permission_plugins.dart';
import '../util/info_plist_reader.dart';
import '../util/project_root.dart';
import '../util/pubspec_lock_reader.dart';
import 'check.dart';

/// Returns the project root to inspect. Defaults to `Directory.current.path`.
typedef ProjectRootProbe = String Function();

/// Reads a file's contents as a string. Injected so tests can supply
/// in-memory fixtures without touching the disk.
typedef FileReader = Future<String> Function(String path);

/// Verifies that every `Info.plist` usage-description key required by an
/// installed permission-requiring plugin is (a) present and (b) non-empty.
///
/// Skips (rather than fails) when run outside a Flutter iOS project — this
/// keeps the check safe to always register in the runner: harmless in
/// non-Flutter dirs, actively useful in Flutter ones.
class InfoPlistCheck extends Check {
  final ProjectRootProbe _rootProbe;
  final FileReader _readFile;
  final PlutilRunner? _plutil;
  final Map<String, List<String>> _mapping;

  InfoPlistCheck({
    ProjectRootProbe? projectRoot,
    FileReader? readFile,
    PlutilRunner? plutil,
    Map<String, List<String>>? mapping,
  })  : _rootProbe = projectRoot ?? _defaultRoot,
        _readFile = readFile ?? _defaultReadFile,
        _plutil = plutil,
        _mapping = mapping ?? permissionPlugins;

  @override
  String get id => 'info_plist';

  @override
  String get title => 'Info.plist usage descriptions';

  @override
  Future<CheckResult> run() async {
    final rootPath = _rootProbe();
    final project = inspectProjectRoot(rootPath);

    if (project is NotAFlutterIosProject) {
      return CheckResult.skip(title, detail: '${project.reason} Skipped.');
    }
    project as FlutterProject;

    // 1. Read pubspec.lock — installed packages.
    final String lockText;
    try {
      lockText = await _readFile(project.pubspecLockPath);
    } on FileSystemException catch (e) {
      return CheckResult.fail(
        title,
        detail: 'Could not read pubspec.lock: ${e.message}',
      );
    }
    final installed = parsePubspecLock(lockText);

    // 2. Cross-reference with the mapping → expected keys + contributing pkgs.
    final expected = <String, List<String>>{};
    final dynamicPlugins = <String>[];
    for (final pkg in installed) {
      if (!_mapping.containsKey(pkg.name)) continue;
      final required = _mapping[pkg.name]!;
      if (required.isEmpty) {
        dynamicPlugins.add('${pkg.name} ${pkg.version}');
        continue;
      }
      for (final key in required) {
        expected.putIfAbsent(key, () => []).add('${pkg.name} ${pkg.version}');
      }
    }

    // 3. Read what's actually in Info.plist.
    final plistKeys = await readInfoPlist(
      project.infoPlistPath,
      runner: _plutil,
    );

    // 4. Diff. Missing = expected key that's absent OR present-but-empty.
    final missing = <String, List<String>>{};
    for (final entry in expected.entries) {
      final value = plistKeys[entry.key];
      if (value == null || value.trim().isEmpty) {
        missing[entry.key] = entry.value;
      }
    }

    // 5. Report.
    if (expected.isEmpty && dynamicPlugins.isEmpty) {
      return CheckResult.pass(
        title,
        detail: 'No known permission-requiring plugins detected in '
            'pubspec.lock.',
      );
    }

    if (missing.isEmpty) {
      final detailBuf = StringBuffer(
        'All ${expected.length} required usage description '
        '${expected.length == 1 ? 'key is' : 'keys are'} present.',
      );
      if (dynamicPlugins.isNotEmpty) {
        detailBuf
          ..write('\n  ⚠️  Manually verify Info.plist keys for dynamic plugin')
          ..write(dynamicPlugins.length == 1 ? ': ' : 's: ')
          ..write(dynamicPlugins.join(', '));
      }
      return CheckResult.pass(title, detail: detailBuf.toString());
    }

    return CheckResult.fail(
      title,
      detail: _formatMissingDetail(missing, dynamicPlugins),
      remediation:
          'Add each missing key to ios/Runner/Info.plist with a non-empty '
          '<string> value explaining the purpose the App Store review team '
          'will see when the permission dialog appears.',
    );
  }

  String _formatMissingDetail(
    Map<String, List<String>> missing,
    List<String> dynamicPlugins,
  ) {
    final buf = StringBuffer();
    buf.write(missing.length == 1
        ? '1 missing usage description key:'
        : '${missing.length} missing usage description keys:');
    for (final entry in missing.entries) {
      buf.write('\n  ❌ ${entry.key}');
      buf.write('\n     Required by: ${entry.value.join(', ')}');
    }
    if (dynamicPlugins.isNotEmpty) {
      buf.write('\n  ⚠️  Also manually verify Info.plist keys for dynamic '
          'plugin${dynamicPlugins.length == 1 ? '' : 's'}: '
          '${dynamicPlugins.join(', ')}');
    }
    return buf.toString();
  }
}

String _defaultRoot() => Directory.current.path;

Future<String> _defaultReadFile(String path) => File(path).readAsString();
