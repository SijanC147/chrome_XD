# AGENTS.md

## Cursor Cloud specific instructions

ChromeXD is a **macOS-only Swift app** (AppKit/Cocoa/SwiftUI menu-bar app, built
with Xcode). The Cloud Agent VM is **Linux**, so the full app **cannot be built
or run here** — there is no `xcodebuild`, and `main.swift`, `AppDelegate.swift`,
`ChromeMonitor.swift`, `ChromeLauncher.swift`, `RecoveryAlert.swift`,
`FlagsSettingsView.swift` import `Cocoa`/`AppKit`/`SwiftUI`/`ServiceManagement`,
and `ProcessInspector.swift` uses Darwin-only `sysctl` constants. Real builds
happen on macOS + Xcode (see `README.md`) or via the `release-build.yml`
GitHub Actions workflow on a `macos-latest` runner. There are **no XCTest
targets** in this repo, so there is no `xcodebuild test` suite to run.

What the Linux environment is set up to do (the active work on this repo is the
macOS release-build CI workflow plus the platform-independent flag logic):

- **Lint the CI workflow** (the main thing editable/verifiable on Linux):
  `actionlint .github/workflows/release-build.yml`
- **Validate the flags config** (`chrome-flags.json` exists in two identical
  copies — repo root and `ChromeXD/ChromeXD/`; the bundled one is what ships):
  `jq 'length' ChromeXD/ChromeXD/chrome-flags.json`
- **Compile & run the Foundation-only core logic** (`FlagsValidator.swift` +
  `FlagsConfiguration.swift`) with the Linux Swift toolchain. `Bundle.main`
  finds `chrome-flags.json` only when it sits next to the compiled binary, so
  copy it into the build dir:
  ```bash
  d=$(mktemp -d); cp ChromeXD/ChromeXD/{FlagsValidator,FlagsConfiguration}.swift ChromeXD/ChromeXD/chrome-flags.json "$d"/
  # add a main.swift that calls FlagsValidator.shared.validate(flags:), then:
  (cd "$d" && swiftc -o verify *.swift && ./verify)
  ```

### Toolchains (installed in the base environment, on PATH via `~/.bashrc`)

- **Swift 6.1.2** (Linux) at `/opt/swift/usr/bin` — only compiles the
  Foundation-only files above; AppKit/Cocoa/SwiftUI files will fail on Linux.
  If missing after a cold boot, reinstall: download
  `swift-6.1.2-RELEASE-ubuntu24.04.tar.gz` from `download.swift.org`, extract to
  `/opt/swift`, and ensure the apt runtime libs are present (`libncurses6`,
  `libncursesw6`, `libpython3-dev`, `libxml2`, `libcurl4`, `libedit2`,
  `libsqlite3-0`).
- **actionlint** at `$(go env GOPATH)/bin` — the update script reinstalls it via
  `go install` if absent. `shellcheck` is not installed, so actionlint does not
  lint the workflow's inline `run:` scripts; install `shellcheck` if you need
  that.
