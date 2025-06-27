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
DONWLOAD_URL="https://raw.githubusercontent.com/marosige/adbutil/refs/heads/main/adbutil.sh"
DOWNLOAD_FOLDER="$HOME/bin"
DONWLOAD_LOCATION="$DOWNLOAD_FOLDER/adbutil"
LOCAL_VERSION="1.0.0"
REMOTE_VERSION=$(curl -s -L "$DONWLOAD_URL" | grep -Eo 'LOCAL_VERSION="[0-9.]+"' | cut -d '"' -f 2)

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

## Configuration
ADBUTIL_CONFIG="$HOME/.adbutil"
[ -f "$ADBUTIL_CONFIG" ] && source "$ADBUTIL_CONFIG"

ADBUTIL_SKIP_ASK_INSTALL=${ADBUTIL_SKIP_ASK_INSTALL:=false}
ADBUTIL_SKIP_ASK_UPDATE=${ADBUTIL_SKIP_ASK_UPDATE:=false}
ADBUTIL_USE_GUM=${ADBUTIL_USE_GUM:=true}
ADBUTIL_CREDENTIALS=${ADBUTIL_CREDENTIALS:=("Set your credentials in $ADBUTIL_CONFIG config file|Username|Password")}
ADBUTIL_PASTE_STRINGS=${ADBUTIL_PASTE_STRINGS:=("Set your strings to paste in $ADBUTIL_CONFIG config file|String")}

rm -f "$ADBUTIL_CONFIG"

cat <<EOF > "$ADBUTIL_CONFIG"
### ADB Utility Configuration
### https://github.com/marosige/adbutil

## Preferences
ADBUTIL_SKIP_ASK_INSTALL=$ADBUTIL_SKIP_ASK_INSTALL
ADBUTIL_SKIP_ASK_UPDATE=$ADBUTIL_SKIP_ASK_UPDATE
ADBUTIL_USE_GUM=$ADBUTIL_USE_GUM

## Private values

# Credentials
# Format: "Title|Username|Password"
# Examples: "Admin|adminuser|password"
#           "Free user|freeuser|password"
#           "Subsciber|subuser|password"
ADBUTIL_CREDENTIALS=(
EOF

# Add the credentials values to the config
for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
    echo "    \"$cred\"" >> "$ADBUTIL_CONFIG"
done

cat <<EOF >> "$ADBUTIL_CONFIG"
)

# Strings to paste
# Format: "Category|String"
# Examples: "register|email"
#           "register|password"
#           "register|country"
#           "promocode|AAAA-1111-BBBB-2222"
#           "promocode|BBBB-3333-CCCC-4444"
ADBUTIL_PASTE_STRINGS=(
EOF

# Add the paste strings values to the config
for str in "${ADBUTIL_PASTE_STRINGS[@]}"; do
    echo "    \"$str\"" >> "$ADBUTIL_CONFIG"
done

cat <<EOF >> "$ADBUTIL_CONFIG"
)
EOF

## Dependencies
isCommandExist() { command -v "$1" &> /dev/null; }
isCommandExist adb || { logFail "ADB is not installed. Please install it and try again."; exit 1; }
isCommandExist gum || { if $ADBUTIL_USE_GUM; then logWarn "Gum is not installed. Install it for a nicer UI"; ADBUTIL_USE_GUM=false; fi; }

