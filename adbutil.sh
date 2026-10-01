#!/usr/bin/env bash

#####################################################################
# ADB Utility for Android Development
#
# Uses gum if available, select if not.
# Stores config inside .adbutil file in the home directory.
#
# Made by Gergely Marosi - https://github.com/marosige
#####################################################################

### Bootstrap

## Constants
DOWNLOAD_URL="https://raw.githubusercontent.com/marosige/adbutil/refs/heads/main/adbutil.sh"
DOWNLOAD_FOLDER="$HOME/bin"
DOWNLOAD_LOCATION="$DOWNLOAD_FOLDER/adbutil"
LOCAL_VERSION="2.0.0"
REMOTE_VERSION_CACHE="${TMPDIR:-/tmp}/adbutil-remote-version"

# Checked in the background at most once a day, so startup doesn't wait for the network
if [ -z "$(find "$REMOTE_VERSION_CACHE" -mtime -1 2>/dev/null)" ]; then
    (
        version=$(curl -fsSL --max-time 10 "$DOWNLOAD_URL" | grep -Eo 'LOCAL_VERSION="[0-9.]+"' | head -n1 | cut -d '"' -f 2)
        [ -n "$version" ] && echo "$version" > "$REMOTE_VERSION_CACHE"
    ) > /dev/null 2>&1 &
fi

# Returns 0 if version $1 is newer than version $2
isNewerVersion() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)" == "$1" ]; }

