# 📱 ADB Utility (`adbutil`)

A powerful interactive Bash utility for Android development, powered by ADB. Supports app management, demo mode, proxy settings, device credentials, and more — all from a clean TUI using [Gum](https://github.com/charmbracelet/gum) (or fallback to plain `select`).

Created by [Gergely Marosi](https://github.com/marosige)

## 📽 Demo

![Demo](assets/demo.gif)

## ✨ Features

- 📦 Manage installed packages: launch, uninstall, clear data, and more  
- 🔐 Store and inject saved credentials into apps  
- 📝 Paste strings into apps from your saved list  
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

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=false
ADBUTIL_SKIP_ASK_UPDATE=false
ADBUTIL_USE_GUM=true

## Private values

# Credentials
# Format: "Title|Username|Password"
# Examples: "Admin|adminuser|password"
#           "Free user|freeuser|password"
#           "Subsciber|subuser|password"
ADBUTIL_CREDENTIALS=(
    "Admin|adminuser|p4ssw0rd"
    "Free user|freeuser|p4ssw0rd"
    "Subsciber|subuser|p4ssw0rd"
)

# Strings to paste
# Format: "Category|String"
# Examples: "register|email"
#           "register|password"
#           "register|country"
#           "promocode|AAAA-1111-BBBB-2222"
#           "promocode|BBBB-3333-CCCC-4444"
ADBUTIL_PASTE_STRINGS=(
    "register|my@email.com"
    "register|p4ssw0rd"
    "register|Hungary"
    "promocode|AAAA-1111-BBBB-2222"
    "promocode|BBBB-3333-CCCC-4444"
)

# Package filter (wildcards supported, e.g. "com.example.*")
ADBUTIL_PACKAGE_FILTER=(
    "com.google.*"
    "com.samsung.*"
)

```

> 💡 Tip: You can disable install/update prompts by setting the related flags to `true` in the config.

Changes take effect the next time you launch `adbutil`.