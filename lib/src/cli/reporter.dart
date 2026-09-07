import 'dart:io';

import '../checks/check.dart';

class Reporter {
  final Stdout _out;

  Reporter({Stdout? out}) : _out = out ?? stdout;

  void report(CheckResult result) {
    _out.writeln('${_iconFor(result.status)} ${result.title}');
    final detail = result.detail;
    if (detail != null) {
      for (final line in detail.split('\n')) {
        _out.writeln('   $line');
      }
    }
    final remediation = result.remediation;
    if (remediation != null) {
      final lines = remediation.split('\n');
      _out.writeln('   → ${lines.first}');
      for (final line in lines.skip(1)) {
        _out.writeln('     $line');
      }
    }
  }

  void summary(List<CheckResult> results) {
    _out.writeln('');
    if (results.isEmpty) {
      _out.writeln('No checks run.');
      return;
    }
    final passed = results.where((r) => r.status == CheckStatus.pass).length;
    final failed = results.where((r) => r.status == CheckStatus.fail).length;
    final warned = results.where((r) => r.status == CheckStatus.warn).length;
    final skipped = results.where((r) => r.status == CheckStatus.skip).length;

    final parts = <String>[];
    if (failed > 0) parts.add('$failed failed');
    if (warned > 0) parts.add('$warned ${warned == 1 ? 'warning' : 'warnings'}');
    if (passed > 0) parts.add('$passed passed');
    if (skipped > 0) parts.add('$skipped skipped');
    _out.writeln('${parts.join(', ')}.');
  }

  String _iconFor(CheckStatus status) {
    switch (status) {
      case CheckStatus.pass:
        return '✅';
      case CheckStatus.fail:
        return '❌';
      case CheckStatus.warn:
        return '⚠️ ';
      case CheckStatus.skip:
        return '⏭️ ';
    }
  }
}
