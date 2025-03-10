# 📱 ADB Utility (`adbutil`)

A powerful interactive Bash utility for Android development, powered by ADB. Supports app management, demo mode, proxy settings, device credentials, and more — all from a clean TUI using [Gum](https://github.com/charmbracelet/gum) (or fallback to plain `select`).

Created by [Gergely Marosi](https://github.com/marosige)

## ✨ Features

- 📦 Manage installed packages: launch, uninstall, clear data, and more  
- 🔐 Store and inject saved credentials into apps  
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

---

## 🧰 Installation

Run directly via `curl`:

```bash
bash <(curl -s https://raw.githubusercontent.com/marosige/adbutil/main/adbutil.sh)
```

You can then run it at any time using:

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
# Preferences
ADBUTIL_SKIP_ASK_INSTALL=false     # Skip the install prompt
ADBUTIL_SKIP_ASK_UPDATE=false      # Skip the update prompt
ADBUTIL_USE_GUM=true               # Use gum for nicer UI if installed

# Credentials
# Format: "Title|Username|Password"
ADBUTIL_CREDENTIALS=(
    "Admin|adminuser|password"
    "Free user|freeuser|password"
)

# Strings to paste
# Format: "Category|String"
ADBUTIL_PASTE_STRINGS=(
    "register|email@example.com"
    "promocode|AAAA-1111-BBBB-2222"
)
```

> 💡 Tip: You can disable install/update prompts by setting the related flags to `true` in the config.

Changes take effect the next time you launch `adbutil`.