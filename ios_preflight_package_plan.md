# iOS Preflight — Flutter Package Plan

*A dev-dependency CLI that validates a Flutter project's iOS readiness before you ever open Xcode or hit "Distribute."*

---

## 1. Background & Motivation

The idea originated from a real, specific frustration: a Flutter project archives successfully in Xcode (including Xcode betas), but fails at the **App Store Connect distribution step** with an SDK compatibility error — after the developer has already spent time building, archiving, and uploading.

This isn't a one-off annoyance. Apple has a documented history of raising its minimum SDK/Xcode requirement roughly once a year, always announced months in advance on its own "Upcoming Requirements" page:

| Effective Date | Requirement |
|---|---|
| April 24, 2025 | Xcode 16+ / iOS 18 SDK+ |
| April 28, 2026 | Xcode 26+ / iOS 26 SDK+ (also iPadOS 26, tvOS 26, visionOS 26, watchOS 26) |

Because this recurs predictably and catches developers off guard every cycle, it's a strong signal that a **preflight validation tool** has lasting value — not just a one-time fix.

## 2. The Gap in the Existing Ecosystem

| Tool | What it covers | What it misses |
|---|---|---|
| `flutter doctor` | Local dev environment (SDK install, licenses, connected devices) | Nothing project-specific to iOS submission readiness |
| Fastlane (`precheck`, `match`) | App Store *metadata* & compliance rules, code signing automation | Doesn't validate the Flutter/iOS project's internal config consistency |
| Xcode itself | Build-time errors, some archive-time validation | Only surfaces problems *after* a full build; SDK-policy rejection often only appears at the **upload/distribute** step, wasting the whole build cycle |

**Conclusion:** no existing tool answers "is my Flutter project's iOS configuration internally consistent and currently submittable?" *before* a developer invests time in a build. That's the gap this package fills.

## 3. Problems This Package Solves

1. **Deployment target mismatches** — `ios/Podfile` and `project.pbxproj` disagreeing with each other, or falling below Flutter's/Apple's current minimum, causing confusing CocoaPods errors mid-build.

2. **Missing `Info.plist` usage-description keys** — permission-requiring plugins (camera, location, photos, etc.) detected via `pubspec.lock` with no matching `NSCameraUsageDescription`-style key present in `Info.plist`. This is one of the single most common real-world App Store rejection reasons.

3. **Missing or outdated privacy manifest** (`PrivacyInfo.xcprivacy`) — required when the project (directly or via a plugin) touches Apple's "required reason" APIs. Enforcement has been tightening.

4. **CocoaPods lock file conflicts** — stale `Podfile.lock`, duplicate or mismatched pod versions across dependencies.

5. **Apple Silicon simulator architecture issues** — missing arm64 simulator runtimes, or leftover `EXCLUDED_ARCHS` overrides in the Podfile that silently break "Run" on newer Macs.

6. **Signing certificate / provisioning profile expiry** — expired or soon-to-expire identities/profiles that only surface as a cryptic failure at archive time.

7. **Xcode / SDK submission deadline mismatch** — the founding use case: local Xcode (including betas) archives fine, but doesn't meet Apple's *current* minimum SDK requirement for App Store Connect uploads — discovered only at the distribute step.

## 4. Design Principles

- **Don't reinvent CocoaPods/Xcode's own resolution logic.** Where possible, shell out to the real tools (`xcodebuild`, `pod install`, `xcrun`, `security`) and parse their output into a clean report, rather than re-implementing dependency resolution.
- **Distribute as a `dev_dependency`, not a global CLI.** This matches the proven pattern of `flutter_launcher_icons`, `flutter_native_splash`, and `pigeon` — version-pinned per project, identical behavior for every teammate and CI runner, no separate global-install step to keep in sync.
- **Report by default; auto-fix only when provably safe.** A wrong auto-fix that silently "succeeds" erodes trust faster than a clear failure. Auto-fixing is reserved for reversible, low-risk actions (e.g., scaffolding a placeholder Info.plist string with a `TODO` comment).
- **CI-friendly output.** Non-zero exit code on any failed check, so the tool can be wired into a build pipeline as a hard gate before `flutter build ipa` runs — not just something a developer remembers to run manually.
- **Treat compatibility data as a living resource.** The permission→Info.plist mapping and the Apple SDK-deadline table are data, not code. They need ongoing maintenance (ideally via community PRs), same as how CocoaPods specs or Flutter's own plugin registry are kept current.

## 5. How Each Check Works (Technical Sketch)

