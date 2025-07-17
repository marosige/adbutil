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
LOCAL_VERSION="1.1.1"
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

waitForEnter() {
    local DESTINATION="${1:+ to $1}"  # Adds " to <destination>" only if $1 is given
    echo -e "${YELLOW}Press enter to continue${DESTINATION:-...}${NC}"
    read -r
}

## Configuration
ADBUTIL_CONFIG="$HOME/.adbutil"
[ -f "$ADBUTIL_CONFIG" ] && source "$ADBUTIL_CONFIG"

ADBUTIL_SKIP_ASK_INSTALL=${ADBUTIL_SKIP_ASK_INSTALL:=false}
ADBUTIL_SKIP_ASK_UPDATE=${ADBUTIL_SKIP_ASK_UPDATE:=false}
ADBUTIL_USE_GUM=${ADBUTIL_USE_GUM:=true}
ADBUTIL_CREDENTIALS=${ADBUTIL_CREDENTIALS:=("Set your credentials in $ADBUTIL_CONFIG config file|Username|Password")}
ADBUTIL_PASTE_STRINGS=${ADBUTIL_PASTE_STRINGS:=("Set your strings to paste in $ADBUTIL_CONFIG config file|String")}
ADBUTIL_PASTE_STRINGS=${ADBUTIL_PASTE_STRINGS:=()}

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

# Package filter (wildcards supported, e.g. "com.example.*")
ADBUTIL_PACKAGE_FILTER=(
EOF

for filter in "${ADBUTIL_PACKAGE_FILTER[@]}"; do
    echo "    \"$filter\"" >> "$ADBUTIL_CONFIG"
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

    waitForEnter "ADB Utility main menu."
    adbutil
    exit 0
}

