# Cecko — project notes for Claude

A simple, good-looking C++ editor for students: write code, press Run, done.

## Code

- Native macOS app, SwiftUI, macOS 27+. Swift Package Manager plus shell
  scripts; there is no Xcode project, so never add one.
- `Sources/CeckoCore` holds logic without UI (no SwiftUI/AppKit) and is
  covered by `swift test` (Swift Testing). `Sources/Cecko` is the SwiftUI
  app and stays a thin layer over the core. New logic goes into the core,
  test first.
- Build and run: `./run.sh` (debug, logs in the terminal), `./run.sh release`,
  `./build.sh [debug|release|dist|clean]`. Details in `development_workflow.md`.
- Every user-visible change gets a line under `## Unreleased` in
  `CHANGELOG.md`; the release notes and the update dialog come from it.

## Releases

- Use the project skill `release` (`.claude/skills/release/SKILL.md`) for
  every release; it holds the whole procedure and its checks.
- Signing: Developer ID Application certificate and the `notary`
  notarytool profile live in the login Keychain.
- The Sparkle EdDSA private key lives only in the login Keychain. Never put
  it (or an exported copy) into the repo; `Info.plist` holds only the public
  key (`SUPublicEDKey`).

## Website (`docs/`, GitHub Pages)

- Served from `main` / `docs` at https://jiripisa.github.io/cecko/. The download links and
  version strings on the pages are bumped with every release.
- `docs/manual.html` describes every control of the app. A user-visible
  change is not done until the manual says how to use it; screenshots live
  in `docs/assets/manual/`.
- **The site is bilingual.** Every change to `docs/index.html` or
  `docs/manual.html` must also go into `docs/cs/` (and the other way
  round). Shared styles live in `docs/assets/`.
