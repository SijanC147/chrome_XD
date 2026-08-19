# ChromeXD - Chrome Extension Compatibility Wrapper

A macOS app that ensures Google Chrome always runs with extension compatibility flags enabled.

## Purpose

ChromeXD wraps Google Chrome and ensures it always launches with these flags:
- `--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled`
- `--silent-debugger-extension-api`

These flags enable legacy Manifest V2 extension support.

## Features

- **Default Browser**: Can be set as macOS default browser
- **Background Monitor**: Watches for Chrome launches and ensures flags are applied
- **Menu Bar Icon**: Shows status and provides quick access
- **Login Item**: Automatically starts at login

## How It Works

1. **URL Handling**: When you click a link anywhere in macOS, ChromeXD receives it and opens Chrome with the required flags
2. **Launch Monitoring**: If Chrome is launched directly (Dock, Spotlight, Terminal), ChromeXD detects it, terminates it, and relaunches with the correct flags
3. **Session Restoration**: Chrome's built-in session restore recovers your tabs after the restart

## Building

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Build Steps

1. Open the project in Xcode:
   ```bash
   open ChromeXD/ChromeXD.xcodeproj
   ```

2. Select your development team in Signing & Capabilities (or use "Sign to Run Locally")

3. Build the project: `Cmd+B`

4. Find the built app in Products folder (right-click → Show in Finder)

### Command Line Build
```bash
cd ChromeXD
xcodebuild -scheme ChromeXD -configuration Release build
```

## Releases (CI)

Cutting a release is a single step: **push a `v*` tag**.

```bash
git tag v1.2.0 && git push origin v1.2.0
```

That triggers the [Release Build workflow](.github/workflows/release-build.yml)
on a GitHub-hosted macOS runner, which:

1. builds a **universal binary** (Apple Silicon + Intel, macOS 13.0+),
2. signs it with a Developer ID certificate, notarizes it with Apple, and
   staples the ticket — so downloads open without Gatekeeper warnings,
3. packages both `ChromeXD-<version>.zip` and a drag-to-install
   `ChromeXD-<version>.dmg` (the disk image is signed, notarized, and
   stapled in its own right),
4. **creates the GitHub release** for that tag with an auto-generated
   changelog, and attaches both artifacts to it. The release it creates stays
   a draft until both artifacts have uploaded, so a failed build never leaves
   a published release with missing downloads.

Creating a release through the GitHub UI works too (that also pushes the tag):
the run finds the release already present and only attaches artifacts, leaving
hand-written release notes and its draft state untouched.

Tags must follow `v<major>[.<minor>[.<patch>]]` — the workflow refuses
anything else so a malformed version can never be embedded in a release. The
app version is stamped from the tag (tag `v1.2.0` →
`CFBundleShortVersionString 1.2.0`).

The workflow can also be run manually (workflow_dispatch) to produce test
build artifacts. Manual runs never create or modify releases, and the
`force_adhoc` input skips signing/notarization for quick pipeline tests.

Helper scripts used by the workflow live in
[`.github/scripts/`](.github/scripts) and can be run locally; both support
`--dry-run` and `--help`.

Maintainers: signing/notarization requires these repository secrets —
`MACOS_CERTIFICATE_P12` (base64 .p12), `MACOS_CERTIFICATE_PASSWORD`,
`APPLE_TEAM_ID`, `NOTARY_API_KEY_P8`, `NOTARY_API_KEY_ID`,
`NOTARY_API_ISSUER_ID`. Releases require all six: a tag push fails before
building rather than publishing artifacts Gatekeeper would reject. Manual test
builds, by contrast, fall back to an ad-hoc–signed, non-notarized build when
the secrets are absent (such a build needs right-click → Open on first
launch).

## Installation

Download the latest `ChromeXD-<version>.dmg` (or `.zip`) from the
[Releases page](https://github.com/SijanC147/chrome_XD/releases).

1. Open the `.dmg` and drag **ChromeXD** to the `Applications` folder
   (or copy `ChromeXD.app` to `/Applications/` if you downloaded the zip)

2. Launch ChromeXD once:
   - Official notarized releases open normally. A locally built (unsigned)
     app may require: Right-click → Open → Open (due to Gatekeeper)
   - Grant any requested permissions

3. Set as default browser:
   - Open **System Settings** → **Desktop & Dock**
   - Scroll to **Default web browser**
   - Select **Chrome XD**

## Usage

Once installed and set as default browser:

- **Click any link** → Opens in Chrome with extension flags
- **Launch Chrome directly** → ChromeXD intercepts and relaunches with flags
- **Menu bar icon** → Shows ChromeXD is active, provides quick actions

### Verify Flags Are Active

1. Open Chrome
2. Navigate to `chrome://version`
3. Check "Command Line" shows both flags

## Project Structure

```
ChromeXD/
├── ChromeXD.xcodeproj/     # Xcode project
└── ChromeXD/
    ├── AppDelegate.swift     # App entry, URL handling, menu bar
    ├── ChromeMonitor.swift   # Background process monitoring
    ├── ChromeLauncher.swift  # Chrome launch with flags
    ├── ProcessInspector.swift # sysctl argument inspection
    ├── Info.plist            # URL schemes, bundle config
    ├── ChromeXD.entitlements # Permissions
    └── Assets.xcassets/      # App icon
```

## Troubleshooting

### ChromeXD doesn't appear in Default Browser list
- Ensure the app is in `/Applications/`
- Run: `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ChromeXD.app`

### Chrome keeps launching without flags
- Make sure ChromeXD is running (check menu bar)
- Check ChromeXD is set as login item in System Settings

### Permission errors
- Grant accessibility permissions if prompted
- Grant automation permissions for Google Chrome

## License

Personal use. Not affiliated with Google.