## Logging
BOLD='\033[1m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_GREEN='\033[0;92m'
YELLOW='\033[0;33m'
BRIGHT_RED='\033[0;91m'
NC='\033[0m'

LOG_TITLE="${BOLD}[#]${NC}"
LOG_TASK="${BRIGHT_BLUE}[>]${NC}"
LOG_INFO="${BRIGHT_BLUE}[i]${NC}"
LOG_DONE="${BRIGHT_GREEN}[✔]${NC}"
LOG_ADD="${BRIGHT_GREEN}[+]${NC}"
LOG_WARN="${YELLOW}[!]${NC}"
LOG_FAIL="${BRIGHT_RED}[✖]${NC}"
LOG_INDENT="   "

logTitle() { echo -e "${LOG_TITLE} $1"; }
logTask() { echo -e "${LOG_TASK} $1"; }
logInfo() { echo -e "${LOG_INFO} $1"; }
logDone() { echo -e "${LOG_DONE} $1"; }
logAdd() { echo -e "${LOG_ADD} $1"; }
logWarn() { echo -e "${LOG_WARN} $1"; }
logFail() { echo -e "${LOG_FAIL} $1"; }
logIndent() { echo -e "${LOG_INDENT} $1"; }

waitForEnter() {
    local DESTINATION="${1:+ to $1}"  # Adds " to <destination>" only if $1 is given
    echo -e "${YELLOW}Press enter to continue${DESTINATION:-...}${NC}"
    # Keyboard input comes from the terminal, stdin is the script itself when run with "curl | bash"
    read -r < /dev/tty
}

## Configuration
ADBUTIL_CONFIG="$HOME/.adbutil"
ADBUTIL_CONFIG_SUPPORTED_VERSION=2
if [ -f "$ADBUTIL_CONFIG" ]; then
    # Stop on a broken config instead of running with missing values.
    # bash 3.2 "bash -n" exits 0 on some syntax errors, so its output is checked too.
    # shellcheck source=/dev/null
    if [ -n "$(bash -n "$ADBUTIL_CONFIG" 2>&1)" ] || ! source "$ADBUTIL_CONFIG"; then
        logFail "Your config file has a syntax error: $ADBUTIL_CONFIG"
        logIndent "Fix it by hand, it was not modified."
        exit 1
    fi
    ADBUTIL_CONFIG_VERSION=${ADBUTIL_CONFIG_VERSION:-1}
else
    ADBUTIL_CONFIG_VERSION=$ADBUTIL_CONFIG_SUPPORTED_VERSION
fi

ADBUTIL_SKIP_ASK_INSTALL=${ADBUTIL_SKIP_ASK_INSTALL:=false}
ADBUTIL_SKIP_ASK_UPDATE=${ADBUTIL_SKIP_ASK_UPDATE:=false}
ADBUTIL_USE_GUM=${ADBUTIL_USE_GUM:=true}
ADBUTIL_PROXY_PORT=${ADBUTIL_PROXY_PORT:=8888}
ADBUTIL_CAPTURE_FOLDER=${ADBUTIL_CAPTURE_FOLDER:="$HOME/Desktop"}
[ ${#ADBUTIL_APP_LOCALES[@]} -eq 0 ] && ADBUTIL_APP_LOCALES=("en-US" "de-DE")

writeConfigArray() {
    local name="$1" value
    shift
    echo "$name=("
    for value in "$@"; do
        # Escape characters that are special inside double quotes, so the config can be sourced again
        value="${value//\"/\\\"}"
        value="${value//\$/\\\$}"
        value="${value//\`/\\\`}"
        echo "    \"$value\""
    done
    echo ")"
}

# Usage: writeConfig <file>
writeConfig() {
{
cat <<EOF
### ADB Utility Configuration
### https://github.com/marosige/adbutil

ADBUTIL_CONFIG_VERSION=$ADBUTIL_CONFIG_SUPPORTED_VERSION

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=$ADBUTIL_SKIP_ASK_INSTALL
ADBUTIL_SKIP_ASK_UPDATE=$ADBUTIL_SKIP_ASK_UPDATE
ADBUTIL_USE_GUM=$ADBUTIL_USE_GUM
ADBUTIL_PROXY_PORT=$ADBUTIL_PROXY_PORT # Port of the proxy running on this computer (Charles default: 8888)
ADBUTIL_CAPTURE_FOLDER="$ADBUTIL_CAPTURE_FOLDER" # Where screenshots and screen recordings are saved
# Languages offered in App Language (Android 13+)
EOF
writeConfigArray ADBUTIL_APP_LOCALES "${ADBUTIL_APP_LOCALES[@]}"
cat <<EOF

## Private values

# Projects
# Format: "Name|Package regex|Package regex|..."
# Package regexes are extended regexes matched against the whole package name.
# Packages are optional, a project can have none, one or many.
# Examples: "Example|com.example.app"
#           "Flavors|com\.example\..*|com\.example2\.(dev|prod)"
#           "No app"
EOF
writeConfigArray ADBUTIL_PROJECTS "${ADBUTIL_PROJECTS[@]}"
cat <<EOF

# Credentials
# Format: "Project|Title|Username|Password"
# Examples: "Example|Admin|adminuser|password"
#           "Example|Free user|freeuser|password"
EOF
writeConfigArray ADBUTIL_CREDENTIALS "${ADBUTIL_CREDENTIALS[@]}"
cat <<EOF

# Strings to paste
# Format: "Project|Label|String"
# Examples: "Example|Email|my@email.com"
#           "Example|Promocode|AAAA-1111-BBBB-2222"
EOF
writeConfigArray ADBUTIL_PASTE_STRINGS "${ADBUTIL_PASTE_STRINGS[@]}"
cat <<EOF

# Deeplinks
# Format: "Project|Name|Link"
# Examples: "Example|Open Wifi|android.settings.WIFI_SETTINGS"
#           "Example|Google|https://www.google.com"
EOF
writeConfigArray ADBUTIL_DEEPLINKS "${ADBUTIL_DEEPLINKS[@]}"
cat <<EOF

$SAVED_DEVICES_HEADER
EOF
writeConfigArray ADBUTIL_SAVED_DEVICES "${ADBUTIL_SAVED_DEVICES[@]}"
} > "$1"
}

SAVED_DEVICES_HEADER='# Saved devices for Quick Connect, managed by adbutil (Settings > Devices)
# Format: "Name|Address"'

# Replaces only the saved devices in the config, the rest of the file is kept as it is
writeSavedDevices() {
    BLOCK="$(writeConfigArray ADBUTIL_SAVED_DEVICES "${ADBUTIL_SAVED_DEVICES[@]}")" HEADER="$SAVED_DEVICES_HEADER" awk '
        /^ADBUTIL_SAVED_DEVICES=\(/ {
            print ENVIRON["BLOCK"]
            found = 1
            if ($0 !~ /\)[[:space:]]*$/) skip = 1
            next
        }
        skip { if (/^\)/) skip = 0; next }
        { print }
        END { if (!found) printf "\n%s\n%s\n", ENVIRON["HEADER"], ENVIRON["BLOCK"] }
    ' "$ADBUTIL_CONFIG" > "$ADBUTIL_CONFIG.tmp" && mv "$ADBUTIL_CONFIG.tmp" "$ADBUTIL_CONFIG"
}

# v1 config: convert it into a separate file for the user to review, the original is never touched
if [ "$ADBUTIL_CONFIG_VERSION" -lt "$ADBUTIL_CONFIG_SUPPORTED_VERSION" ]; then
    ADBUTIL_CONFIG_CONVERTED="$ADBUTIL_CONFIG.v$ADBUTIL_CONFIG_SUPPORTED_VERSION"
    # Don't overwrite a converted file the user may already be editing
    if [ ! -f "$ADBUTIL_CONFIG_CONVERTED" ]; then
        migrateEntries() {
            MIGRATED=()
            local entry
            for entry in "$@"; do
                [[ "$entry" == *"Set your "* ]] && continue # Skip v1 placeholder values
                MIGRATED+=("Default|$entry")
            done
        }
        migrateEntries "${ADBUTIL_CREDENTIALS[@]}"; ADBUTIL_CREDENTIALS=("${MIGRATED[@]}")
        migrateEntries "${ADBUTIL_PASTE_STRINGS[@]}"; ADBUTIL_PASTE_STRINGS=("${MIGRATED[@]}")
        migrateEntries "${ADBUTIL_DEEPLINKS[@]}"; ADBUTIL_DEEPLINKS=("${MIGRATED[@]}")
        ADBUTIL_PROJECTS=("Default")
        for filter in "${ADBUTIL_PACKAGE_FILTER[@]}"; do ADBUTIL_PROJECTS[0]+="|$filter"; done
        writeConfig "$ADBUTIL_CONFIG_CONVERTED"
    fi
    logFail "Your config file is from an older adbutil and is not compatible with version $LOCAL_VERSION."
    logIndent "Your config was NOT modified: $ADBUTIL_CONFIG"
    logIndent "A converted version is waiting for review: $ADBUTIL_CONFIG_CONVERTED"
    logIndent "Everything is in a \"Default\" project there. Split it into projects by hand, then replace your config:"
    logIndent "    mv \"$ADBUTIL_CONFIG_CONVERTED\" \"$ADBUTIL_CONFIG\""
    logIndent "Config format: https://github.com/marosige/adbutil#readme"
    exit 1
fi

if [ "$ADBUTIL_CONFIG_VERSION" -gt "$ADBUTIL_CONFIG_SUPPORTED_VERSION" ]; then
    logFail "Your config file is from a newer adbutil. Update adbutil, your config was NOT modified: $ADBUTIL_CONFIG"
    logIndent "Download: $DOWNLOAD_URL"
    exit 1
fi

# The config is only created, never rewritten, so hand edits and comments are kept.
# Written to a temp file first, so an interrupted write can't leave a half written config.
if [ ! -f "$ADBUTIL_CONFIG" ]; then
    # Starter project with deeplinks useful on any phone
    ADBUTIL_PROJECTS=("Maintenance")
    ADBUTIL_DEEPLINKS=(
        "Maintenance|Developer Options|android.settings.APPLICATION_DEVELOPMENT_SETTINGS"
        "Maintenance|Wi-Fi Settings|android.settings.WIFI_SETTINGS"
        "Maintenance|Date & Time Settings|android.settings.DATE_SETTINGS"
    )
    writeConfig "$ADBUTIL_CONFIG.tmp" && mv "$ADBUTIL_CONFIG.tmp" "$ADBUTIL_CONFIG"
fi

## Dependencies
isCommandExist() { command -v "$1" &> /dev/null; }
isCommandExist adb || { logFail "ADB is not installed. Please install it and try again."; exit 1; }
isCommandExist gum || { if $ADBUTIL_USE_GUM; then logWarn "Gum is not installed. Install it for a nicer UI"; ADBUTIL_USE_GUM=false; fi; }

## Install & Update
download() {
    local action=$1 # install or update

    #Create bin folder and add it to path if missing
    mkdir -p "$DOWNLOAD_FOLDER"
    [ -f "$HOME/.bashrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.bashrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.zshrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.zshrc"
    [ -f "$HOME/.config/fish/config.fish" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.config/fish/config.fish" && echo "set -gx PATH \$PATH $DOWNLOAD_FOLDER" >> "$HOME/.config/fish/config.fish"

    # Download next to the target and only replace it with a complete, valid script
    local download="$DOWNLOAD_LOCATION.download"
    if curl -fsSL -o "$download" "$DOWNLOAD_URL" && [ -z "$(bash -n "$download" 2>&1)" ] && grep -q '^LOCAL_VERSION=' "$download"; then
        chmod +x "$download"
        mv "$download" "$DOWNLOAD_LOCATION"
        logDone "adbutil $action succeed."
    else
        rm -f "$download"
        logFail "Failed to $action adbutil."
        logIndent "You can manually download it from: $DOWNLOAD_URL"
        logIndent "Don't forget to make it executable and move it to your PATH."
    fi

    waitForEnter "ADB Utility main menu."
    adbutil
    exit 0
}

## Menu
# Usage: menu <title> <highlighted option> <options...>
# Prints the selected option, or nothing if the menu was cancelled.
menu() {
    local title="$1" selected="$2"
    shift 2

    if $ADBUTIL_USE_GUM; then
        local args=(--height "$(( $(tput lines) - 4 ))" --header "$title") # Subtract 4 for gum UI elements
        [ -n "$selected" ] && args+=(--selected "$selected")
        gum choose "${args[@]}" "$@"
    else
        echo "$title" >&2
        PS3="Please select an option: "
        select choice in "$@"; do
            [ -n "$choice" ] && echo "$choice" && break
            echo -e "Invalid option. Please try again." >&2
        done < /dev/tty
    fi
}

# Usage: prompt <header> [placeholder]
# Prints the entered text.
prompt() {
    local value
    if $ADBUTIL_USE_GUM; then
        gum input --header "$1" --placeholder "${2:-}"
    else
        read -r -p "$1: " value < /dev/tty
        echo "$value"
    fi
}

# Usage: menuList [-s <status command>] [-n] <title> [<label> <command>]...
# Runs the command of the selected label until Back. The status command's output is shown in the title.
# Commands are strings, split on spaces, so they can have arguments.
# Returns when the device disconnects, unless -n (no device needed) is given.
menuList() {
    local status="" needsDevice=true title header last="" choice i entries labels
    while true; do
        case "$1" in
            -s) status="$2"; shift 2 ;;
            -n) needsDevice=false; shift ;;
            *) break ;;
        esac
    done
    title="$1"
    shift
    entries=("$@")
    labels=()
    for ((i = 0; i < ${#entries[@]}; i += 2)); do labels+=("${entries[$i]}"); done
    while ! $needsDevice || isDeviceConnected; do
        clear
        header="$title"
        # shellcheck disable=SC2086
        [ -n "$status" ] && header+=" ($($status))"
        choice=$(menu "$header" "$last" "${labels[@]}" "$MENU_BACK")
        last="$choice"
        if [ "$choice" == "$MENU_BACK" ] || [ -z "$choice" ]; then
            return
        fi
        for ((i = 0; i < ${#entries[@]}; i += 2)); do
            if [ "${entries[$i]}" == "$choice" ]; then
                # shellcheck disable=SC2086
                ${entries[$((i + 1))]}
                break
            fi
        done
    done
}

# Usage: menuToggle <title> <status command> <on command> <off command> [<label> <command>]...
menuToggle() {
    local title="$1" status="$2" on="$3" off="$4"
    shift 4
    menuList -s "$status" "$title" "$MENU_ON" "$on" "$MENU_OFF" "$off" "$@"
}

### ADB Utility

## Constants
MENU_INSTALL="📥 Install adbutil"
MENU_PROJECTS="📁 Projects"
MENU_ALL_PACKAGES="📦 All Third Party Packages"
MENU_DEVICE_TOOLS="🛠️ Device Tools"
MENU_CREDENTIALS="🔐 Credentials"
MENU_PASTE_STRINGS="📝 Paste Strings"
MENU_DEEPLINKS="🔗 Deeplinks"
MENU_CONTROL="🎮 Control"
MENU_LAUNCH="🚀 Launch"
MENU_FORCE_STOP="⛔ Force Stop"
MENU_HOME="🏠 Home (Background)"
MENU_CLEAR_DATA="🧹 Clear Data"
MENU_UNINSTALL="🗑️ Uninstall"
MENU_LAYOUT_BOUNDS="🎯 Layout Bounds"
MENU_SHOW_TAPS="👆 Show Taps"
MENU_POINTER_LOCATION="📍 Pointer Location"
MENU_ANIMATIONS="🐢 Animations"
MENU_DEBUG="🐞 Debug"
MENU_DISPLAY="🎨 Display & Accessibility"
MENU_CAPTURE="📷 Capture"
MENU_SYSTEM="🔩 System"
MENU_SETTINGS="⚙️ Settings"
MENU_EDIT_CONFIG="📝 Edit Config"
MENU_DARK_MODE="🌙 Dark Mode"
MENU_FONT_SIZE="🔠 Font Size"
MENU_DISPLAY_SIZE="🔍 Display Size"
MENU_SCREENSHOT="🖼️ Screenshot"
MENU_SCREEN_RECORD="🎥 Screen Record"
MENU_LANGUAGE="🌍 Language Settings"
MENU_APP_LANGUAGE="🌍 App Language"
MENU_SYSTEM_DEFAULT="⚙️ System default"
MENU_PROXY="🌐 Proxy"
MENU_DEMO_MODE="📸 Demo Mode"
MENU_MEDIA_SESSION="🎬 Media Session"
MENU_SCREEN_READER="📖 Screen Reader"
MENU_NAVIGATE="🧭 Navigate"
MENU_FIRE_TV_DEV_TOOLS="🔧 Fire TV Dev Tools"
MENU_SYNC_TIME="⏱️  Sync Time"
MENU_DEVICE_INFO="ℹ️ Device Info"
MENU_DEVICES="📱 Devices"
MENU_QUICK_CONNECT="⚡ Quick Connect"
MENU_WIFI_SWITCH="📶 Switch current device to Wi-Fi"
MENU_WIFI_CONNECT="🔗 Connect New Device"
MENU_WIFI_PAIR="🤝 Pair (Android 11+)"
MENU_WIFI_DISCONNECT="✂️ Disconnect"
MENU_FORGET_DEVICE="🗑️ Forget Saved Device"
MENU_ALL_WIFI_DEVICES="All Wi-Fi devices"
MENU_REFRESH="🔄 Refresh"
MENU_TAB=" ⇥ Tab Key"
MENU_ENTER=" ⏎ Enter Key"
MENU_SELECT_DEVICE="📱 Select Device"
MENU_EXIT="🚪 Exit"
MENU_BACK="↩️ Back"
MENU_ON="🟢 Enable"
MENU_OFF="🔴 Disable"
MENU_INFO="ℹ️ Info"
MENU_OPEN_SETTINGS="⚙️ Open settings screen"

## Devices
# adb targets ANDROID_SERIAL for every command, so selecting a device only has to set it

# Sets DEVICES to "serial|model" of the usable devices and DEVICES_UNAUTHORIZED to the count of unauthorized ones
loadDevices() {
    local serial state rest model
    DEVICES=()
    DEVICES_UNAUTHORIZED=0
    while read -r serial state rest; do
        case "$state" in
            device)
                model=$(echo "$rest" | grep -Eo 'model:[^ ]+' | cut -d: -f2)
                DEVICES+=("$serial|${model:-Unknown}")
                ;;
            unauthorized) DEVICES_UNAUTHORIZED=$((DEVICES_UNAUTHORIZED + 1)) ;;
        esac
    done < <(adb devices -l 2>/dev/null | tail -n +2)
}

# Keeps the selected device if it's still connected, picks the only device, otherwise leaves it unselected
selectDefaultDevice() {
    local device
    loadDevices
    for device in "${DEVICES[@]}"; do
        [ "${device%%|*}" == "$ANDROID_SERIAL" ] && return
    done
    unset ANDROID_SERIAL
    [ ${#DEVICES[@]} -eq 1 ] && export ANDROID_SERIAL="${DEVICES[0]%%|*}"
}

deviceLabel() {
    local device name
    name=$(savedDeviceName "$1")
    for device in "${DEVICES[@]}"; do
        [ "${device%%|*}" == "$1" ] && echo "${name:-${device#*|}} ($1)" && return
    done
}

savedDeviceName() {
    local device
    for device in "${ADBUTIL_SAVED_DEVICES[@]}"; do
        [ "${device#*|}" == "$1" ] && echo "${device%%|*}" && return
    done
}

isDeviceConnected() { [ -n "$ANDROID_SERIAL" ] && [ "$(adb get-state 2>/dev/null)" == "device" ]; }

## Project data
installedPackages() {
    adb shell cmd package list packages -3 | tr -d '\r' | cut -f 2 -d ":" | sort  # cut "package:" from "package:com.example"
}

# Returns 0 if the package matches one of the package regexes of the "Name|regex|..." project entry
projectMatchesPackage() {
    local package="$2" pattern regex parts=()
    IFS='|' read -r -a parts <<< "$1"
    for pattern in "${parts[@]:1}"; do
        regex="^(${pattern})\$"
        [[ "$package" =~ $regex ]] && return 0
    done
    return 1
}

# Sets PROJECT_PACKAGES to the installed packages matching the project's package regexes
loadProjectPackages() {
    local project="$1" entry package
    PROJECT_PACKAGES=()
    for entry in "${ADBUTIL_PROJECTS[@]}"; do
        [ "${entry%%|*}" == "$project" ] && break
    done
    [ "${entry%%|*}" == "$project" ] || return
    for package in $(installedPackages); do
        projectMatchesPackage "$entry" "$package" && PROJECT_PACKAGES+=("$package")
    done
}

# Sets PACKAGE_PROJECTS to the "|" separated names of the projects the package belongs to
loadPackageProjects() {
    local package="$1" entry
    PACKAGE_PROJECTS=""
    for entry in "${ADBUTIL_PROJECTS[@]}"; do
        projectMatchesPackage "$entry" "$package" && PACKAGE_PROJECTS+="${PACKAGE_PROJECTS:+|}${entry%%|*}"
    done
}

# Sets PROJECT_ENTRIES to the given "Project|..." entries of the "|" separated projects, without the project prefix
loadProjectEntries() {
    local projects="$1" entry
    shift
    PROJECT_ENTRIES=()
    for entry in "$@"; do
        if [[ "|$projects|" == *"|${entry%%|*}|"* ]]; then
            PROJECT_ENTRIES+=("${entry#*|}")
        fi
    done
}

# Sets PROJECT_ITEMS to the Deeplinks, Credentials and Paste Strings items the project has entries for
loadProjectItems() {
    local project="$1"
    PROJECT_ITEMS=()
    loadProjectEntries "$project" "${ADBUTIL_DEEPLINKS[@]}"
    [ ${#PROJECT_ENTRIES[@]} -gt 0 ] && PROJECT_ITEMS+=("$MENU_DEEPLINKS")
    loadProjectEntries "$project" "${ADBUTIL_CREDENTIALS[@]}"
    [ ${#PROJECT_ENTRIES[@]} -gt 0 ] && PROJECT_ITEMS+=("$MENU_CREDENTIALS")
    loadProjectEntries "$project" "${ADBUTIL_PASTE_STRINGS[@]}"
    [ ${#PROJECT_ENTRIES[@]} -gt 0 ] && PROJECT_ITEMS+=("$MENU_PASTE_STRINGS")
}

## Actions
# "input text" needs spaces as %s and runs through the device shell, so quote the rest
actionInputText() { adb shell input text "$(printf '%q' "${1// /%s}")"; }
actionTabKey() { adb shell input keyevent 61; }   # KEYCODE_TAB
actionEnterKey() { adb shell input keyevent 66; } # KEYCODE_ENTER
actionOpenDeeplink() {
    if [[ "$1" =~ ^https?:// ]]; then
        adb shell am start -a android.intent.action.VIEW -d "$1"
    else
        adb shell am start -a "$1"
    fi
}
## Device Tool Actions
# Status functions print the current state, shown in the menu title
getSetting() { adb shell settings get "$1" "$2" | tr -d '\r'; }
onOff() { if "$@"; then echo "On"; else echo "Off"; fi; }

actionLayoutBounds() { adb shell setprop debug.layout "$1"; adb shell service call activity 1599295570 > /dev/null 2>&1; }
statusLayoutBounds() { onOff [ "$(adb shell getprop debug.layout | tr -d '\r')" == "true" ]; }
actionShowTaps() { adb shell settings put system show_touches "$1"; }
statusShowTaps() { onOff [ "$(getSetting system show_touches)" == "1" ]; }
actionPointerLocation() { adb shell settings put system pointer_location "$1"; }
statusPointerLocation() { onOff [ "$(getSetting system pointer_location)" == "1" ]; }
actionAnimations() {
    local key
    for key in window_animation_scale transition_animation_scale animator_duration_scale; do
        adb shell settings put global "$key" "$1"
    done
}
statusAnimations() { onOff [ "$(getSetting global animator_duration_scale | sed 's/\.0*$//')" != "0" ]; }

actionDarkMode() { adb shell cmd uimode night "$1" > /dev/null 2>&1; }
statusDarkMode() { onOff [ "$(adb shell cmd uimode night 2>/dev/null | grep -c 'yes')" -gt 0 ]; }
actionFontScale() { adb shell settings put system font_scale "$1"; }
statusFontSize() {
    local scale
    scale=$(getSetting system font_scale)
    [ "$scale" == "null" ] && scale=1
    awk -v s="$scale" 'BEGIN { printf "%d%%", s * 100 + 0.5 }'
}
# Usage: actionDisplaySize <factor of the physical density | reset>
actionDisplaySize() {
    if [ "$1" == "reset" ]; then
        adb shell wm density reset
        return
    fi
    adb shell wm density "$(adb shell wm density | tr -d '\r' | awk -v f="$1" '/Physical/ { printf "%d", $3 * f + 0.5 }')"
}
statusDisplaySize() {
    adb shell wm density | tr -d '\r' | awk '/Physical/ { p = $3 } /Override/ { o = $3 } END { if (o) printf "%d%%", o * 100 / p + 0.5; else print "Default" }'
}

# Prints a new file path in the capture folder, named after the device model and time
captureFile() {
    mkdir -p "$ADBUTIL_CAPTURE_FOLDER"
    echo "$ADBUTIL_CAPTURE_FOLDER/$(adb shell getprop ro.product.model | tr -d '\r ')-$(date +%Y%m%d-%H%M%S).$1"
}
actionScreenshot() {
    local file
    file=$(captureFile png)
    clear
    if adb exec-out screencap -p > "$file" && [ -s "$file" ]; then
        osascript -e "set the clipboard to (read (POSIX file \"$file\") as «class PNGf»)" > /dev/null 2>&1
        logDone "Screenshot saved and copied to the clipboard:"
        logIndent "$file"
    else
        rm -f "$file"
        logFail "Could not take a screenshot."
    fi
    waitForEnter
}
actionScreenRecord() {
    local file pid remote="/sdcard/adbutil-recording.mp4"
    file=$(captureFile mp4)
    clear
    adb shell screenrecord "$remote" > /dev/null 2>&1 &
    pid=$!
    logTask "Recording... (Android stops automatically after 3 minutes)"
    echo -e "${YELLOW}Press enter to stop recording${NC}"
    read -r < /dev/tty
    # SIGINT lets screenrecord finish the file properly
    adb shell pkill -2 screenrecord > /dev/null 2>&1
    wait "$pid"
    sleep 1
    if adb pull "$remote" "$file" > /dev/null 2>&1; then
        logDone "Recording saved:"
        logIndent "$file"
    else
        logFail "Could not save the recording."
    fi
    adb shell rm -f "$remote" > /dev/null 2>&1
    waitForEnter
}
actionOpenLanguageSettings() { adb shell am start -a android.settings.LOCALE_SETTINGS > /dev/null 2>&1; }
# Usage: actionAppLanguage <package> [locale], without locale the app follows the system language again
actionAppLanguage() {
    if [ -n "$2" ]; then
        adb shell cmd locale set-app-locales "$1" --locales "$2" > /dev/null 2>&1
    else
        adb shell cmd locale set-app-locales "$1" > /dev/null 2>&1
    fi
}
statusAppLanguage() {
    local locales
    locales=$(adb shell cmd locale get-app-locales "$1" 2>/dev/null | tr -d '\r' | sed -n 's/.*\[\(.*\)\].*/\1/p')
    echo "${locales:-System default}"
}

actionProxyOn() {
    local interface ip=""
    # Wi-Fi/Ethernet first, the default route can be a VPN the device can't reach
    for interface in en0 en1 "$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"; do
        ip=$(ipconfig getifaddr "$interface" 2>/dev/null) && [ -n "$ip" ] && break
    done
    if [ -z "$ip" ]; then
        clear
        logFail "Could not find this computer's IP address, is it connected to a network?"
        waitForEnter
        return
    fi
    adb shell settings put global http_proxy "$ip:$ADBUTIL_PROXY_PORT"
}
actionProxyOff() { adb shell settings put global http_proxy :0; }
statusProxy() {
    local proxy
    proxy=$(getSetting global http_proxy)
    if [ -z "$proxy" ] || [ "$proxy" == "null" ] || [ "$proxy" == ":0" ]; then
        echo "Off"
    else
        echo "$proxy"
    fi
}
actionMediaSession() { adb shell cmd media_session dispatch "$1" > /dev/null 2>&1; }
actionMediaSessionInfo() { adb shell dumpsys media_session | less; }
# Only changes what the status bar shows, the real device time is untouched
actionDemoMode() {
    local demo=(adb shell am broadcast -a com.android.systemui.demo -e command)
    if [ "$1" = true ]; then
        adb shell settings put global sysui_demo_allowed 1 > /dev/null 2>&1
        "${demo[@]}" enter > /dev/null 2>&1
        "${demo[@]}" clock -e hhmm 1000 > /dev/null 2>&1                                   # Status bar clock 10:00
        "${demo[@]}" battery -e level 100 -e plugged false -e powersave false > /dev/null 2>&1
        "${demo[@]}" network -e wifi show -e level 4 -e fully true > /dev/null 2>&1
        "${demo[@]}" network -e mobile show -e level 4 -e datatype none > /dev/null 2>&1
        "${demo[@]}" network -e airplane hide > /dev/null 2>&1
        "${demo[@]}" status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e tty hide -e eri hide -e mute hide -e speakerphone hide -e managed_profile hide > /dev/null 2>&1
        "${demo[@]}" notifications -e visible false > /dev/null 2>&1
        if ! adb shell dumpsys activity service com.android.systemui 2>/dev/null | grep -q "isInDemoMode=true"; then
            clear
            logWarn "The device's System UI did not enter demo mode (some OEM builds, e.g. Samsung One UI, ignore it)."
            waitForEnter
        fi
    else
        "${demo[@]}" exit > /dev/null 2>&1
        adb shell settings put global sysui_demo_allowed 0 > /dev/null 2>&1
    fi
}
statusDemoMode() { onOff [ "$(adb shell dumpsys activity service com.android.systemui 2>/dev/null | grep -c 'isInDemoMode=true')" -gt 0 ]; }
TALKBACK_SERVICE="com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"
# Prints the enabled accessibility services, ":" separated
accessibilityServices() { adb shell settings get secure enabled_accessibility_services | tr -d '\r' | sed 's/^null$//'; }
actionScreenReaderOn() {
    local services
    services=$(accessibilityServices)
    if [[ ":$services:" != *":$TALKBACK_SERVICE:"* ]]; then
        services="${services:+$services:}$TALKBACK_SERVICE"
    fi
    adb shell settings put secure enabled_accessibility_services "$services" > /dev/null 2>&1
    adb shell settings put secure accessibility_enabled 1 > /dev/null 2>&1
}
# Only removes TalkBack, other accessibility services stay enabled
actionScreenReaderOff() {
    local services
    services=$(accessibilityServices | tr ':' '\n' | grep -vxF "$TALKBACK_SERVICE" | paste -sd: -)
    if [ -n "$services" ]; then
        adb shell settings put secure enabled_accessibility_services "$services" > /dev/null 2>&1
    else
        adb shell settings delete secure enabled_accessibility_services > /dev/null 2>&1
        adb shell settings put secure accessibility_enabled 0 > /dev/null 2>&1
    fi
}
statusScreenReader() { onOff [ "$(accessibilityServices | tr ':' '\n' | grep -cxF "$TALKBACK_SERVICE")" -gt 0 ]; }
actionScreenReaderNavigate() {
    clear
    logInfo "Screen Reader Navigation Mode"
    echo
    logIndent "Arrow keys: Navigate (↑ up, ↓ down, ← left, → right)"
    logIndent "Space/Enter: Activate current item"
    logIndent "Tab: Move to next item"
    logIndent "b: Back button"
    logIndent "+: Volume up"
    logIndent "-: Volume down"
    logIndent "q: Quit navigation mode"
    echo

    # Send initial tab to start accessibility focus if nothing is focused
    adb shell input keyevent 61 > /dev/null 2>&1

    while true; do
        read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')  # ESC sequence for arrow keys
                read -rsn2 key < /dev/tty
                case "$key" in
                    '[A') adb shell input keyevent 19 ;;  # DPAD_UP
                    '[B') adb shell input keyevent 20 ;;  # DPAD_DOWN
                    '[C') adb shell input keyevent 22 ;;  # DPAD_RIGHT
                    '[D') adb shell input keyevent 21 ;;  # DPAD_LEFT
                esac
                ;;
            ' '|'') adb shell input keyevent 23 ;;  # DPAD_CENTER (Enter/Activate)
            $'\t') adb shell input keyevent 61 ;;   # TAB
            'b'|'B') adb shell input keyevent 4 ;;  # BACK button
            '=') adb shell input keyevent 24 ;;     # VOLUME_UP
            '-') adb shell input keyevent 25 ;;     # VOLUME_DOWN
            'q'|'Q') break ;;
        esac
    done
}
actionOpenFireTVDevTools() { adb shell am start com.amazon.ssm/com.amazon.ssm.ControlPanel > /dev/null 2>&1; }
actionSetSystemDate() { adb shell "date $(date +%m%d%H%M%G.%S) ; am broadcast -a android.intent.action.TIME_SET";}
actionOpenDateSettings() { adb shell am start -a android.settings.DATE_SETTINGS; }
actionRestartDevice() { adb reboot; }

## Wireless Debugging Actions
actionWifiSwitch() {
    local ip interface output
    clear
    ip=$(adb shell ip -f inet addr show wlan0 2>/dev/null | tr -d '\r' | awk '/inet / { sub(/\/.*/, "", $2); print $2; exit }')
    if [ -z "$ip" ]; then
        logFail "The device is not connected to Wi-Fi."
        waitForEnter
        return
    fi
    # A route through a VPN tunnel means the phone is not on this computer's network
    interface=$(route -n get "$ip" 2>/dev/null | awk '/interface:/ { print $2 }')
    if [[ "$interface" == utun* ]]; then
        logFail "The device ($ip) is only reachable through this computer's VPN ($interface)."
        logIndent "Wireless debugging needs the device and this computer on the same network without a VPN in between."
        waitForEnter
        return
    fi
    logTask "Switching $ip to wireless debugging..."
    adb tcpip 5555 > /dev/null
    sleep 2
    output=$(adb connect "$ip:5555")
    # adb connect exits 0 even when it fails
    if [[ "$output" == *"connected to"* ]]; then
        export ANDROID_SERIAL="$ip:5555"
        logDone "Connected to $ip:5555, you can unplug the cable."
        offerSaveDevice "$ip:5555"
    else
        logFail "$output"
        # Don't leave the device listening on the network
        adb usb > /dev/null 2>&1
        logIndent "The device was switched back to USB. Are the device and this computer on the same network?"
    fi
    waitForEnter
}
actionWifiConnect() {
    local address output
    clear
    address=$(prompt "Device address (IP:port from Developer options > Wireless debugging)" "192.168.1.23:5555")
    [ -z "$address" ] && return
    output=$(adb connect "$address")
    if [[ "$output" == *"connected to"* ]]; then
        export ANDROID_SERIAL="$address"
        logDone "$output"
        offerSaveDevice "$address"
    else
        logFail "$output"
    fi
    waitForEnter
}
# Connects a saved device, only stops to show an error
actionQuickConnect() {
    local output
    output=$(adb connect "$1")
    if [[ "$output" == *"connected to"* ]]; then
        export ANDROID_SERIAL="$1"
        return
    fi
    clear
    logFail "$output"
    logIndent "Is wireless debugging still on and does the device still have this address?"
    waitForEnter
}
# Asks for a name to remember a newly connected device for Quick Connect
offerSaveDevice() {
    local name
    [ -n "$(savedDeviceName "$1")" ] && return
    echo
    name=$(prompt "Save for Quick Connect? Enter a name, or leave empty to skip" "$(adb -s "$1" shell getprop ro.product.model | tr -d '\r')")
    name="${name//|/}"
    [ -z "$name" ] && return
    ADBUTIL_SAVED_DEVICES+=("$name|$1")
    writeSavedDevices && logDone "Saved \"$name\" for Quick Connect."
}
actionWifiPair() {
    local address code
    clear
    address=$(prompt "Pairing address (Wireless debugging > Pair device with pairing code)" "192.168.1.23:37123")
    [ -z "$address" ] && return
    code=$(prompt "Pairing code" "123456")
    [ -z "$code" ] && return
    adb pair "$address" "$code"
    logInfo "After pairing, use Connect New Device with the IP address & port shown on the Wireless debugging screen."
    waitForEnter
}

## Project Menus
# Every menu loops until Back, keeping the last selected option highlighted.

menuProjects() {
    local last="" choice entry title names
    while isDeviceConnected; do
        clear
        names=()
        for entry in "${ADBUTIL_PROJECTS[@]}"; do names+=("${entry%%|*}"); done
        title="$MENU_PROJECTS"
        [ ${#names[@]} -eq 0 ] && title="$MENU_PROJECTS (add projects to $ADBUTIL_CONFIG)"
        choice=$(menu "$title" "$last" "${names[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_BACK"|"") return ;;
            *) menuProject "$choice" ;;
        esac
    done
}

# Shows the project menu (no app installed), the app menu (one app) or the app list (multiple apps)
menuProject() {
    local project="$1" last="" choice entry title
    title="📁 $project"
    loadProjectItems "$project"
    for entry in "${ADBUTIL_PROJECTS[@]}"; do
        if [ "${entry%%|*}" == "$project" ] && [ "$entry" != "$project" ]; then
            title+=" (Not Installed)"
        fi
    done
    while isDeviceConnected; do
        clear
        loadProjectPackages "$project"
        case ${#PROJECT_PACKAGES[@]} in
            0)
                choice=$(menu "$title" "$last" "${PROJECT_ITEMS[@]}" "$MENU_REFRESH" "$MENU_BACK")
                last="$choice"
                case "$choice" in
                    "$MENU_CREDENTIALS") menuCredentials "$project" ;;
                    "$MENU_PASTE_STRINGS") menuPasteStrings "$project" ;;
                    "$MENU_DEEPLINKS") menuDeeplinks "$project" ;;
                    "$MENU_BACK"|"") return ;;
                esac
                ;;
            1)
                # Re-evaluate the project after uninstall, otherwise go back to the projects
                menuApp "$project" "${PROJECT_PACKAGES[0]}" || continue
                return
                ;;
            *)
                choice=$(menu "📁 $project" "$last" "${PROJECT_PACKAGES[@]}" "$MENU_REFRESH" "$MENU_BACK")
                last="$choice"
                case "$choice" in
                    "$MENU_REFRESH") ;;
                    "$MENU_BACK"|"") return ;;
                    *) menuApp "$project" "$choice" ;;
                esac
                ;;
        esac
    done
}

