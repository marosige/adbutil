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
REMOTE_VERSION=$(curl -s -L --max-time 3 "$DOWNLOAD_URL" | grep -Eo 'LOCAL_VERSION="[0-9.]+"' | cut -d '"' -f 2)

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
    read -r
}

## Configuration
ADBUTIL_CONFIG="$HOME/.adbutil"
ADBUTIL_CONFIG_SUPPORTED_VERSION=2
if [ -f "$ADBUTIL_CONFIG" ]; then
    # A config that fails to load would be rewritten with empty values, so stop instead.
    # bash 3.2 "bash -n" exits 0 on some syntax errors, so its output is checked too.
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
} > "$1"
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

# Write to a temp file first, so an interrupted write can't leave a half written config
writeConfig "$ADBUTIL_CONFIG.tmp" && mv "$ADBUTIL_CONFIG.tmp" "$ADBUTIL_CONFIG"

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

    # Download and install adbutil
    if curl -s -L -o "$DOWNLOAD_LOCATION" "$DOWNLOAD_URL"; then
        chmod +x "$DOWNLOAD_LOCATION"
        logDone "adbutil $action succeed."
    else
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
        done
    fi
}

### ADB Utility

## Constants
MENU_INSTALL="📥 Install adbutil"
MENU_UPDATE="📥 Update adbutil ($LOCAL_VERSION -> $REMOTE_VERSION)"
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
MENU_PROXY="🌐 Proxy"
MENU_DEMO_MODE="📸 Demo Mode"
MENU_MEDIA_SESSION="🎬 Media Session"
MENU_SCREEN_READER="📖 Screen Reader"
MENU_FIRE_TV_DEV_TOOLS="🔧 Fire TV Dev Tools"
MENU_SYNC_TIME="⏱️  Sync Time"
MENU_DEVICE_INFO="ℹ️ Device Info"
MENU_REFRESH="🔄 Refresh"
MENU_EXIT="🚪 Exit"
MENU_BACK="↩️ Back"
MENU_ON="🟢 Enable"
MENU_OFF="🔴 Disable"
MENU_INFO="ℹ️ Info"
MENU_OPEN_SETTINGS="⚙️ Open settings screen"

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
actionOpenDeeplink() {
    if [[ "$1" =~ ^https?:// ]]; then
        adb shell am start -a android.intent.action.VIEW -d "$1"
    else
        adb shell am start -a "$1"
    fi
}
actionLayoutBounds() { adb shell setprop debug.layout "$1"; adb shell service call activity 1599295570 > /dev/null 2>&1; }
actionProxyOn() { adb shell settings put global http_proxy "$(ipconfig getifaddr en0):8888"; }
actionProxyOff() { adb shell settings put global http_proxy :0; }
actionProxyStatus() {
    local proxy
    clear
    proxy=$(adb shell settings get global http_proxy)
    if [ -z "$proxy" ] || [ "$proxy" == "null" ] || [ "$proxy" == ":0" ]; then
        logInfo "Proxy is not set"
    else
        logInfo "Proxy set to: $proxy"
    fi
    waitForEnter
}
actionMediaSession() { adb shell input keyevent "$1"; }
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
actionScreenReaderOn() { adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService > /dev/null 2>&1; adb shell settings put secure accessibility_enabled 1 > /dev/null 2>&1; }
actionScreenReaderOff() { adb shell settings put secure enabled_accessibility_services null > /dev/null 2>&1; adb shell settings put secure accessibility_enabled 0 > /dev/null 2>&1; }
actionScreenReaderStatus() {
    local enabled services
    clear
    enabled=$(adb shell settings get secure accessibility_enabled)
    services=$(adb shell settings get secure enabled_accessibility_services)
    if [ "$enabled" = "1" ] && [ -n "$services" ] && [ "$services" != "null" ]; then
        logInfo "Screen Reader is enabled"
        logIndent "Services: $services"
    else
        logInfo "Screen Reader is disabled"
    fi
    waitForEnter
}
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
        read -rsn1 key
        case "$key" in
            $'\x1b')  # ESC sequence for arrow keys
                read -rsn2 key
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

## Project Menus
# Every menu loops until Back, keeping the last selected option highlighted.

menuProjects() {
    local last="" choice entry title names
    while true; do
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
    local project="$1" last="" choice entry title="📁 $project"
    loadProjectItems "$project"
    for entry in "${ADBUTIL_PROJECTS[@]}"; do
        if [ "${entry%%|*}" == "$project" ] && [ "$entry" != "$project" ]; then
            title+=" (Not Installed)"
        fi
    done
    while true; do
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
    while true; do
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
}

# Returns 1 if the app got uninstalled
menuControl() {
    local package="$1" title="$2" last="" choice
    while true; do
        clear
        choice=$(menu "$title" "$last" "$MENU_LAUNCH" "$MENU_FORCE_STOP" "$MENU_HOME" "$MENU_CLEAR_DATA" "$MENU_UNINSTALL" "$MENU_INFO" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_LAUNCH") adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 ;;
            "$MENU_FORCE_STOP") adb shell am force-stop "$package" ;;
            "$MENU_HOME") adb shell input keyevent 3 ;;
            "$MENU_CLEAR_DATA") adb shell pm clear "$package" ;;
            "$MENU_UNINSTALL") adb uninstall "$package"; return 1 ;;
            "$MENU_INFO") adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$package" > /dev/null 2>&1 ;;
            "$MENU_BACK"|"") return 0 ;;
        esac
    done
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
    local MENU_TAB=" ⇥ Tab Key"
    local MENU_PASSWORD="🔑 Password"
    local MENU_ENTER=" ⏎ Enter Key"
    IFS='|' read -r title user pass <<< "$1"
    while true; do
        clear
        choice=$(menu "🔐 $title" "$last" "$MENU_USERNAME: $user" "$MENU_TAB" "$MENU_PASSWORD: $pass" "$MENU_ENTER" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_USERNAME: $user") actionInputText "$user" ;;
            "$MENU_TAB") adb shell input keyevent 61 ;;   # 61 is KEYCODE_TAB
            "$MENU_PASSWORD: $pass") actionInputText "$pass" ;;
            "$MENU_ENTER") adb shell input keyevent 66 ;; # 66 is KEYCODE_ENTER
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
        choice=$(menu "$title" "$last" "${labels[@]}" "$MENU_BACK")
        last="$choice"
        case "$choice" in
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
    while true; do
        clear
        packages=($(installedPackages))
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
    local last="" choice
    while true; do
        clear
        choice=$(menu "$MENU_DEVICE_TOOLS" "$last" \
            "$MENU_LAYOUT_BOUNDS" \
            "$MENU_SCREEN_READER" \
            "$MENU_PROXY" \
            "$MENU_DEMO_MODE" \
            "$MENU_MEDIA_SESSION" \
            "$MENU_FIRE_TV_DEV_TOOLS" \
            "$MENU_SYNC_TIME" \
            "$MENU_DEVICE_INFO" \
            "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_LAYOUT_BOUNDS") menuLayoutBounds ;;
            "$MENU_SCREEN_READER") menuScreenReader ;;
            "$MENU_PROXY") menuProxy ;;
            "$MENU_DEMO_MODE") menuDemoMode ;;
            "$MENU_MEDIA_SESSION") menuMediaSession ;;
            "$MENU_FIRE_TV_DEV_TOOLS") menuFireTVDevTools ;;
            "$MENU_SYNC_TIME") menuSyncTime ;;
            "$MENU_DEVICE_INFO") menuDeviceInfo ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuLayoutBounds() {
    local last="" choice
    while true; do
        clear
        choice=$(menu "$MENU_LAYOUT_BOUNDS" "$last" "$MENU_ON" "$MENU_OFF" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_ON") actionLayoutBounds "true" ;;
            "$MENU_OFF") actionLayoutBounds "false" ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuProxy() {
    local last="" choice
    while true; do
        clear
        choice=$(menu "$MENU_PROXY" "$last" "$MENU_ON" "$MENU_OFF" "$MENU_INFO" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_ON") actionProxyOn ;;
            "$MENU_OFF") actionProxyOff ;;
            "$MENU_INFO") actionProxyStatus ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuDemoMode() {
    local last="" choice
    while true; do
        clear
        choice=$(menu "$MENU_DEMO_MODE" "$last" "$MENU_ON" "$MENU_OFF" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_ON") actionDemoMode true ;;
            "$MENU_OFF") actionDemoMode false ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuMediaSession() {
    local last="" choice
    local MENU_MEDIA_PLAY_PAUSE="⏯️ play-pause"
    local MENU_MEDIA_PLAY="▶️ play"
    local MENU_MEDIA_PAUSE="⏸️ pause"
    local MENU_MEDIA_FF="⏩ fast-forward"
    local MENU_MEDIA_RW="⏪ rewind"
    while true; do
        clear
        choice=$(menu "$MENU_MEDIA_SESSION" "$last" "$MENU_MEDIA_PLAY_PAUSE" "$MENU_MEDIA_PLAY" "$MENU_MEDIA_PAUSE" "$MENU_MEDIA_FF" "$MENU_MEDIA_RW" "$MENU_INFO" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_BACK"|"") return ;;
            "$MENU_INFO") adb shell dumpsys media_session ;;
            *)
                # Remove emoji and whitespace before passing to actionMediaSession
                actionMediaSession "$(echo "$choice" | sed -E 's/^[^ ]+ //')"
            ;;
        esac
    done
}
menuScreenReader() {
    local last="" choice
    local MENU_NAVIGATE="🧭 Navigate"
    while true; do
        clear
        choice=$(menu "$MENU_SCREEN_READER" "$last" "$MENU_ON" "$MENU_OFF" "$MENU_NAVIGATE" "$MENU_INFO" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_ON") actionScreenReaderOn ;;
            "$MENU_OFF") actionScreenReaderOff ;;
            "$MENU_NAVIGATE") actionScreenReaderNavigate ;;
            "$MENU_INFO") actionScreenReaderStatus ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuFireTVDevTools() {
    local last="" choice
    while true; do
        clear
        choice=$(menu "$MENU_FIRE_TV_DEV_TOOLS" "$last" "$MENU_OPEN_SETTINGS" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_OPEN_SETTINGS") actionOpenFireTVDevTools ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
}
menuSyncTime() {
    local last="" choice
    local MENU_SYNC_TIME_AUTO="🕒 Sync time automatically (needs root)"
    local MENU_SYNC_TIME_RESTART="🔄 Restart device"
    while true; do
        clear
        choice=$(menu "$MENU_SYNC_TIME" "$last" "$MENU_SYNC_TIME_AUTO" "$MENU_OPEN_SETTINGS" "$MENU_SYNC_TIME_RESTART" "$MENU_BACK")
        last="$choice"
        case "$choice" in
            "$MENU_SYNC_TIME_AUTO") actionSetSystemDate ;;
            "$MENU_OPEN_SETTINGS") actionOpenDateSettings ;;
            "$MENU_SYNC_TIME_RESTART") actionRestartDevice ;;
            "$MENU_BACK"|"") return ;;
        esac
    done
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
menuMain() {
    local last="" choice menuItems
    while true; do
        clear
        menuItems=()
        if ! $ADBUTIL_SKIP_ASK_INSTALL && ! isCommandExist adbutil; then
            menuItems+=("$MENU_INSTALL")
        elif ! $ADBUTIL_SKIP_ASK_UPDATE && [ -n "$REMOTE_VERSION" ] && isNewerVersion "$REMOTE_VERSION" "$LOCAL_VERSION"; then
            menuItems+=("$MENU_UPDATE")
        fi
        menuItems+=("$MENU_PROJECTS" "$MENU_ALL_PACKAGES" "$MENU_DEVICE_TOOLS" "$MENU_EXIT")
        choice=$(menu "📱 Main menu" "$last" "${menuItems[@]}")
        last="$choice"
        case "$choice" in
            "$MENU_INSTALL") download "install" ;;
            "$MENU_UPDATE") download "update" ;;
            "$MENU_PROJECTS") menuProjects ;;
            "$MENU_ALL_PACKAGES") menuAllPackages ;;
            "$MENU_DEVICE_TOOLS") menuDeviceTools ;;
            "$MENU_EXIT"|"") exit 0 ;;
        esac
    done
}

# Start the main menu
menuMain