| # | Check | Mechanism |
|---|---|---|
| 1 | Deployment target consistency | Read `IPHONEOS_DEPLOYMENT_TARGET` from `project.pbxproj` and `platform :ios` from `Podfile`; flag disagreement. Optionally run `pod install --repo-update` in a subprocess and parse CocoaPods' own deployment-target warnings. |
| 2 | Info.plist usage descriptions | Parse `pubspec.lock` for known permission-requiring packages against a bundled JSON mapping (package → required plist keys). Cross-check `ios/Runner/Info.plist` for missing or empty-string keys. For dynamic packages (e.g. `permission_handler`), grep Dart source for `Permission.x` calls as a best-effort heuristic flagged for manual confirmation. |
| 3 | Privacy manifest | Check for presence of `PrivacyInfo.xcprivacy` in the Runner target; cross-reference installed pod versions against known "required reason API" usage. |
| 4 | Podfile.lock conflicts | Compare current lock file against a fresh dry-run install in a scratch copy; flag stale locks or known-bad version combinations via a small compatibility table. |
| 5 | Simulator architecture | `xcrun simctl list runtimes` to confirm arm64 availability; scan Podfile `post_install` hooks for legacy `EXCLUDED_ARCHS` overrides. |
| 6 | Signing / provisioning expiry | `security find-identity -v -p codesigning` for certificate expiry; decode `.mobileprovision` files via `security cms -D -i <file>` for profile expiration dates. |
| 7 | Xcode / SDK deadline | `xcodebuild -version` compared against a bundled table mirroring Apple's official upcoming-requirements page. Warns **ahead of** an upcoming deadline, not just after it's passed. |

## 6. Example Output

```
$ dart run ios_preflight check

✅ Deployment target consistent (iOS 13.0)
❌ Missing NSCameraUsageDescription (required by image_picker ^1.1.2)
⚠️  PrivacyInfo.xcprivacy missing (2 pods flagged: app_tracking_transparency, sqflite)
✅ Provisioning profile valid until 2027-01-14
❌ Xcode 16.2 installed — Apple requires Xcode 26+ for submissions from 2026-04-28

2 failed, 1 warning, 2 passed.
```

Exit code `1` if any check fails — safe to use as a CI gate.

## 7. Roadmap

### ✅ v1.0 — Minimum viable, ship first *(shipped)*
Focus on the two checks with the best effort-to-payoff ratio:
- ✅ **Info.plist usage-description validation** (#2) — highest real-world rejection-rate payoff, no external tool-shelling required. *Shipped in 1.0.0 with a bundled mapping of 24+ permission-requiring plugins (federated variants included), transitive-dep coverage via `pubspec.lock`, and `plutil -convert json` for both XML and binary plists.*
- ✅ **Xcode / SDK deadline check** (#7) — simple version comparison against a bundled table; directly solves the founding use case. *Shipped in 1.0.0 with beta-vs-release detection (via `LicenseInfo.plist`'s `licenseType`), a 90-day upcoming-deadline warn window, and an explicit TestFlight-accepted / App-Store-rejected split for beta Xcodes.*

Goal: get a small, reliable tool in front of 5–10 real users and gather feedback before expanding scope.

### v1.1 — First iteration, based on early feedback *(in progress)*
- ✅ **Deployment target consistency check** (#1) — cheap to add, very common source of confusion. *Shipped in 1.1.0. Cross-references `ios/Podfile`, every `IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj` (paired with its build-config name), and a bundled Flutter iOS-floor table. Precedence: below-Flutter-floor fails, Podfile ≠ pbxproj fails, pbxproj configs disagreeing with each other warns.*
- ⏳ **Signing certificate / provisioning profile expiry check** (#6) — high pain when it hits, straightforward to implement.

### v1.2+ — Later, only if v1.1 gains traction
- Privacy manifest check (#3)
- Podfile.lock conflict detection (#4)
- Apple Silicon simulator architecture check (#5)

These are deferred because they either require a community-maintained compatibility table (higher ongoing maintenance burden) or address lower-frequency pain points — better to earn adoption first and let real GitHub issues guide priority.

## 8. Key Risks & Honest Caveats

- **This is a preflight linter, not a guarantee.** It cannot replace Apple's own server-side binary validation during upload/processing — some things simply aren't checkable locally.
- **Data tables require ongoing maintenance.** The permission-mapping JSON and Apple's SDK-deadline table will go stale without upkeep. Silently wrong data is worse than the tool not existing — plan for community contributions or a regular update cadence.
- **Scope creep is the main failure mode for this kind of tool.** Resist building all seven checks at once; a smaller, reliable tool beats a large, half-working one.

## 9. Validation Strategy (Before/While Building)

- Search pub.dev and GitHub for existing overlap before committing further effort.
- Post the idea (even just this README) as a public repo or pub.dev placeholder, and share it in the Flutter Discord / r/FlutterDev to gauge real interest cheaply.
- Let actual GitHub issues — not upfront guessing — decide what gets built after v1.0.

---

*Distribution model: published as a `dev_dependency` in `pubspec.yaml`, invoked via `dart run ios_preflight check`, so it runs identically for every developer and CI runner on a project.*
