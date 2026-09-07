import 'dart:io';

import '../checks/check.dart';
import '../checks/xcode_sdk_check.dart';
import '../ios_preflight_base.dart';
import 'reporter.dart';
import 'runner.dart';

Future<int> runCli(List<String> args) async {
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('ios_preflight $iosPreflightVersion');
    return 0;
  }
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_helpText);
    return 0;
  }

  final reporter = Reporter();
  final runner = PreflightRunner(
    checks: <Check>[
      XcodeSdkCheck(),
    ],
    reporter: reporter,
  );

  return runner.run();
}

const _helpText = '''
ios_preflight — validate iOS submission readiness before you build.

Usage:
  dart run ios_preflight             Run all checks
  dart run ios_preflight --help      Show this help
  dart run ios_preflight --version   Show version

Exit codes:
  0  All checks passed
  1  One or more checks failed
  2  Tool error (invalid project, etc.)
''';
