enum CheckStatus { pass, warn, fail, skip }

class CheckResult {
  final CheckStatus status;
  final String title;
  final String? detail;
  final String? remediation;

  const CheckResult({
    required this.status,
    required this.title,
    this.detail,
    this.remediation,
  });

  const CheckResult.pass(this.title, {this.detail})
      : status = CheckStatus.pass,
        remediation = null;

  const CheckResult.warn(this.title, {this.detail, this.remediation})
      : status = CheckStatus.warn;

  const CheckResult.fail(this.title, {this.detail, this.remediation})
      : status = CheckStatus.fail;

  const CheckResult.skip(this.title, {this.detail})
      : status = CheckStatus.skip,
        remediation = null;
}

abstract class Check {
  String get id;
  String get title;
  Future<CheckResult> run();
}
