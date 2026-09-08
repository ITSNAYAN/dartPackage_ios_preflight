import 'package:yaml/yaml.dart';

/// One resolved package entry from `pubspec.lock`.
class InstalledPackage {
  /// Package name (map key under `packages:` in the lock file).
  final String name;

  /// Resolved pinned version (e.g. `"1.1.2"`).
  final String version;

  /// `"direct main"`, `"direct dev"`, or `"transitive"`.
  final String dependency;

  const InstalledPackage({
    required this.name,
    required this.version,
    required this.dependency,
  });

  @override
  String toString() => '$name $version ($dependency)';
}

/// Parses a `pubspec.lock` YAML document and returns every resolved package.
///
/// Includes both direct and transitive dependencies — critical because a
/// transitive plugin can still trigger iOS permission dialogs the developer
/// never explicitly imported.
///
/// Returns an empty list if the document is malformed or has no `packages:`
/// map (rather than throwing) — the check treats this as "no known
/// permission-requiring plugins found" and passes with a note.
List<InstalledPackage> parsePubspecLock(String yamlText) {
  final YamlNode doc;
  try {
    doc = loadYamlNode(yamlText);
  } on YamlException {
    return const [];
  }

  if (doc is! YamlMap) return const [];
  final packages = doc['packages'];
  if (packages is! YamlMap) return const [];

  final result = <InstalledPackage>[];
  packages.nodes.forEach((key, value) {
    if (key is! YamlScalar) return;
    final name = key.value;
    if (name is! String) return;
    if (value is! YamlMap) return;

    final version = value['version'];
    final dependency = value['dependency'];
    if (version is! String) return;

    result.add(InstalledPackage(
      name: name,
      version: version,
      dependency: dependency is String ? dependency : 'unknown',
    ));
  });

  return result;
}
