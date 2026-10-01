# 📱 ADB Utility (`adbutil`)

A powerful interactive Bash utility for Android development, powered by ADB. Supports app management, demo mode, proxy settings, device credentials, and more — all from a clean TUI using [Gum](https://github.com/charmbracelet/gum) (or fallback to plain `select`).

Created by [Gergely Marosi](https://github.com/marosige)

## 📽 Demo

![Demo](assets/demo.gif)

## ✨ Features

- 📁 **Projects:** group package regexes, credentials, paste strings and deeplinks per project
  - 🎮 Control apps: launch, force stop, home, clear data, uninstall, per-app language (Android 13+)  
  - 🔐 Type saved credentials (username, tab, password, enter) and 📝 paste strings  
  - 🔗 Open deeplinks  
- 🛠️ **Device Tools:**  
  - 📷 Capture: screenshots (also copied to the clipboard), screen recordings, demo mode  
  - 🎨 Display & Accessibility: dark mode, font size, display size, screen reader  
  - 🐞 Debug: layout bounds, show taps, pointer location, animations on/off, proxy  
  - 🔩 System: language settings, time sync, media session, device info, Fire TV dev tools  
  - 📦 All third party packages  
- ⚙️ **Settings:**  
  - 📱 Devices: select device, ⚡ quick connect saved devices, connect/pair/disconnect wireless devices, switch USB device to Wi-Fi  
  - 📝 Edit config  
- 📱 Multiple devices: device selector on the main screen, saved device names used as labels  

---

## 🧪 Prerequisites

- **ADB** installed and added to your `PATH`  
- (Optional but recommended) [Gum](https://github.com/charmbracelet/gum) for a better terminal UI experience

### 🚀 Quick Setup (macOS)

Install [Homebrew](https://brew.sh/), then use it to install ADB and Gum:

```bash
# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Install adb
brew install android-platform-tools
# Install gum
brew install gum
```

---

## 🧰 Try or Install

Try it by running directly via `curl`:

```bash
curl -s https://raw.githubusercontent.com/marosige/adbutil/main/adbutil.sh | bash
```

If you like it, select  **📥 Install adbutil** option from the menu. After installation, you can launch it anytime by running:

```bash
adbutil
```

## 🛠️ Configuration

When you run `adbutil` for the first time, it creates a configuration file at:

```
~/.adbutil
```

It starts with a `Maintenance` project containing deeplinks useful on any phone (Developer Options, Wi-Fi and Date & Time settings). You can customize the following options in that file:

```bash
### ADB Utility Configuration
### https://github.com/marosige/adbutil

ADBUTIL_CONFIG_VERSION=2

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=false
ADBUTIL_SKIP_ASK_UPDATE=false
ADBUTIL_USE_GUM=true
ADBUTIL_PROXY_PORT=8888 # Port of the proxy running on this computer (Charles default: 8888)
ADBUTIL_CAPTURE_FOLDER="$HOME/Desktop" # Where screenshots and screen recordings are saved
# Languages offered in App Language (Android 13+)
ADBUTIL_APP_LOCALES=(
    "en-US"
    "de-DE"
)

## Private values

# Projects
# Format: "Name|Package regex|Package regex|..."
# Package regexes are extended regexes matched against the whole package name.
# Packages are optional, a project can have none, one or many.
ADBUTIL_PROJECTS=(
    "Example|com\.example\..*"
    "Web only"
)

# Credentials
# Format: "Project|Title|Username|Password"
ADBUTIL_CREDENTIALS=(
    "Example|Admin|adminuser|p4ssw0rd"
    "Example|Free user|freeuser|p4ssw0rd"
)

# Strings to paste
# Format: "Project|Label|String"
ADBUTIL_PASTE_STRINGS=(
    "Example|Email|my@email.com"
    "Example|Promocode|AAAA-1111-BBBB-2222"
)

# Deeplinks
# Format: "Project|Name|Link"
ADBUTIL_DEEPLINKS=(
    "Example|Open Wifi|android.settings.WIFI_SETTINGS"
    "Web only|Google|https://www.google.com"
)
```

Selecting a project shows:

- **No matching app installed:** credentials, paste strings and deeplinks
- **One matching app:** the app screen directly (credentials, paste strings, deeplinks, control)
- **Multiple matching apps:** a list of the apps, then the app screen

> 💡 Updating from 1.x: your old `~/.adbutil` is never modified. adbutil stops with an error and saves a converted copy to `~/.adbutil.v2` with everything in a `Default` project. Split it into projects, then `mv ~/.adbutil.v2 ~/.adbutil`.

> 💡 Tip: You can disable install/update prompts by setting the related flags to `true` in the config.

Changes take effect the next time you launch `adbutil`.