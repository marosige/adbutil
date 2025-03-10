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
LOCAL_VERSION="1.0.0"
REMOTE_VERSION=$(curl -s -L $DONWLOAD_URL | grep -Eo "LOCAL_VERSION=\"[0-9.]+\"" | cut -d "\"" -f 2)

DONWLOAD_URL="https://raw.githubusercontent.com/marosige/adbutil/refs/heads/main/adbutil.sh"
DOWNLOAD_FOLDER="$HOME/bin"
DONWLOAD_LOCATION="$DOWNLOAD_FOLDER/adbutil"

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

log() { echo -e "$1 $2"; }

## Configuration
ADBUTIL_CONFIG="$HOME/.adbutil"
if [ ! -f "$ADBUTIL_CONFIG" ]; then
    cat <<EOF > "$ADBUTIL_CONFIG"
### ADB Utility Configuration
### https://github.com/marosige/adbutil

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=false
ADBUTIL_SKIP_ASK_UPDATE=false
ADBUTIL_USE_GUM=true

## Private 

# Credentials
# Format: "Title|Username|Password"
# Examples: "Admin|adminuser|password"
#           "Free user|freeuser|password"
#           "Subsciber|subuser|password"
ADBUTIL_CREDENTIALS=(
    "Set your credentials in $ADBUTIL_CONFIG config file|Username written here will be pasted on android device|Password written here will be pasted on android device"

# Strings to paste
# Format: "Category|String"
# Examples: "register|email"
#           "register|password"
#           "register|country"
#           "promocode|AAAA-1111-BBBB-2222"
#           "promocode|BBBB-3333-CCCC-4444"
ADBUTIL_PASTE_STRINGS=(
    "Set your strings to paste in $ADBUTIL_CONFIG config file|String written here will be pasted on android device")
)
EOF
    echo -e "$LOG_ADD Default config file created at $ADBUTIL_CONFIG"
else
    # Ensure all required constants are present in the config file
    declare -A default_values=(
        ["ADBUTIL_SKIP_ASK_INSTALL"]="false"
        ["ADBUTIL_SKIP_ASK_UPDATE"]="false"
        ["ADBUTIL_USE_GUM"]="true"
        ["ADBUTIL_CREDENTIALS"]="(\"Set your credentials in $ADBUTIL_CONFIG config file|Username|Password\")"
        ["ADBUTIL_PASTE_STRINGS"]="(\"Set your strings to paste in $ADBUTIL_CONFIG config file|String\")"
    )

    for key in "${!default_values[@]}"; do
        if ! grep -q "^$key=" "$ADBUTIL_CONFIG"; then
            echo "$key=${default_values[$key]}" >> "$ADBUTIL_CONFIG"
            echo -e "$LOG_ADD Added missing config key: $key with default value"
        fi
    done
fi
source "$ADBUTIL_CONFIG"

ADBUTIL_USE_GUM=${ADBUTIL_USE_GUM:=true}
ADBUTIL_SKIP_ASK_INSTALL=${ADBUTIL_SKIP_ASK_INSTALL:=false}
ADBUTIL_SKIP_ASK_UPDATE=${ADBUTIL_SKIP_ASK_UPDATE:=false}
ADBUTIL_CREDENTIALS=${ADBUTIL_CREDENTIALS:=("Set your credentials in $ADBUTIL_CONFIG config file|Username|Password")}
ADBUTIL_PASTE_STRINGS=${ADBUTIL_PASTE_STRINGS:=("Set your strings to paste in $ADBUTIL_CONFIG config file|String")}

## Dependencies
isCommandExist() { command -v "$1" &> /dev/null; }
isCommandExist adb || { log "$LOG_FAIL" "ADB is not installed. Please install it and try again."; exit 1; }
isCommandExist gum || { if $ADBUTIL_USE_GUM; then log "$LOG_WARN" "Gum is not installed. Install it for a nicer UI"; ADBUTIL_USE_GUM=false; fi; }

