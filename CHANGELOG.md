## 1.0.0

First shippable release. Two checks live:

### Xcode / SDK requirement check
- Reads the installed Xcode via `xcodebuild -version`.
- Detects beta vs release channel via `xcode-select -p` + Xcode's `LicenseInfo.plist` (`licenseType` field), with bundle-name heuristic fallback.
- Cross-references the installed Xcode major against a bundled table of Apple's App Store Connect Xcode/SDK deadlines.
- Beta Xcodes surface as **warn** with an explicit TestFlight (✅) vs App Store distribution (❌) split — reflecting Apple's actual policy that beta Xcodes are accepted for TestFlight but rejected at App Store review.
- Warns 90 days before an upcoming deadline the installed Xcode won't meet.

### Info.plist usage-descriptions check
- Parses `pubspec.lock` for every installed package (direct **and** transitive).
- Cross-references each against a bundled mapping of ~24 permission-requiring plugins → their required `Info.plist` keys, including federated plugin variants (e.g. `image_picker` + `image_picker_ios`).
- Reads `ios/Runner/Info.plist` via `plutil -convert json` (handles both XML and binary plists).
- Fails if a required key is missing OR present-but-empty.
- Skips gracefully when run outside a Flutter iOS project.

### CLI / reporter
- Multi-line detail rendering with proper indentation.
- Inline ✅ / ❌ markers per sub-outcome.
- Exit code `1` on any failure — safe as a CI gate.

## 0.1.0

- Initial scaffold. CLI entry point wired via `dart run ios_preflight`. No checks implemented yet.
