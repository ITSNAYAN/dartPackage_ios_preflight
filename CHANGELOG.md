## 1.2.0

Adds the fourth check: **Provisioning profile expiry**.

### Provisioning profile expiry check
- Lists every `.mobileprovision` file in `~/Library/MobileDevice/Provisioning Profiles/`.
- Decodes each via `security cms -D -i` + `plutil -convert json`, extracting `Name`, `ExpirationDate`, and the profile's `application-identifier` entitlement.
- Filters to profiles that match the app's own bundle identifier (parsed from `PRODUCT_BUNDLE_IDENTIFIER` in `project.pbxproj`, skipping `*Tests` entries). Wildcard profiles (`com.example.*`) are matched correctly.
- Decision tree (top wins):
  1. Not a Flutter iOS project → **skip**
  2. Xcode automatic signing detected (`CODE_SIGN_STYLE = Automatic`) → **skip** (Xcode manages profiles)
  3. No matching profile on disk → **skip** (likely a CI environment or fresh checkout)
  4. Any matching profile expired → **fail**
  5. Any matching profile expiring within 30 days → **warn**
  6. All valid + beyond warn window → **pass**
- Wildcard app-identifier matching so `com.example.*` correctly covers `com.example.myapp`.

### Note on certificate expiry
This release ships **provisioning profile expiry only**. Code signing certificate expiry — the other half of check #6 in the plan — is deferred to a follow-up release. It requires nested shell-outs (`security find-certificate` + `openssl x509 -enddate`) which are fragile enough to deserve their own isolated implementation and test surface.

## 1.1.0

Adds the third check: **Deployment target consistency**.

### Deployment target consistency check
- Reads `ios/Podfile` for the `platform :ios, 'X.Y'` line (respects single- and double-quoted variants; ignores commented-out lines).
- Reads every `IPHONEOS_DEPLOYMENT_TARGET` entry from `ios/Runner.xcodeproj/project.pbxproj`, pairing each with its build configuration name (Debug / Release / Profile).
- Cross-references against a bundled table of Flutter's own iOS deployment target policy — updated via community PRs, same principle as the Xcode/SDK table.
- Decision tree (top wins):
  1. Podfile missing/unparseable → **skip** (nothing to compare)
  2. pbxproj missing/unparseable → **fail** (broken project structure)
  3. Any target below Flutter's known minimum → **fail** (build will fail)
  4. Podfile ≠ pbxproj → **fail** (guaranteed CocoaPods errors mid-build)
  5. pbxproj configs disagree with each other → **warn** (works locally, breaks in CI)
  6. All consistent + above floor → **pass**
- Best-effort Flutter version probe via `flutter --version`; sub-check silently degrades if Flutter isn't installed.

### Other
- Extended `FlutterProject` sealed variant with `podfilePath` + `pbxprojPath`.
- Added public exports for `parsePodfilePlatform`, `parseDeploymentTargets`, `flutterIosMinimums`, `DeploymentTargetCheck`.

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
