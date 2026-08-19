# Chrome URL Schemes and Programmatic Actions Research

> **Research Date:** December 2024
> **Purpose:** Document all methods for triggering Chrome actions via URL schemes, command-line, and automation APIs.

---

## Table of Contents

1. [Overview](#overview)
2. [Chrome Internal URLs (chrome://)](#chrome-internal-urls-chrome)
3. [Command-Line Switches](#command-line-switches)
4. [Custom URL Scheme Integration](#custom-url-scheme-integration)
5. [AppleScript Automation (macOS)](#applescript-automation-macos)
6. [chrome-cli Tool (macOS)](#chrome-cli-tool-macos)
7. [Chrome DevTools Protocol (CDP)](#chrome-devtools-protocol-cdp)
8. [Chrome Extension APIs](#chrome-extension-apis)
9. [PWA and App Mode](#pwa-and-app-mode)
10. [Implementation Recommendations for ChromeXD](#implementation-recommendations-for-chromexd)

---

## Overview

Chrome provides multiple mechanisms for programmatic control and action triggering:

| Method | Scope | Complexity | Best For |
|--------|-------|------------|----------|
| `chrome://` URLs | Navigate to internal pages | Low | Opening settings, tools |
| Command-line switches | Launch-time configuration | Low | Window modes, profiles |
| Custom URL schemes | External app integration | Medium | Deep linking, app triggers |
| AppleScript | macOS automation | Medium | Tab/window control |
| chrome-cli | macOS CLI automation | Low | Scripted automation |
| DevTools Protocol | Full browser control | High | Testing, automation |
| Extension APIs | In-browser automation | High | User-installed features |

---

## Chrome Internal URLs (chrome://)

Chrome exposes 100+ internal pages via the `chrome://` scheme. Access the full list at `chrome://chrome-urls` or `chrome://about/`.

### Core Browsing Pages

| URL | Purpose | Notes |
|-----|---------|-------|
| `chrome://newtab` | Open new tab page | Default start page |
| `chrome://bookmarks` | Bookmark manager | Full-featured UI |
| `chrome://downloads` | Download manager | View/manage downloads |
| `chrome://history` | Browsing history | Search and clear |
| `chrome://extensions` | Extension manager | Install/configure extensions |
| `chrome://apps` | Chrome apps page | Legacy apps interface |

### Settings & Configuration

| URL | Purpose | Notes |
|-----|---------|-------|
| `chrome://settings` | Main settings page | All browser settings |
| `chrome://settings/passwords` | Password manager | View saved passwords |
| `chrome://settings/privacy` | Privacy settings | Cookies, tracking |
| `chrome://settings/appearance` | Appearance settings | Themes, fonts |
| `chrome://settings/searchEngines` | Search engine settings | Default search config |
| `chrome://settings/languages` | Language settings | UI and spell check |
| `chrome://settings/content` | Site permissions | Camera, mic, location |
| `chrome://settings/defaultBrowser` | Default browser setting | Set as default |
| `chrome://flags` | Experimental features | **Caution: Unstable features** |

### Debugging & Developer Tools

| URL | Purpose | Notes |
|-----|---------|-------|
| `chrome://version` | Version info | Shows flags, profile path |
| `chrome://gpu` | GPU info & status | Graphics diagnostics |
| `chrome://net-internals` | Network diagnostics | DNS, sockets, HSTS |
| `chrome://inspect` | DevTools targets | Debug pages, extensions |
| `chrome://tracing` | Performance tracing | Chrome trace recording |
| `chrome://crashes` | Crash reports | View crash history |
| `chrome://histograms` | Usage metrics | Internal statistics |
| `chrome://sync-internals` | Sync debugging | Account sync status |
| `chrome://media-internals` | Media debugging | Audio/video status |

### Security & Privacy

| URL | Purpose | Notes |
|-----|---------|-------|
| `chrome://safe-browsing` | Safe browsing status | Protection info |
| `chrome://certificate-manager` | SSL certificates | Manage certs |
| `chrome://policy` | Applied policies | Enterprise policies |
| `chrome://sandbox` | Sandbox status | Security sandbox info |

### Specialized Pages

| URL | Purpose | Notes |
|-----|---------|-------|
| `chrome://dino` | Dinosaur game | The offline game! |
| `chrome://credits` | Open source credits | Library attributions |
| `chrome://components` | Chrome components | Update status |
| `chrome://bluetooth-internals` | Bluetooth debugging | BLE diagnostics |
| `chrome://webrtc-internals` | WebRTC debugging | Call diagnostics |
| `chrome://serviceworker-internals` | Service worker debug | PWA workers |
| `chrome://device-log` | Device logs | Hardware events |
| `chrome://autofill-internals` | Autofill debugging | Form filling debug |

### Opening chrome:// URLs Programmatically

**From ChromeXD (current implementation):**
```swift
if let url = URL(string: "chrome://version") {
    chromeLauncher.openURLs([url])
}
```

**Limitations:**
- Cannot be opened via JavaScript from web pages (security restriction)
- Some pages require specific permissions or enterprise policies
- Cannot be opened in iframes

---

## Command-Line Switches

Chrome supports 1000+ command-line switches. The authoritative list is maintained at [peter.sh/experiments/chromium-command-line-switches](https://peter.sh/experiments/chromium-command-line-switches/).

### Window & Tab Control

| Switch | Description | Example |
|--------|-------------|---------|
| `--new-window` | Open URLs in new window | `chrome --new-window https://example.com` |
| `--new-tab` | Open URL in new tab | (default behavior) |
| `--incognito` | Open in incognito mode | `chrome --incognito https://private.com` |
| `--app=<url>` | Open as standalone app window | `chrome --app=https://app.example.com` |
| `--kiosk` | Full-screen kiosk mode | `chrome --kiosk https://display.com` |
| `--start-maximized` | Start maximized | `chrome --start-maximized` |
| `--start-fullscreen` | Start in fullscreen | `chrome --start-fullscreen` |
| `--window-size=w,h` | Set window dimensions | `chrome --window-size=1280,720` |
| `--window-position=x,y` | Set window position | `chrome --window-position=100,100` |

### Profile & User Management

| Switch | Description | Example |
|--------|-------------|---------|
| `--profile-directory=<name>` | Use specific profile | `--profile-directory="Profile 2"` |
| `--user-data-dir=<path>` | Custom user data directory | `--user-data-dir=/tmp/chrome-test` |
| `--guest` | Start in guest mode | `chrome --guest` |

### Remote Debugging

| Switch | Description | Example |
|--------|-------------|---------|
| `--remote-debugging-port=<port>` | Enable CDP on port | `--remote-debugging-port=9222` |
| `--remote-debugging-address=<ip>` | Bind to specific address | `--remote-debugging-address=0.0.0.0` |
| `--remote-allow-origins=<origins>` | Allow specific origins | `--remote-allow-origins=*` |

### Performance & Features

| Switch | Description | Use Case |
|--------|-------------|----------|
| `--disable-gpu` | Disable GPU acceleration | Compatibility |
| `--disable-extensions` | Disable all extensions | Clean testing |
| `--disable-plugins` | Disable plugins | Security |
| `--no-sandbox` | Disable sandbox | **Security risk** |
| `--disable-web-security` | Disable CORS | **Dev only** |
| `--enable-features=<list>` | Enable Chrome features | New features |
| `--disable-features=<list>` | Disable Chrome features | Compatibility |

### Current ChromeXD Usage

From `ChromeLauncher.swift:177-179`:
```swift
var args = currentFlags + ["--new-window"]
args += urls.map { $0.absoluteString }
process.arguments = args
```

---

## Custom URL Scheme Integration

### How ChromeXD Uses Custom Schemes

ChromeXD registers `chromexd-new://` scheme for forcing new window opens:

```swift
// AppDelegate.swift:42-54
let newWindowURLs = urls.filter { $0.scheme == "chromexd-new" }
// Convert chromexd-new://example.com/path -> https://example.com/path
var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
components?.scheme = "https"
```

### Potential Additional Custom Schemes

| Proposed Scheme | Action | Implementation |
|-----------------|--------|----------------|
| `chromexd-new://` | Open in new window | **Already implemented** |
| `chromexd-incognito://` | Open in incognito | Convert + `--incognito` flag |
| `chromexd-app://` | Open as app window | Convert + `--app=` flag |
| `chromexd-profile://` | Open in specific profile | Parse profile from path |
| `chromexd-settings://` | Open Chrome settings | Redirect to `chrome://settings` |

### Registering URL Schemes (Info.plist)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>ChromeXD New Window</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>chromexd-new</string>
            <string>chromexd-incognito</string>
            <string>chromexd-app</string>
        </array>
    </dict>
</array>
```

### Protocol Handler Security Notes

- Custom schemes can only be triggered from user-initiated actions
- Cannot be loaded in iframes
- Browser shows security prompt for unknown schemes
- Consider scheme hijacking risks

---

## AppleScript Automation (macOS)

Chrome has built-in AppleScript support for window and tab management.

### Basic Commands

```applescript
-- Get URL of active tab
tell application "Google Chrome"
    set currentURL to URL of active tab of front window
end tell

-- Open URL in new tab
tell application "Google Chrome"
    tell window 1
        make new tab with properties {URL:"https://example.com"}
    end tell
end tell

-- Open URL in new window
tell application "Google Chrome"
    make new window
    set URL of active tab of front window to "https://example.com"
end tell

-- Open in incognito
tell application "Google Chrome"
    make new window with properties {mode:"incognito"}
    set URL of active tab of front window to "https://example.com"
end tell
```

### Tab/Window Properties

```applescript
tell application "Google Chrome"
    -- Window properties
    set bounds of front window to {100, 100, 1200, 800}
    set miniaturized of front window to false

    -- Tab properties
    tell active tab of front window
        set theTitle to title
        set theURL to URL
        reload
        go back
        go forward
    end tell
end tell
```

### Execute JavaScript

```applescript
-- Requires: View > Developer > Allow JavaScript from Apple Events
tell application "Google Chrome"
    tell active tab of front window
        execute javascript "document.title"
    end tell
end tell
```

### Integration with ChromeXD

```swift
// Example: Using NSAppleScript
let script = """
tell application "Google Chrome"
    make new window with properties {mode:"incognito"}
    set URL of active tab of front window to "\(url)"
end tell
"""
var error: NSDictionary?
NSAppleScript(source: script)?.executeAndReturnError(&error)
```

---

## chrome-cli Tool (macOS)

A powerful third-party CLI tool for Chrome automation.

### Installation

```bash
brew install chrome-cli
```

### Available Commands

| Command | Description |
|---------|-------------|
| `chrome-cli list windows` | List all windows |
| `chrome-cli list tabs` | List all tabs |
| `chrome-cli list tabs -w <id>` | List tabs in window |
| `chrome-cli info` | Info for active tab |
| `chrome-cli open <url>` | Open in new tab |
| `chrome-cli open <url> -n` | Open in new window |
| `chrome-cli open <url> -i` | Open in incognito window |
| `chrome-cli open <url> -t <id>` | Open in specific tab |
| `chrome-cli close` | Close active tab |
| `chrome-cli close -w` | Close active window |
| `chrome-cli reload` | Reload active tab |
| `chrome-cli back` | Navigate back |
| `chrome-cli forward` | Navigate forward |
| `chrome-cli source` | Print page source |
| `chrome-cli execute <js>` | Execute JavaScript |
| `chrome-cli chrome version` | Chrome version |
| `chrome-cli chrome path` | Chrome binary path |

### JSON Output

```bash
OUTPUT_FORMAT=json chrome-cli list tabs
```

### Other Browsers

```bash
CHROME_BUNDLE_IDENTIFIER="com.brave.Browser" chrome-cli list tabs
CHROME_BUNDLE_IDENTIFIER="com.microsoft.edgemac" chrome-cli list tabs
```

### Integration with ChromeXD

```swift
func openInIncognitoUsingChromeCli(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/chrome-cli")
    process.arguments = ["open", url.absoluteString, "-i"]
    try? process.run()
}
```

---

## Chrome DevTools Protocol (CDP)

The most powerful method for Chrome automation, used by Puppeteer, Playwright, and Selenium.

### Enabling Remote Debugging

```bash
# Start Chrome with debugging port
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=9222
```

### CDP Endpoints

| Endpoint | Description |
|----------|-------------|
| `http://localhost:9222/json` | List of debuggable targets |
| `http://localhost:9222/json/version` | Browser version info |
| `http://localhost:9222/json/protocol` | Full protocol spec |
| `http://localhost:9222/json/new?url` | Open new tab |
| `http://localhost:9222/json/close/<id>` | Close tab |
| `http://localhost:9222/json/activate/<id>` | Activate tab |

### CDP Domains

Key protocol domains for actions:

| Domain | Capabilities |
|--------|--------------|
| `Browser` | Close, window management, permissions |
| `Target` | Create/close tabs, attach to targets |
| `Page` | Navigate, reload, screenshot, PDF |
| `Network` | Intercept, mock, throttle |
| `Input` | Keyboard, mouse events |
| `Runtime` | Execute JavaScript |
| `DOM` | Query, modify DOM |
| `Emulation` | Device, geolocation, timezone |

### Example CDP Commands

```json
// Navigate to URL
{"id": 1, "method": "Page.navigate", "params": {"url": "https://example.com"}}

// Take screenshot
{"id": 2, "method": "Page.captureScreenshot", "params": {"format": "png"}}

// Execute JavaScript
{"id": 3, "method": "Runtime.evaluate", "params": {"expression": "document.title"}}

// Create new target (tab)
{"id": 4, "method": "Target.createTarget", "params": {"url": "https://example.com"}}
```

### Swift WebSocket Integration

```swift
import Foundation

class CDPClient {
    var webSocket: URLSessionWebSocketTask?

    func connect(to debuggerUrl: String) {
        let url = URL(string: debuggerUrl)!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
    }

    func send(command: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: command)
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocket?.send(message) { error in
            if let error = error {
                print("CDP send error: \(error)")
            }
        }
    }

    func navigate(to url: String) {
        send(command: [
            "id": 1,
            "method": "Page.navigate",
            "params": ["url": url]
        ])
    }
}
```

---

## Chrome Extension APIs

For user-installed extensions, Chrome provides rich APIs.

### Relevant APIs for Actions

| API | Capabilities | Permission |
|-----|--------------|------------|
| `chrome.tabs` | Create, update, close tabs | `tabs` |
| `chrome.windows` | Create, update, close windows | `windows` |
| `chrome.bookmarks` | CRUD bookmarks | `bookmarks` |
| `chrome.downloads` | Start, manage downloads | `downloads` |
| `chrome.history` | Read, modify history | `history` |
| `chrome.browsingData` | Clear browsing data | `browsingData` |
| `chrome.commands` | Keyboard shortcuts | N/A |
| `chrome.contextMenus` | Right-click menu items | `contextMenus` |

### Example: Create Window with Specific Properties

```javascript
chrome.windows.create({
    url: "https://example.com",
    type: "normal",  // or "popup", "panel"
    incognito: true,
    width: 1200,
    height: 800,
    left: 100,
    top: 100,
    focused: true
});
```

### Example: Download File

```javascript
chrome.downloads.download({
    url: "https://example.com/file.pdf",
    filename: "downloaded-file.pdf",
    saveAs: false
});
```

---

## PWA and App Mode

### --app Flag

Opens a website in a minimal window without browser UI:

```bash
chrome --app=https://music.spotify.com
```

**Properties:**
- No address bar, tabs, or bookmarks bar
- Has minimize, maximize, close buttons
- Site can still open popups
- Useful for web apps

### PWA Standalone Mode

For installed PWAs with `display: "standalone"` in manifest:

```json
{
    "display": "standalone",
    "start_url": "/app",
    "scope": "/"
}
```

### Kiosk Mode

Full-screen mode with no UI, difficult to exit:

```bash
chrome --kiosk https://signage.example.com
```

---

## Implementation Recommendations for ChromeXD

### Priority 1: New Custom URL Schemes

**1. Incognito Window Scheme** (`chromexd-incognito://`)
```swift
func handleIncognitoScheme(_ url: URL) {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    if let httpsURL = components?.url {
        openInIncognito(httpsURL)
    }
}

func openInIncognito(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: chromeBinaryPath)
    process.arguments = currentFlags + ["--incognito", url.absoluteString]
    try? process.run()
}
```

**2. App Mode Scheme** (`chromexd-app://`)
```swift
func handleAppModeScheme(_ url: URL) {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    if let httpsURL = components?.url {
        openAsApp(httpsURL)
    }
}

func openAsApp(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: chromeBinaryPath)
    process.arguments = currentFlags + ["--app=\(url.absoluteString)"]
    try? process.run()
}
```

### Priority 2: Quick Actions Menu

Add menu items for common actions:

| Menu Item | Action |
|-----------|--------|
| Open Settings | `chrome://settings` |
| Open Extensions | `chrome://extensions` |
| Open Downloads | `chrome://downloads` |
| Open History | `chrome://history` |
| Open Flags | `chrome://flags` |
| Open New Incognito | Launch with `--incognito` |

### Priority 3: Advanced Features

**Profile Selector:**
```swift
func openInProfile(_ url: URL, profile: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: chromeBinaryPath)
    process.arguments = currentFlags + [
        "--profile-directory=\(profile)",
        url.absoluteString
    ]
    try? process.run()
}
```

**Window Geometry:**
```swift
func openWithGeometry(_ url: URL, x: Int, y: Int, width: Int, height: Int) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: chromeBinaryPath)
    process.arguments = currentFlags + [
        "--new-window",
        "--window-position=\(x),\(y)",
        "--window-size=\(width),\(height)",
        url.absoluteString
    ]
    try? process.run()
}
```

---

## Sources

- [Peter Beverloo's Chromium Command Line Switches](https://peter.sh/experiments/chromium-command-line-switches/)
- [Chrome DevTools Protocol Documentation](https://chromedevtools.github.io/devtools-protocol/)
- [chrome-cli GitHub Repository](https://github.com/prasmussen/chrome-cli)
- [Chromium AppleScript Support](https://www.chromium.org/developers/design-documents/applescript/)
- [Chrome Extension APIs Reference](https://developer.chrome.com/docs/extensions/reference/api)
- [PWA URL Protocol Handler](https://developer.chrome.com/docs/web-platform/best-practices/url-protocol-handler)
- [Chrome Internal URLs List](https://gist.github.com/evieluvsrainbows/4bec5630e040be4dcbbe460bb5a1a0ad)
- [gHacks Chrome URLs List](https://www.ghacks.net/2012/09/04/list-of-chrome-urls-and-their-purpose/)
- [MiniTool Chrome URLs Reference](https://www.minitool.com/news/chrome-urls.html)

---

## Changelog

| Date | Change |
|------|--------|
| 2024-12-12 | Initial research document created |