## Install & Update
download() {
    action=$1 # install or update

    #Create bin folder and add it to path if missing
    mkdir -p "$DOWNLOAD_FOLDER"
    [ -f "$HOME/.bashrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.bashrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.zshrc" && echo "export PATH=\"\$PATH:$DOWNLOAD_FOLDER\"" >> "$HOME/.zshrc"
    [ -f "$HOME/.config/fish/config.fish" ] && ! grep -q "$DOWNLOAD_FOLDER" "$HOME/.config/fish/config.fish" && echo "set -gx PATH \$PATH $DOWNLOAD_FOLDER" >> "$HOME/.config/fish/config.fish"

    # Download and install adbutil
    if curl -s -L -o "$DONWLOAD_LOCATION" "$DONWLOAD_URL"; then
        chmod +x "$DONWLOAD_LOCATION"
        logDone "adbutil $action succeed."
    else
        logFail "Failed to $action adbutil."
        logIndent "You can manually download it from: $DONWLOAD_URL"
        logIndent "Don't forget to make it executable and move it to your PATH."
    fi

    read -p "Press enter to continue to ADB Utility main menu."
    adbutil
    exit 0
}

## Menu
menu() {
    options=("$@")
    if $ADBUTIL_USE_GUM; then
        gum choose --height 15 "${options[@]}"
    else
        PS3="Please select an option: "
        select choice in "${options[@]}"; do
            [ -n "$choice" ] && echo "$choice" && break
            echo -e "Invalid option. Please try again."
        done
    fi
}

### ADB Utility

## Constants
MENU_INSTALL="📥 Install adbutil"
MENU_UPDATE="📥 Update adbutil ($LOCAL_VERSION -> $REMOTE_VERSION)"
MENU_PACKAGES="📦 Third Party Packages"
MENU_CREDENTIALS="🔐 Credentials"
MENU_PASTE_STRINGS="📝 Paste Strings"
MENU_LAYOUT_BOUNDS="🎯 Layout Bounds"
MENU_PROXY="🌐 Proxy"
MENU_DEMO_MODE="📸 Demo Mode"
MENU_MEDIA_SESSION="🎬 Media Session"
MENU_FIRE_TV_DEV_TOOLS="🔧 Fire TV Dev Tools"
MENU_SYNC_TIME="⏱️  Sync Time"
MENU_EXIT="🚪 Exit"
MENU_BACK="↩️  Back"

## Actions
actionPackage() {
    clear; echo "📦 Selected Package: $1"
    case "$(menu "Launch" "Force Stop" "Uninstall" "Clear Data" "Open Info Page" "$MENU_BACK")" in
        "Launch") adb shell monkey -p "$1" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 ;;
        "Force Stop") adb shell am force-stop "$1" ;;
        "Uninstall") adb uninstall "$1"; menuPackages; return ;;
        "Clear Data") adb shell pm clear "$1" ;;
        "Open Info Page") adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$1" > /dev/null 2>&1 ;;
        "$MENU_BACK") menuPackages; return ;;
    esac
    actionPackage "$1"
}
actionCredentials() {
    clear; echo "🔐 Credentials for User: $1"
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title user pass <<< "$cred"
        if [ "$title" == "$1" ]; then
            case "$(menu "Username ($user)" "Password ($pass)" "$MENU_BACK")" in
                "Username ($user)") adb shell input text "$user" ;;
                "Password ($pass)") adb shell input text "$pass" ;;
                "$MENU_BACK") menuCredentials; return ;;
            esac
            break
        fi
    done
    actionCredentials "$1"
}
actionPasteString() {
    clear; echo "📝 Paste Strings for Category: $1"
    values=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category value <<< "$string"
        if [ "$category" == "$1" ]; then
            values+=("$value")
        fi
    done
    selected_value=$(menu "${values[@]}" "$MENU_BACK")
    case "$selected_value" in
        "$MENU_BACK") menuPasteStrings; return ;;
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
        logInfo "Proxy is not set"
    else
        logInfo "Proxy set to: $proxy"
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
    clear; echo "$MENU_PACKAGES"
    packages=($(adb shell cmd package list packages -3 | cut -f 2 -d ":"))  # cut "package:" from "package:com.android.bluetooth"
    sortedPackages=($(echo "${packages[@]}" | tr ' ' '\n' | sort))
    options=("Refresh" "${sortedPackages[@]}" "$MENU_BACK")
    selected_option=$(menu "${options[@]}")
    case "$selected_option" in
        "Refresh") menuPackages ;;
        "$MENU_BACK") menuMain ;;
        *) actionPackage "$selected_option" ;;
    esac
}
menuCredentials() {
    clear; echo "$MENU_CREDENTIALS"
    titles=()
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title _ _ <<< "$cred"
        titles+=("$title")
    done
    selected_option=$(menu "${titles[@]}" "$MENU_BACK")
    case "$selected_option" in
        "$MENU_BACK") menuMain; return ;;
        *)
            actionCredentials "$selected_option"
        ;;
    esac
    menuCredentials
}
menuPasteStrings() {
    clear; echo "$MENU_PASTE_STRINGS"
    categories=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category _ <<< "$string"
        categories+=("$category")
    done
    selected_option=$(menu "${categories[@]}" "$MENU_BACK")
    case "$selected_option" in
        "$MENU_BACK") menuMain; return ;;
        *)
            actionPasteString "$selected_option"
        ;;
    esac
    menuPasteStrings
}
menuLayoutBounds() {
    clear; echo "$MENU_LAYOUT_BOUNDS"
    case "$(menu "On" "Off" "$MENU_BACK")" in
        "On") actionLayoutBounds "true" ;;
        "Off") actionLayoutBounds "false" ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuLayoutBounds
}
menuProxy() {
    clear; echo "$MENU_PROXY"
    case "$(menu "On" "Off" "Status" "$MENU_BACK")" in
        "On") actionProxyOn ;;
        "Off") actionProxyOff ;;
        "Status") actionProxyStatus ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuProxy
}
menuDemoMode() {
    clear; echo "$MENU_DEMO_MODE"
    case "$(menu "On" "Off" "$MENU_BACK")" in
        "On") actionDemoMode true ;;
        "Off") actionDemoMode false ;;
        "$MENU_BACK") menuMain; return ;;
    esac;
    menuDemoMode
}
menuMediaSession() {
    clear; echo "$MENU_MEDIA_SESSION"
    options=("⏯️  play-pause" "▶️  play" "⏸️  pause" "⏩ fast-forward" "⏪ rewind" "ℹ️  Info" "$MENU_BACK")
    selected=$(menu "${options[@]}")
    case "$selected" in
        "$MENU_BACK") menuMain; return ;;
        "ℹ️  Info") adb shell dumpsys media_session ;;
        *)
            # Remove emoji and whitespace before passing to actionMediaSession
            event=$(echo "$selected" | sed -E 's/^[^ ]+ //')
            actionMediaSession "$event"
        ;;
    esac
    menuMediaSession
}
menuFireTVDevTools() {
    clear; echo "$MENU_FIRE_TV_DEV_TOOLS"
    case "$(menu "Open" "$MENU_BACK")" in
        "Open") actionOpenFireTVDevTools ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuFireTVDevTools
}
menuSyncTime() {
    clear; echo "$MENU_SYNC_TIME"
    case "$(menu "Sync time automatically (needs root)" "Open settings page" "Restart device" "$MENU_BACK")" in
        "Sync time automatically (needs root)") actionSetSystemDate ;;
        "Open settings page") actionOpenDateSettings ;;
        "Restart device") actionRestartDevice ;;
        "$MENU_BACK") menuMain; return;;
    esac
    menuSyncTime
}

