/// Parsed representation of `xcodebuild -version` output.
class XcodeVersion {
  final int major;
  final int minor;
  final int? patch;
  final String? build;
  final String raw;

  const XcodeVersion({
    required this.major,
    required this.minor,
    this.patch,
    this.build,
    required this.raw,
  });

  /// Parses the output of `xcodebuild -version`, which looks like:
  ///
  ///     Xcode 16.2
  ///     Build version 16C5032a
  ///
  /// Returns `null` if the input does not start with a recognizable
  /// `Xcode <major>[.<minor>[.<patch>]]` line.
  static XcodeVersion? tryParse(String output) {
    final lines = output.split('\n');
    if (lines.isEmpty) return null;
    final firstLine = lines.first.trim();
    final versionMatch =
        RegExp(r'^Xcode\s+(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(firstLine);
    if (versionMatch == null) return null;

    String? build;
    if (lines.length > 1) {
      final buildMatch =
          RegExp(r'^Build version\s+(\S+)').firstMatch(lines[1].trim());
      build = buildMatch?.group(1);
    }

    return XcodeVersion(
      major: int.parse(versionMatch.group(1)!),
      minor: int.tryParse(versionMatch.group(2) ?? '') ?? 0,
      patch: versionMatch.group(3) != null
          ? int.tryParse(versionMatch.group(3)!)
          : null,
      build: build,
      raw: firstLine,
    );
  }

  String get display {
    final buf = StringBuffer('$major.$minor');
    if (patch != null) buf.write('.$patch');
    return buf.toString();
  }

  @override
  String toString() => raw;
}

/// Distribution channel of the installed Xcode. App Store Connect enforces
/// different rules per channel: only `release` Xcodes are accepted for App
/// Store review submissions; `beta` Xcodes are accepted for TestFlight only
/// and Apple actively retires older betas.
enum XcodeChannel { release, beta, unknown }

/// A snapshot of the Xcode discovered on this machine — the parsed version
/// plus the distribution channel and the bundle path we resolved it from.
///
/// Kept separate from [XcodeVersion] so pure version parsing has no
/// dependency on filesystem/process probing.
class XcodeInstallation {
  final XcodeVersion version;
  final XcodeChannel channel;
  final String? bundlePath;

  const XcodeInstallation({
    required this.version,
    required this.channel,
    this.bundlePath,
  });
}