# Returns 1 if the app got uninstalled. Projects can be "|" separated when the package is in multiple projects.
menuApp() {
    local projects="$1" package="$2" last="" choice
    loadProjectItems "$projects"
    while isDeviceConnected; do
        clear
        choice=$(menu "📁 ${projects//|/ + } - $package" "$last" "$MENU_CONTROL" "${PROJECT_ITEMS[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_CREDENTIALS") menuCredentials "$projects" ;;
            "$MENU_PASTE_STRINGS") menuPasteStrings "$projects" ;;
            "$MENU_DEEPLINKS") menuDeeplinks "$projects" ;;
            "$MENU_CONTROL") menuControl "$package" "$MENU_CONTROL - $package" || return 1 ;;
            "$MENU_BACK"|"") return 0 ;;
        esac
    done
    return 0
}

# Returns 1 if the app got uninstalled
menuControl() {
    local package="$1" title="$2" last="" choice items
    items=("$MENU_LAUNCH" "$MENU_FORCE_STOP" "$MENU_HOME" "$MENU_CLEAR_DATA" "$MENU_UNINSTALL")
    # Per-app languages exist since Android 13 (API 33)
    [ "$(adb shell getprop ro.build.version.sdk | tr -d '\r')" -ge 33 ] 2>/dev/null && items+=("$MENU_APP_LANGUAGE")
    items+=("$MENU_INFO" "$MENU_BACK")
    while isDeviceConnected; do
        clear
        choice=$(menu "$title" "$last" "${items[@]}")
        last="$choice"
        case "$choice" in
            "$MENU_LAUNCH") adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 ;;
            "$MENU_FORCE_STOP") adb shell am force-stop "$package" ;;
            "$MENU_HOME") adb shell input keyevent 3 ;;
            "$MENU_CLEAR_DATA") adb shell pm clear "$package" ;;
            "$MENU_APP_LANGUAGE") menuAppLanguage "$package" ;;
            "$MENU_UNINSTALL") adb uninstall "$package"; return 1 ;;
            "$MENU_INFO") adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$package" > /dev/null 2>&1 ;;
            "$MENU_BACK"|"") return 0 ;;
        esac
    done
    return 0
}

