# 📱 ADB Utility (`adbutil`)

A powerful interactive Bash utility for Android development, powered by ADB. Supports app management, demo mode, proxy settings, device credentials, and more — all from a clean TUI using [Gum](https://github.com/charmbracelet/gum) (or fallback to plain `select`).

Created by [Gergely Marosi](https://github.com/marosige)

## 📽 Demo

![Demo](assets/demo.gif)

## ✨ Features

- � Projects: group package regexes, credentials, paste strings and deeplinks per project  
- 📦 Manage installed packages: launch, force stop, clear data, uninstall, and more  
- 🔐 Type saved credentials into apps (username, tab, password, enter)  
- 📝 Paste strings into apps from your saved list  
- 🔗 Open deeplinks  
- 🎯 Toggle layout bounds for debugging UI  
- 🌐 Set or check proxy settings on the device  
- 📸 Toggle Android’s demo mode (perfect for screenshots)  
- 🎬 Control media sessions  
- 🔧 Fire TV Dev Tools quick access  
- ⏱️ Sync device time or open settings  

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

You can customize the following options in that file:

```bash
### ADB Utility Configuration
### https://github.com/marosige/adbutil

ADBUTIL_CONFIG_VERSION=2

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=false
ADBUTIL_SKIP_ASK_UPDATE=false
ADBUTIL_USE_GUM=true

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