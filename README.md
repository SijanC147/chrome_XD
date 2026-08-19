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

Every published GitHub release triggers the
[Release Build workflow](.github/workflows/release-build.yml) on a
GitHub-hosted macOS runner. (Bare tag pushes intentionally do not trigger
builds — publishing a release with a new tag would otherwise start two
racing runs. Release tags must follow `v<major>[.<minor>[.<patch>]]`.) It builds a **universal binary**
(Apple Silicon + Intel, macOS 13.0+), signs it with a Developer ID
certificate, notarizes it with Apple, staples the ticket, and attaches
`ChromeXD-<version>.zip` to the release — so downloaded builds open
without Gatekeeper warnings.

The app version is stamped from the tag (e.g. tag `v1.2.0` →
`CFBundleShortVersionString 1.2.0`). The workflow can also be run manually
(workflow_dispatch) to produce a test build artifact — manual runs never
attach anything to releases, and the `force_adhoc` input skips
signing/notarization for quick pipeline tests.

Maintainers: signing/notarization requires these repository secrets —
`MACOS_CERTIFICATE_P12` (base64 .p12), `MACOS_CERTIFICATE_PASSWORD`,
`APPLE_TEAM_ID`, `NOTARY_API_KEY_P8`, `NOTARY_API_KEY_ID`,
`NOTARY_API_ISSUER_ID`. If they're absent the workflow still succeeds with an
ad-hoc–signed, non-notarized build (first launch then needs
right-click → Open).

## Installation

1. Copy `ChromeXD.app` to `/Applications/`

2. Launch ChromeXD once:
   - First launch may require: Right-click → Open → Open (due to Gatekeeper)
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
