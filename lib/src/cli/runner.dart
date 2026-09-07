import '../checks/check.dart';
import 'reporter.dart';

class PreflightRunner {
  final List<Check> checks;
  final Reporter reporter;

  const PreflightRunner({required this.checks, required this.reporter});

  Future<int> run() async {
    final results = <CheckResult>[];
    for (final check in checks) {
      final result = await check.run();
      reporter.report(result);
      results.add(result);
    }
    reporter.summary(results);

    final anyFailed = results.any((r) => r.status == CheckStatus.fail);
    return anyFailed ? 1 : 0;
  }
}