menuAppLanguage() {
    local package="$1" locale entries
    entries=("$MENU_SYSTEM_DEFAULT" "actionAppLanguage $package")
    for locale in "${ADBUTIL_APP_LOCALES[@]}"; do
        entries+=("$locale" "actionAppLanguage $package $locale")
    done
    menuList -s "statusAppLanguage $package" "$MENU_APP_LANGUAGE - $package" "${entries[@]}"
}

menuCredentials() {
    local project="$1" last="" choice entry title titles=() creds=()
    loadProjectEntries "$project" "${ADBUTIL_CREDENTIALS[@]}"
    creds=("${PROJECT_ENTRIES[@]}")
    for entry in "${creds[@]}"; do titles+=("${entry%%|*}"); done
    title="$MENU_CREDENTIALS - ${project//|/ + }"
    while true; do
        clear
        choice=$(menu "$title" "$last" "${titles[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_BACK"|"") return ;;
        esac
        for entry in "${creds[@]}"; do
            if [ "${entry%%|*}" == "$choice" ]; then
                menuCredential "$entry"
                break
            fi
        done
    done
}

menuCredential() {
    local title user pass last="" choice
    local MENU_USERNAME="👤 Username"
    local MENU_PASSWORD="🔑 Password"
    IFS='|' read -r title user pass <<< "$1"
    while true; do
        clear
        choice=$(menu "🔐 $title" "$last" "$MENU_USERNAME: $user" "$MENU_TAB" "$MENU_PASSWORD: $pass" "$MENU_ENTER" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_USERNAME: $user") actionInputText "$user" ;;
            "$MENU_TAB") actionTabKey ;;
            "$MENU_PASSWORD: $pass") actionInputText "$pass" ;;
            "$MENU_ENTER") actionEnterKey ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}

