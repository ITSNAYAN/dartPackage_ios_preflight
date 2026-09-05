# ios_preflight

A Flutter dev-dependency CLI that validates a project's iOS submission readiness **before** you build or open Xcode.

Catches the common reasons an iOS build fails at the App Store Connect upload step — missing `Info.plist` usage descriptions, Xcode/SDK below Apple's current minimum, deployment-target mismatches — so you find out in seconds, not after a full archive.

> **Status:** early development (`0.1.0`). No checks implemented yet — this release only wires up the CLI plumbing.

## Install

Add as a dev-dependency:

```yaml
dev_dependencies:
  ios_preflight: ^0.1.0
```

Then:

```sh
flutter pub get
dart run ios_preflight
```

## Roadmap

- `0.2.0` — Xcode / SDK deadline check
- `0.3.0` — `Info.plist` usage-description check
- Later — deployment target consistency, provisioning profile expiry, privacy manifest, Podfile.lock, simulator arch

See [`ios_preflight_package_plan.md`](https://github.com/nayansoni-Application/ios_preflight) for the full design.

## License

MIT