## Menu
menu() {
    options=("$@")
    title="${options[0]}"
    unset options[0] # Remove title from options
    
    if $ADBUTIL_USE_GUM; then
        term_height=$(tput lines)
        gum_height=$((term_height - 4)) # Subtract 4 for gum UI elements
        gum choose --height "$gum_height" --header "$title" "${options[@]}"
    else
         echo "$title" >&2
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
MENU_DEVICE_INFO="ℹ️ Device Info"
MENU_EXIT="🚪 Exit"
MENU_BACK="↩️ Back"
MENU_ON="🟢 Enable"
MENU_OFF="🔴 Disable"
MENU_INFO="ℹ️ Info"
MENU_OPEN_SETTINGS="⚙️ Open settings screen"

## Actions
actionPackage() {
    local param_package="$1"
    local param_show_filtered=${2:-true}
    clear;
    local MENU_LAUNCH="🚀 Launch"
    local MENU_FORCE_STOP="⛔ Force Stop"
    local MENU_UNINSTALL="🗑️ Uninstall"
    local MENU_CLEAR_DATA="🧹 Clear Data"
    local MENU_HOME="🏠 Home (Background)"
    case "$(menu "📦 $param_package" "$MENU_LAUNCH" "$MENU_FORCE_STOP" "$MENU_HOME" "$MENU_CLEAR_DATA" "$MENU_UNINSTALL" "$MENU_INFO" "$MENU_BACK")" in
        "$MENU_LAUNCH") adb shell monkey -p "$param_package" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 ;;
        "$MENU_FORCE_STOP") adb shell am force-stop "$param_package" ;;
        "$MENU_HOME") adb shell input keyevent 3 ;;
        "$MENU_CLEAR_DATA") adb shell pm clear "$param_package" ;;
        "$MENU_UNINSTALL") adb uninstall "$param_package"; menuPackages; return ;;
        "$MENU_INFO") adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$param_package" > /dev/null 2>&1 ;;
        "$MENU_BACK") menuPackages "$param_show_filtered"; return ;;
    esac
    actionPackage "$param_package" "$param_show_filtered"
}
actionCredentials() {
    local param_title="$1"
    clear;
    local MENU_USERNAME="👤 Username"
    local MENU_PASSWORD="🔑 Password"
    local MENU_TAB=" ⇥ Tab Key"
    local MENU_ENTER=" ⏎ Enter Key"
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title user pass <<< "$cred"
        if [ "$title" == "$param_title" ]; then
            case "$(menu "🔐 $title" "$MENU_USERNAME: $user" "$MENU_PASSWORD: $pass" "$MENU_TAB" "$MENU_ENTER" "$MENU_BACK")" in
                "$MENU_USERNAME: $user") adb shell input text "$user" ;;
                "$MENU_PASSWORD: $pass") adb shell input text "$pass" ;;
                "$MENU_TAB") adb shell input keyevent 61 ;;   # 61 is KEYCODE_TAB
                "$MENU_ENTER") adb shell input keyevent 66 ;; # 66 is KEYCODE_ENTER
                "$MENU_BACK") menuCredentials; return ;;
            esac
            break
        fi
    done
    actionCredentials "$param_title"
}
actionPasteString() {
    local param_category="$1"
    clear;
    values=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category value <<< "$string"
        if [ "$category" == "$param_category" ]; then
            values+=("$value")
        fi
    done
    selected_value=$(menu "📝 $category" "${values[@]}" "$MENU_BACK")
    case "$selected_value" in
        "$MENU_BACK") menuPasteStrings; return ;;
        *) adb shell input text "$selected_value" ;;
    esac
    actionPasteString "$param_category"
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
    waitForEnter
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
    local param_show_filtered=${1:-true}
    clear;
    local MENU_SHOW_ALL="📦 Show all packages (remove filter)"
    local MENU_SHOW_FILTERED="🔍 Show only filtered packages"
    local MENU_REFRESH="🔄 Refresh"
    packages=($(adb shell cmd package list packages -3 | cut -f 2 -d ":"))  # cut "package:" from "package:com.android.bluetooth"

    # Filter packages based on ADBUTIL_PACKAGE_FILTER
    if [ "$param_show_filtered" = true ] && [ ${#ADBUTIL_PACKAGE_FILTER[@]} -gt 0 ]; then
        filteredPackages=()
        for package in "${packages[@]}"; do
            for filter in "${ADBUTIL_PACKAGE_FILTER[@]}"; do
                # Support wildcards
                if [[ "$package" == $filter ]]; then
                    filteredPackages+=("$package")
                    break
                fi 
            done
        done
        packages=("${filteredPackages[@]}")
    fi

    sortedPackages=($(echo "${packages[@]}" | tr ' ' '\n' | sort))

    options=()
    if [ ${#ADBUTIL_PACKAGE_FILTER[@]} -gt 0 ]; then
        if [ "$param_show_filtered" = true ]; then
            options+=("$MENU_SHOW_ALL")
        else
            options+=("$MENU_SHOW_FILTERED")
        fi
    fi
    options+=("$MENU_REFRESH" "${sortedPackages[@]}" "$MENU_BACK")

    selected_option=$(menu "$MENU_PACKAGES" "${options[@]}")
    case "$selected_option" in
        "$MENU_REFRESH") menuPackages "$param_show_filtered" ;;
        "$MENU_SHOW_ALL") menuPackages false ;;
        "$MENU_SHOW_FILTERED") menuPackages true ;;
        "$MENU_BACK") menuMain ;;
        *) actionPackage "$selected_option" "$param_show_filtered" ;;
    esac
}
menuCredentials() {
    clear;
    titles=()
    for cred in "${ADBUTIL_CREDENTIALS[@]}"; do
        IFS='|' read -r title _ _ <<< "$cred"
        titles+=("$title")
    done
    selected_option=$(menu "$MENU_CREDENTIALS" "${titles[@]}" "$MENU_BACK")
    case "$selected_option" in
        "$MENU_BACK") menuMain; return ;;
        *)
            actionCredentials "$selected_option"
        ;;
    esac
    menuCredentials
}
menuPasteStrings() {
    clear;
    categories=()
    for string in "${ADBUTIL_PASTE_STRINGS[@]}"; do
        IFS='|' read -r category _ <<< "$string"
        if [[ ! " ${categories[*]} " =~ " ${category} " ]]; then
            categories+=("$category")
        fi
    done
    selected_option=$(menu "$MENU_PASTE_STRINGS" "${categories[@]}" "$MENU_BACK")
    case "$selected_option" in
        "$MENU_BACK") menuMain; return ;;
        *)
            actionPasteString "$selected_option"
        ;;
    esac
    menuPasteStrings
}
menuLayoutBounds() {
    clear;
    case "$(menu "$MENU_LAYOUT_BOUNDS" "$MENU_ON" "$MENU_OFF" "$MENU_BACK")" in
        "$MENU_ON") actionLayoutBounds "true" ;;
        "$MENU_OFF") actionLayoutBounds "false" ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuLayoutBounds
}
menuProxy() {
    clear;
    case "$(menu "$MENU_PROXY" "$MENU_ON" "$MENU_OFF" "$MENU_INFO" "$MENU_BACK")" in
        "$MENU_ON") actionProxyOn ;;
        "$MENU_OFF") actionProxyOff ;;
        "$MENU_INFO") actionProxyStatus ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuProxy
}
menuDemoMode() {
    clear;
    case "$(menu "$MENU_DEMO_MODE" "$MENU_ON" "$MENU_OFF" "$MENU_BACK")" in
        "$MENU_ON") actionDemoMode true ;;
        "$MENU_OFF") actionDemoMode false ;;
        "$MENU_BACK") menuMain; return ;;
    esac;
    menuDemoMode
}
menuMediaSession() {
    clear;
    local MENU_MEDIA_PLAY_PAUSE="⏯️ play-pause"
    local MENU_MEDIA_PLAY="▶️ play"
    local MENU_MEDIA_PAUSE="⏸️ pause"
    local MENU_MEDIA_FF="⏩ fast-forward"
    local MENU_MEDIA_RW="⏪ rewind"
    options=("$MENU_MEDIA_SESSION" "$MENU_MEDIA_PLAY_PAUSE" "$MENU_MEDIA_PLAY" "$MENU_MEDIA_PAUSE" "$MENU_MEDIA_FF" "$MENU_MEDIA_RW" "$MENU_INFO" "$MENU_BACK")
    selected=$(menu "${options[@]}")
    case "$selected" in
        "$MENU_BACK") menuMain; return ;;
        "$MENU_INFO") adb shell dumpsys media_session ;;
        *)
            # Remove emoji and whitespace before passing to actionMediaSession
            event=$(echo "$selected" | sed -E 's/^[^ ]+ //')
            actionMediaSession "$event"
        ;;
    esac
    menuMediaSession
}
menuFireTVDevTools() {
    clear;
    case "$(menu "$MENU_FIRE_TV_DEV_TOOLS" "$MENU_OPEN_SETTINGS" "$MENU_BACK")" in
        "$MENU_OPEN_SETTINGS") actionOpenFireTVDevTools ;;
        "$MENU_BACK") menuMain; return ;;
    esac
    menuFireTVDevTools
}
menuSyncTime() {
    clear;
    local MENU_SYNC_TIME_AUTO="🕒 Sync time automatically (needs root)"
    local MENU_SYNC_TIME_RESTART="🔄 Restart device"
    case "$(menu "$MENU_SYNC_TIME" "$MENU_SYNC_TIME_AUTO" "$MENU_OPEN_SETTINGS" "$MENU_SYNC_TIME_RESTART" "$MENU_BACK")" in
        "$MENU_SYNC_TIME_AUTO") actionSetSystemDate ;;
        "$MENU_OPEN_SETTINGS") actionOpenDateSettings ;;
        "$MENU_SYNC_TIME_RESTART") actionRestartDevice ;;
        "$MENU_BACK") menuMain; return;;
    esac
    menuSyncTime
}
menuDeviceInfo() {
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
    menuMain
}

## Main Menu
menuMain() {
    clear;
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
        "$MENU_DEVICE_INFO"
        "$MENU_EXIT"
        )
    case "$(menu "📱 Main menu" "${menuItems[@]}")" in
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
        "$MENU_DEVICE_INFO") menuDeviceInfo ;;
        "$MENU_EXIT") exit 0 ;;
    esac
    menuMain
}

menuMain