menuPasteStrings() {
    local project="$1" last="" choice entry title i labels=() values=()
    loadProjectEntries "$project" "${ADBUTIL_PASTE_STRINGS[@]}"
    for entry in "${PROJECT_ENTRIES[@]}"; do
        labels+=("${entry%%|*}: ${entry#*|}")
        values+=("${entry#*|}")
    done
    title="$MENU_PASTE_STRINGS - ${project//|/ + }"
    while true; do
        clear
        choice=$(menu "$title" "$last" "${labels[@]}" "$MENU_TAB" "$MENU_ENTER" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_TAB") actionTabKey; continue ;;
            "$MENU_ENTER") actionEnterKey; continue ;;
            "$MENU_BACK"|"") return ;;
        esac
        for i in "${!labels[@]}"; do
            if [ "${labels[$i]}" == "$choice" ]; then
                actionInputText "${values[$i]}"
                break
            fi
        done
    done
}

menuDeeplinks() {
    local project="$1" last="" choice entry title i names=() links=()
    loadProjectEntries "$project" "${ADBUTIL_DEEPLINKS[@]}"
    for entry in "${PROJECT_ENTRIES[@]}"; do
        names+=("${entry%%|*}")
        links+=("${entry#*|}")
    done
    title="$MENU_DEEPLINKS - ${project//|/ + }"
    while true; do
        clear
        choice=$(menu "$title" "$last" "${names[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_BACK"|"") return ;;
        esac
        for i in "${!names[@]}"; do
            if [ "${names[$i]}" == "$choice" ]; then
                actionOpenDeeplink "${links[$i]}"
                break
            fi
        done
    done
}