## Install
if ! $ADBUTIL_SKIP_ASK_INSTALL && ! isCommandExist adbutil; then
    log "$LOG_WARN" "adbutil is not installed on your system"
    read -p "Do you want to install it? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        #Create bin folder and add it to path if missing
        mkdir -p "$DOWNLOAD_FOLDER"
        [ -f "$HOME/.bashrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.bashrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.bashrc"
        [ -f "$HOME/.zshrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.zshrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.zshrc"
        [ -f "$HOME/.config/fish/config.fish" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.config/fish/config.fish" && echo "set -gx PATH \$PATH $DOWNLOAD_FOLDER" >> "$HOME/.config/fish/config.fish"

        # Download and install adbutil
        if curl -s -L -o "$DONWLOAD_LOCATION" "$DONWLOAD_URL"; then
            chmod +x "$DONWLOAD_LOCATION"
            log "$LOG_DONE" "adbutil installed successfully."
        else
            log "$LOG_FAIL" "Failed to download adbutil."
            log "$LOG_INDENT" "You can manually download it from: $DONWLOAD_URL"
            log "$LOG_INDENT" "Don't forget to make it executable and move it to your PATH."
        fi
    else
        log "$LOG_WARN" "You can disable this prompt by setting ADBUTIL_SKIP_ASK_INSTALL=true in $ADBUTIL_CONFIG"
    fi
    read -p "Press enter to continue to ADB Utility main menu."
fi

## Update
if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
    log "$LOG_WARN" "New version of adbutil is available."
    log "$LOG_INDENT" "Current version: $LOCAL_VERSION"
    log "$LOG_INDENT" "Latest version: $REMOTE_VERSION"
    read -p "Do you want to update it now? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if curl -s -L -o "$DONWLOAD_LOCATION" "$DONWLOAD_URL"; then
            chmod +x "$DONWLOAD_LOCATION"
            log "$LOG_DONE" "adbutil updated successfully."
            exec "$DONWLOAD_LOCATION" "$@"
        else
            log "$LOG_FAIL" "Failed to update adbutil."
            log "$LOG_INDENT" "You can manually update it downloading latest version from:"
            log "$LOG_INDENT" "$DONWLOAD_URL"
            log "$LOG_INDENT" "Don't forget to make it executable and move it to your PATH."
        fi
    else
        log "$LOG_WARN" "You can disable this prompt by setting ADBUTIL_SKIP_ASK_UPDATE=true in $ADBUTIL_CONFIG"
    fi
    read -p "Press enter to continue to ADB Utility main menu."
fi


## Menu
menu() {
    options=("$@")
    if [ "$ADBUTIL_USE_GUM" = "true" ]; then
        gum choose "${options[@]}"
    else
        PS3="Please select an option: "
        select choice in "${options[@]}"; do
            [ -n "$choice" ] && echo "$choice" && break
            echo -e "Invalid option. Please try again."
        done
    fi
}

### ADB Utility

## Actions
actionPackage() {
    clear; log "$LOG_TITLE" "Selected package: $1"
    case "$(menu "Launch" "Force Stop" "Uninstall" "Clear Data" "Open Info Page" "Back")" in
        "Launch") adb shell monkey -p "$1" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 ;;
        "Force Stop") adb shell am force-stop "$1" ;;
        "Uninstall") adb uninstall "$1"; menuPackages; return ;;
        "Clear Data") adb shell pm clear "$1" ;;
        "Open Info Page") adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$1" > /dev/null 2>&1 ;;
        "Back") menuPackages; return ;;
    esac
    actionPackage "$1"
}
actionCredentials() {
    clear; log "$LOG_TITLE" "Credentials for user: $1"
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title user pass <<< "$cred"
        if [ "$title" == "$1" ]; then
            case "$(menu "Username ($user)" "Password ($pass)" "Back")" in
                "Username ($user)") adb shell input text "$user" ;;
                "Password ($pass)") adb shell input text "$pass" ;;
                "Back") menuCredentials; return ;;
            esac
            break
        fi
    done
    actionCredentials "$1"
}
actionPasteString() {
    clear; log "$LOG_TITLE" "Paste string for category: $1"
    values=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category value <<< "$string"
        if [ "$category" == "$1" ]; then
            values+=("$value")
        fi
    done
    selected_value=$(menu "${values[@]}" "Back")
    case "$selected_value" in
        "Back") menuPasteStrings; return ;;
        *) adb shell input text "$selected_value" ;;
    esac
}
actionLayoutBounds() { adb shell setprop debug.layout "$1"; adb shell service call activity 1599295570 > /dev/null 2>&1; }
actionProxyOn() { adb shell settings put global http_proxy "$(ipconfig getifaddr en0):8888"; }
actionProxyOff() { adb shell settings put global http_proxy :0; }
actionProxyStatus() { 
    clear
    proxy=$(adb shell settings get global http_proxy)
    if [ -z "$proxy" ] || [ "$proxy" == "null" ] || [ "$proxy" == ":0" ]; then
        log "$LOG_INFO" "Proxy is not set"
    else
        log "$LOG_INFO" "Proxy set to: $proxy"
    fi
    read -p "Press enter to get back to menu."
}
actionMediaSession() { adb shell input keyevent "$1"; }
actionDemoMode() {
    if [ "$1" = true ]; then
        adb shell settings put global sysui_demo_allowed 1 > /dev/null 2>&1  # Enable demo mode
        adb shell am broadcast -a com.android.systemui.demo -e command enter > /dev/null 2>&1    # Enter demo mode
        adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000 > /dev/null 2>&1  # Set Clock to 10:00 (integer. For 10:00 pass 1000)
        adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 > /dev/null 2>&1  # Set wifi level to 4 (integer between 0 and 4)
        adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e level 4  > /dev/null 2>&1   # Set mobile network level to 4 (integer between 0 and 4)
        adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false > /dev/null 2>&1   # Hide notifications
    else
        adb shell am broadcast -a com.android.systemui.demo -e command exit > /dev/null 2>&1 # Exit from demo mode
        adb shell settings put global sysui_demo_allowed 0 > /dev/null 2>&1  # Disable demo mode
    fi
}
actionOpenFireTVDevTools() { adb shell am start com.amazon.ssm/com.amazon.ssm.ControlPanel > /dev/null 2>&1; }
actionSetSystemDate() { adb root ; adb shell "date $(date +%m%d%H%M%G.%S) ; am broadcast -a android.intent.action.TIME_SET";}
actionOpenDateSettings() { adb shell am start -a android.settings.DATE_SETTINGS; }
actionRestartDevice() { adb reboot; }