## Main Menu
menuMain() {
    clear; echo "📱 Main menu"
    menuItems=()
    if ! $ADBUTIL_SKIP_ASK_INSTALL && ! isCommandExist adbutil; then
        menuItems+=("$MENU_INSTALL")
    elif [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        menuItems+=("$MENU_UPDATE")
    fi
    menuItems+=(
        "$MENU_PACKAGES" 
        "$MENU_CREDENTIALS" 
        "$MENU_PASTE_STRINGS" 
        "$MENU_LAYOUT_BOUNDS" 
        "$MENU_PROXY" 
        "$MENU_DEMO_MODE" 
        "$MENU_MEDIA_SESSION" 
        "$MENU_FIRE_TV_DEV_TOOLS" 
        "$MENU_SYNC_TIME" 
        "$MENU_EXIT"
        )
    case "$(menu "${menuItems[@]}")" in
        "$MENU_INSTALL") download "install" ;;
        "$MENU_UPDATE") download "update" ;;
        "$MENU_PACKAGES") menuPackages ;;
        "$MENU_CREDENTIALS") menuCredentials ;;
        "$MENU_PASTE_STRINGS") menuPasteStrings ;;
        "$MENU_LAYOUT_BOUNDS") menuLayoutBounds ;;
        "$MENU_PROXY") menuProxy ;;
        "$MENU_DEMO_MODE") menuDemoMode ;;
        "$MENU_MEDIA_SESSION") menuMediaSession ;;
        "$MENU_FIRE_TV_DEV_TOOLS") menuFireTVDevTools ;;
        "$MENU_SYNC_TIME") menuSyncTime ;;
        "$MENU_EXIT") exit 0 ;;
    esac
    menuMain
}

menuMain