menuAllPackages() {
    local last="" choice packages
    while isDeviceConnected; do
        clear
        IFS=$'\n' read -r -d '' -a packages < <(installedPackages)
        choice=$(menu "$MENU_ALL_PACKAGES" "$last" "${packages[@]}" "$MENU_REFRESH" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_REFRESH") ;;
            "$MENU_BACK"|"") return ;;
            *)
                loadPackageProjects "$choice"
                if [ -n "$PACKAGE_PROJECTS" ]; then
                    menuApp "$PACKAGE_PROJECTS" "$choice"
                else
                    menuControl "$choice" "📦 $choice"
                fi
                ;;
        esac
    done
}

## Device Tool Menus
menuDeviceTools() {
    menuList "$MENU_DEVICE_TOOLS" \
        "$MENU_CAPTURE" menuCapture \
        "$MENU_DISPLAY" menuDisplay \
        "$MENU_DEBUG" menuDebug \
        "$MENU_SYSTEM" menuSystem \
        "$MENU_ALL_PACKAGES" menuAllPackages
}
menuCapture() {
    menuList "$MENU_CAPTURE" \
        "$MENU_SCREENSHOT" actionScreenshot \
        "$MENU_SCREEN_RECORD" actionScreenRecord \
        "$MENU_SHOW_TAPS" menuShowTaps \
        "$MENU_DEMO_MODE" menuDemoMode
}
menuDisplay() {
    menuList "$MENU_DISPLAY" \
        "$MENU_DARK_MODE" menuDarkMode \
        "$MENU_FONT_SIZE" menuFontSize \
        "$MENU_DISPLAY_SIZE" menuDisplaySize \
        "$MENU_SCREEN_READER" menuScreenReader
}
menuSystem() {
    local entries=(
        "$MENU_LANGUAGE" actionOpenLanguageSettings
        "$MENU_SYNC_TIME" menuSyncTime
        "$MENU_MEDIA_SESSION" menuMediaSession
        "$MENU_DEVICE_INFO" menuDeviceInfo
    )
    if [ "$(adb shell getprop ro.product.manufacturer | tr -d '\r')" == "Amazon" ]; then
        entries+=("$MENU_FIRE_TV_DEV_TOOLS" actionOpenFireTVDevTools)
    fi
    menuList "$MENU_SYSTEM" "${entries[@]}"
}
menuDarkMode() { menuToggle "$MENU_DARK_MODE" statusDarkMode "actionDarkMode yes" "actionDarkMode no"; }
menuFontSize() {
    menuList -s statusFontSize "$MENU_FONT_SIZE" \
        "Small (85%)" "actionFontScale 0.85" \
        "Default (100%)" "actionFontScale 1.0" \
        "Large (115%)" "actionFontScale 1.15" \
        "Larger (130%)" "actionFontScale 1.3" \
        "Largest (150%)" "actionFontScale 1.5" \
        "Huge (200%, Android 14+)" "actionFontScale 2.0"
}
menuDisplaySize() {
    menuList -s statusDisplaySize "$MENU_DISPLAY_SIZE" \
        "Small (85%)" "actionDisplaySize 0.85" \
        "Default" "actionDisplaySize reset" \
        "Large (115%)" "actionDisplaySize 1.15" \
        "Larger (130%)" "actionDisplaySize 1.3"
}
menuDebug() {
    menuList "$MENU_DEBUG" \
        "$MENU_LAYOUT_BOUNDS" menuLayoutBounds \
        "$MENU_SHOW_TAPS" menuShowTaps \
        "$MENU_POINTER_LOCATION" menuPointerLocation \
        "$MENU_ANIMATIONS" menuAnimations \
        "$MENU_PROXY" menuProxy
}
menuLayoutBounds() { menuToggle "$MENU_LAYOUT_BOUNDS" statusLayoutBounds "actionLayoutBounds true" "actionLayoutBounds false"; }
menuShowTaps() { menuToggle "$MENU_SHOW_TAPS" statusShowTaps "actionShowTaps 1" "actionShowTaps 0"; }
menuPointerLocation() { menuToggle "$MENU_POINTER_LOCATION" statusPointerLocation "actionPointerLocation 1" "actionPointerLocation 0"; }
menuAnimations() { menuToggle "$MENU_ANIMATIONS" statusAnimations "actionAnimations 1" "actionAnimations 0"; }
menuProxy() { menuToggle "$MENU_PROXY" statusProxy actionProxyOn actionProxyOff; }
menuDemoMode() { menuToggle "$MENU_DEMO_MODE" statusDemoMode "actionDemoMode true" "actionDemoMode false"; }
menuScreenReader() { menuToggle "$MENU_SCREEN_READER" statusScreenReader actionScreenReaderOn actionScreenReaderOff "$MENU_NAVIGATE" actionScreenReaderNavigate; }
menuMediaSession() {
    menuList "$MENU_MEDIA_SESSION" \
        "⏯️ Play/Pause" "actionMediaSession play-pause" \
        "▶️ Play" "actionMediaSession play" \
        "⏸️ Pause" "actionMediaSession pause" \
        "⏩ Fast Forward" "actionMediaSession fast-forward" \
        "⏪ Rewind" "actionMediaSession rewind" \
        "$MENU_INFO" actionMediaSessionInfo
}
menuSyncTime() {
    menuList "$MENU_SYNC_TIME" \
        "🕒 Sync time automatically (needs root)" actionSetSystemDate \
        "$MENU_OPEN_SETTINGS" actionOpenDateSettings \
        "🔄 Restart device" actionRestartDevice
}
# Device manager: select, connect, disconnect and remember devices
menuDevices() {
    local last="" choice title items device wifiCount
    while true; do
        clear
        selectDefaultDevice
        wifiCount=0
        for device in "${DEVICES[@]}"; do [[ "${device%%|*}" == *:* ]] && wifiCount=$((wifiCount + 1)); done
        items=()
        [ ${#DEVICES[@]} -gt 1 ] && items+=("$MENU_SELECT_DEVICE")
        [ ${#ADBUTIL_SAVED_DEVICES[@]} -gt 0 ] && items+=("$MENU_QUICK_CONNECT")
        items+=("$MENU_WIFI_CONNECT" "$MENU_WIFI_PAIR")
        # Switching only makes sense for a USB device, Wi-Fi serials are IP:port
        [ -n "$ANDROID_SERIAL" ] && [[ "$ANDROID_SERIAL" != *:* ]] && items+=("$MENU_WIFI_SWITCH")
        [ "$wifiCount" -gt 0 ] && items+=("$MENU_WIFI_DISCONNECT")
        [ ${#ADBUTIL_SAVED_DEVICES[@]} -gt 0 ] && items+=("$MENU_FORGET_DEVICE")
        if [ -n "$ANDROID_SERIAL" ]; then
            title="$MENU_DEVICES - $(deviceLabel "$ANDROID_SERIAL")"
        else
            title="$MENU_DEVICES - ${#DEVICES[@]} connected, none selected"
        fi
        choice=$(menu "$title" "$last" "${items[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_SELECT_DEVICE") menuSelectDevice ;;
            "$MENU_QUICK_CONNECT") menuQuickConnect ;;
            "$MENU_WIFI_CONNECT") actionWifiConnect ;;
            "$MENU_WIFI_PAIR") actionWifiPair ;;
            "$MENU_WIFI_SWITCH") actionWifiSwitch ;;
            "$MENU_WIFI_DISCONNECT") menuDisconnect ;;
            "$MENU_FORGET_DEVICE") menuForgetDevice ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
# Sets SAVED_DEVICE_LABELS to "Name (address)" of the saved devices, in the same order
loadSavedDeviceLabels() {
    local device
    SAVED_DEVICE_LABELS=()
    for device in "${ADBUTIL_SAVED_DEVICES[@]}"; do SAVED_DEVICE_LABELS+=("${device%%|*} (${device#*|})"); done
}
menuQuickConnect() {
    local choice i
    loadSavedDeviceLabels
    clear
    choice=$(menu "$MENU_QUICK_CONNECT" "" "${SAVED_DEVICE_LABELS[@]}" "$MENU_BACK")
    for i in "${!SAVED_DEVICE_LABELS[@]}"; do
        [ "${SAVED_DEVICE_LABELS[$i]}" == "$choice" ] && actionQuickConnect "${ADBUTIL_SAVED_DEVICES[$i]#*|}"
    done
}
menuDisconnect() {
    local choice device labels=()
    for device in "${DEVICES[@]}"; do
        [[ "${device%%|*}" == *:* ]] && labels+=("$(deviceLabel "${device%%|*}")")
    done
    clear
    choice=$(menu "$MENU_WIFI_DISCONNECT" "" "${labels[@]}" "$MENU_ALL_WIFI_DEVICES" "$MENU_BACK")
    if [ "$choice" == "$MENU_ALL_WIFI_DEVICES" ]; then
        adb disconnect > /dev/null 2>&1
        return
    fi
    for device in "${DEVICES[@]}"; do
        [ "$(deviceLabel "${device%%|*}")" == "$choice" ] && adb disconnect "${device%%|*}" > /dev/null 2>&1
    done
}
menuForgetDevice() {
    local choice i kept=()
    loadSavedDeviceLabels
    clear
    choice=$(menu "$MENU_FORGET_DEVICE" "" "${SAVED_DEVICE_LABELS[@]}" "$MENU_BACK")
    for i in "${!SAVED_DEVICE_LABELS[@]}"; do
        [ "${SAVED_DEVICE_LABELS[$i]}" != "$choice" ] && kept+=("${ADBUTIL_SAVED_DEVICES[$i]}")
    done
    if [ ${#kept[@]} -ne ${#ADBUTIL_SAVED_DEVICES[@]} ]; then
        ADBUTIL_SAVED_DEVICES=("${kept[@]}")
        writeSavedDevices
    fi
}
menuSettings() {
    menuList -n "$MENU_SETTINGS" \
        "$MENU_DEVICES" menuDevices \
        "$MENU_EDIT_CONFIG" actionEditConfig
}
# Opens the config in the terminal editor and reloads it when the editor closes
actionEditConfig() {
    # shellcheck disable=SC2086 # EDITOR may contain arguments, e.g. "code --wait"
    ${VISUAL:-${EDITOR:-nano}} "$ADBUTIL_CONFIG" < /dev/tty
    # shellcheck source=/dev/null
    if [ -n "$(bash -n "$ADBUTIL_CONFIG" 2>&1)" ] || ! source "$ADBUTIL_CONFIG"; then
        clear
        logFail "Your config file has a syntax error: $ADBUTIL_CONFIG"
        logIndent "Fix it with Edit Config, otherwise adbutil won't start next time."
        waitForEnter
    fi
}
menuDeviceInfo() {
    local i value keys labels
    clear
    echo -e "${BRIGHT_BLUE}Device information:${NC}"
    echo

    keys=(
        "ro.product.manufacturer"
        "ro.product.model"
        "ro.product.device"
        "ro.build.version.release"
        "ro.build.version.sdk"
        "ro.build.id"
        "ro.build.version.security_patch"
        "ro.build.fingerprint"
        "ro.serialno"
    )

    labels=(
        "Manufacturer"
        "Model"
        "Device Codename"
        "Android Version"
        "API Level"
        "Build ID"
        "Security Patch"
        "Build Fingerprint"
        "Serial Number"
    )

    for i in "${!keys[@]}"; do
        value=$(adb shell getprop "${keys[$i]}" | tr -d '[]')
        printf "%b%-22s%b: %b%s%b\n" \
            "$BOLD" "${labels[$i]}" "$NC" \
            "$BRIGHT_GREEN" "$value" "$NC"
    done

    echo
    waitForEnter
}

## Main Menu
menuSelectDevice() {
    local device choice labels=()
    loadDevices
    for device in "${DEVICES[@]}"; do labels+=("$(deviceLabel "${device%%|*}")"); done
    clear
    choice=$(menu "$MENU_SELECT_DEVICE" "$(deviceLabel "$ANDROID_SERIAL")" "${labels[@]}" "$MENU_BACK")
    for device in "${DEVICES[@]}"; do
        [ "$(deviceLabel "${device%%|*}")" == "$choice" ] && export ANDROID_SERIAL="${device%%|*}"
    done
}

menuMain() {
    local last="" choice menuItems title
    while true; do
        clear
        selectDefaultDevice
        menuItems=()
        REMOTE_VERSION=$(cat "$REMOTE_VERSION_CACHE" 2>/dev/null)
        MENU_UPDATE="📥 Update adbutil ($LOCAL_VERSION -> $REMOTE_VERSION)"
        if ! $ADBUTIL_SKIP_ASK_INSTALL && ! isCommandExist adbutil; then
            menuItems+=("$MENU_INSTALL")
        elif ! $ADBUTIL_SKIP_ASK_UPDATE && [ -n "$REMOTE_VERSION" ] && isNewerVersion "$REMOTE_VERSION" "$LOCAL_VERSION"; then
            menuItems+=("$MENU_UPDATE")
        fi
        if [ -n "$ANDROID_SERIAL" ]; then
            title="📱 $(deviceLabel "$ANDROID_SERIAL")"
            menuItems+=("$MENU_PROJECTS" "$MENU_DEVICE_TOOLS")
        elif [ ${#DEVICES[@]} -gt 1 ]; then
            title="📱 ${#DEVICES[@]} devices connected, select one"
        elif [ "$DEVICES_UNAUTHORIZED" -gt 0 ]; then
            title="⚠️ Device unauthorized, accept the USB debugging prompt on the device"
            menuItems+=("$MENU_REFRESH")
        else
            title="⚠️ No device connected"
            menuItems+=("$MENU_REFRESH")
        fi
        [ ${#DEVICES[@]} -gt 1 ] && menuItems+=("$MENU_SELECT_DEVICE")
        [ -z "$ANDROID_SERIAL" ] && [ ${#ADBUTIL_SAVED_DEVICES[@]} -gt 0 ] && menuItems+=("$MENU_QUICK_CONNECT")
        menuItems+=("$MENU_SETTINGS" "$MENU_EXIT")
        choice=$(menu "$title" "$last" "${menuItems[@]}")
        last="$choice"
        case "$choice" in
            "$MENU_INSTALL") download "install" ;;
            "$MENU_UPDATE") download "update" ;;
            "$MENU_PROJECTS") menuProjects ;;
            "$MENU_DEVICE_TOOLS") menuDeviceTools ;;
            "$MENU_SELECT_DEVICE") menuSelectDevice ;;
            "$MENU_QUICK_CONNECT") menuQuickConnect ;;
            "$MENU_SETTINGS") menuSettings ;;
            "$MENU_EXIT"|"") exit 0 ;;
        esac
    done
}

# Start the main menu
menuMain
