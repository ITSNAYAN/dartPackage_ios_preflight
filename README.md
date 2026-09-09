# ios_preflight

A Flutter dev-dependency CLI that validates a project's iOS submission readiness **before** you build or open Xcode.

Catches the two most common reasons an iOS build fails at the App Store Connect upload step:

- **Xcode / SDK below Apple's current minimum** (or a *beta* Xcode being used for App Store distribution — which Apple rejects at review)
- **Missing `Info.plist` usage descriptions** for permission-requiring plugins detected in `pubspec.lock` (camera, photos, location, contacts, Bluetooth, microphone, motion, NFC, biometrics, …)

Runs in seconds. Zero setup beyond `flutter pub get`.

## Install

Add as a dev-dependency:

```yaml
dev_dependencies:
  ios_preflight: ^1.0.0
```

Then:

```sh
flutter pub get
dart run ios_preflight
```

## Example output

```
⚠️  App Store Connect upload — Xcode / SDK requirement
   Xcode 27.0 is a beta build.
     ✅ TestFlight: uploads accepted (while this beta is still current — Apple retires older betas as new ones ship)
     ❌ App Store distribution: will be rejected (Apple requires a Release Candidate or GM build for review submissions)
   → For App Store submissions, install the latest released Xcode from the Mac App Store or an RC from developer.apple.com/download, then run: sudo xcode-select --switch /Applications/Xcode.app
❌ Info.plist usage descriptions
   2 missing usage description keys:
     ❌ NSPhotoLibraryUsageDescription
        Required by: image_picker 1.1.2
     ❌ NSLocationWhenInUseUsageDescription
        Required by: geolocator 10.1.0
   → Add each missing key to ios/Runner/Info.plist with a non-empty <string> value explaining the purpose the App Store review team will see when the permission dialog appears.

1 failed, 1 warning.
```

Exit code `1` if any check fails — safe to use as a CI gate before `flutter build ipa`.

## What each check does

### 1. Xcode / SDK requirement

- Runs `xcodebuild -version` to detect the installed Xcode major.
- Detects **beta vs release** via `xcode-select -p` + Apple's own `LicenseInfo.plist` field. A beta Xcode surfaces as a **warn** (not fail) because TestFlight uploads still work, but App Store review will reject.
- Cross-references against a bundled table of Apple's App Store Connect Xcode/SDK deadlines (mirrored from [Apple's Upcoming Requirements page](https://developer.apple.com/news/upcoming-requirements/)).
- Warns 90 days before an upcoming deadline you won't meet.

### 2. Info.plist usage descriptions

- Parses `pubspec.lock` (direct **and** transitive deps) — critical because a transitive plugin can still trigger iOS permission dialogs you never explicitly imported.
- Cross-references each installed package against a bundled mapping of **plugin → required Info.plist keys** (24+ common plugins seeded).
- Parses `ios/Runner/Info.plist` via `plutil -convert json` (handles both XML and binary plists).
- Fails if a required key is missing OR present-but-empty (Apple still rejects empty purpose strings).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | All checks passed |
| `1` | One or more checks failed |
| `2` | Tool error (invalid project, etc.) |

## Roadmap

Per the [package plan](ios_preflight_package_plan.md):

- **v1.1** — Deployment target consistency (`Podfile` vs `project.pbxproj`), provisioning profile expiry, dynamic `permission_handler` source-scan
- **v1.2+** — Privacy manifest (`PrivacyInfo.xcprivacy`), `Podfile.lock` conflicts, Apple Silicon simulator arch

## Contributing

The permission plugin mapping ([`lib/src/data/permission_plugins.dart`](lib/src/data/permission_plugins.dart)) and the Apple SDK deadline table ([`lib/src/data/apple_sdk_requirements.dart`](lib/src/data/apple_sdk_requirements.dart)) are **living data** — PRs adding new plugins or new Apple deadlines are welcome.

## License

MIT