## Menus
menuPackages() {
    clear; log "$LOG_TITLE" "Third party packages:"
    packages=($(adb shell cmd package list packages -3 | cut -f 2 -d ":"))  # cut "package:" from "package:com.android.bluetooth"
    sortedPackages=($(echo "${packages[@]}" | tr ' ' '\n' | sort))
    options=("Refresh" "${sortedPackages[@]}" "Back")
    selected_option=$(menu "${options[@]}")
    case "$selected_option" in
        "Refresh") menuPackages ;;
        "Back") menuMain ;;
        *) actionPackage "$selected_option" ;;
    esac
}
menuCredentials() {
    clear; log "$LOG_TITLE" "Credentials:"
    titles=()
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title _ _ <<< "$cred"
        titles+=("$title")
    done
    selected_option=$(menu "${titles[@]}" "Back")
    case "$selected_option" in
        "Back") menuMain; return ;;
        *)
            actionCredentials "$selected_option"
        ;;
    esac
    menuCredentials
}
menuPasteStrings() {
    clear; log "$LOG_TITLE" "Paste strings:"
    categories=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category _ <<< "$string"
        categories+=("$category")
    done
    selected_option=$(menu "${categories[@]}" "Back")
    case "$selected_option" in
        "Back") menuMain; return ;;
        *)
            actionPasteString "$selected_option"
        ;;
    esac
    menuPasteStrings
}
menuLayoutBounds() {
    clear; log "$LOG_TITLE" "Layout bounds:"
    case "$(menu "On" "Off" "Back")" in
        "On") actionLayoutBounds "true" ;;
        "Off") actionLayoutBounds "false" ;;
        "Back") menuMain; return ;;
    esac
    menuLayoutBounds
}
menuProxy() {
    clear; log "$LOG_TITLE" "Proxy:"
    case "$(menu "On" "Off" "Status" "Back")" in
        "On") actionProxyOn ;;
        "Off") actionProxyOff ;;
        "Status") actionProxyStatus ;;
        "Back") menuMain; return ;;
    esac
    menuProxy
}
menuDemoMode() {
    clear; log "$LOG_TITLE" "Demo mode:"
    case "$(menu "On" "Off" "Back")" in
        "On") actionDemoMode true ;;
        "Off") actionDemoMode false ;;
        "Back") menuMain; return ;;
    esac;
    menuDemoMode
}
menuMediaSession() {
    clear; log "$LOG_TITLE" "Media session controls:"
    case "$(menu "play-pause" "play" "pause" "fast-forward" "rewind" "Info" "Back")" in
        "Back") menuMain; return ;;
        "Info") adb shell dumpsys media_session ;;
        *) actionMediaSession "$REPLY" ;;
    esac
    menuMediaSession
}
menuFireTVDevTools() {
    clear; log "$LOG_TITLE" "Fire TV dev tools:"
    case "$(menu "Open" "Back")" in
        "Open") actionOpenFireTVDevTools ;;
        "Back") menuMain; return ;;
    esac
    menuFireTVDevTools
}
menuSyncTime() {
    clear; log "$LOG_TITLE" "Set time:"
    case "$(menu "Sync time automatically (needs root)" "Open settings page" "Restart device" "Back")" in
        "Sync time automatically (needs root)") actionSetSystemDate ;;
        "Open settings page") actionOpenDateSettings ;;
        "Restart device") actionRestartDevice ;;
        "Back") menuMain; return;;
    esac
    menuSyncTime
}

## Main Menu
menuMain() {
    clear; log "$LOG_TITLE" "Main menu:"
    case "$(menu "📦 Packages" "🔐 Credentials" "📋 Paste Strings" "🎯 Layout Bounds" "🌐 Proxy" "📸 Demo Mode" "🎬 Media Session" "🔧 Fire TV Dev Tools" "⏱️ Sync Time" "Exit")" in
        "📦 Packages") menuPackages ;;
        "🔐 Credentials") menuCredentials ;;
        "📋 Paste Strings") menuPasteStrings ;;
        "🎯 Layout Bounds") menuLayoutBounds ;;
        "🌐 Proxy") menuProxy ;;
        "📸 Demo Mode") menuDemoMode ;;
        "🎬 Media Session") menuMediaSession ;;
        "🔧 Fire TV Dev Tools") menuFireTVDevTools ;;
        "⏱️ Sync Time") menuSyncTime ;;
        "Exit") exit 0 ;;
    esac
    menuMain
}

menuMain
