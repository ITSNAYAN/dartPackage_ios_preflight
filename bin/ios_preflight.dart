import 'dart:io';

import 'package:ios_preflight/src/cli/entry.dart';

Future<void> main(List<String> args) async {
  final code = await runCli(args);
  exit(code);
}
