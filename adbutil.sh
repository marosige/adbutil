#!/usr/bin/env bash

#####################################################################
# ADB Utility for Android Development
#
# Uses gum if available, select if not.
# Saves info into a .adbutil file in the home directory.
# Override gum with the ADBUTIL_USE_GUM environment variable.
#
# Made by Gergely Marosi - github.com/marosige
#####################################################################

### Bootstrap

## Logging

# Colors
BOLD='\033[1m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_GREEN='\033[0;92m'
YELLOW='\033[0;33m'
BRIGHT_RED='\033[0;91m'
NC='\033[0m' # No Color (resets to default)

# Messages
export LOG_TITLE="${BOLD}[#]${NC}"
export LOG_TASK="${BRIGHT_BLUE}[>]${NC}"
export LOG_DONE="${BRIGHT_GREEN}[✔]${NC}"
export LOG_ADD="${BRIGHT_GREEN}[+]${NC}"
export LOG_WARN="${YELLOW}[!]${NC}"
export LOG_FAIL="${BRIGHT_RED}[✖]${NC}"
export LOG_INDENT="   "

# Functions
log() {
    echo -e "$1 $2"
}

## Environment

# Source .adbutil config file
ADBUTIL_CONFIG="$HOME/.adbutil"
if [ ! -f "$ADBUTIL_CONFIG" ]; then
    echo "# ADB Utility Configuration" > "$ADBUTIL_CONFIG"
    echo "ADBUTIL_USE_GUM=true" > "$ADBUTIL_CONFIG"
    echo "ADBUTIL_SKIP_ASK_INSTALL=false" >> "$ADBUTIL_CONFIG"
fi
source "$ADBUTIL_CONFIG"

ADBUTIL_USE_GUM=${ADBUTIL_USE_GUM:-true}
ADBUTIL_SKIP_ASK_INSTALL=${ADBUTIL_SKIP_ASK_INSTALL:-false}

# Check dependencies
isCommandExist() { command -v "$1" &> /dev/null; }
isCommandExist adb || { log "$LOG_FAIL" "ADB is not installed. Please install it and try again."; exit 1; }
isCommandExist gum || { if $ADBUTIL_USE_GUM; then log "$LOG_WARN" "Gum is not installed. Install it for a nicer UI"; ADBUTIL_USE_GUM=false; fi; }

# Install adbutil
if ! $ADBUTIL_SKIP_ASK_INSTALL && ! isCommandExist adbutil; then
    log "$LOG_WARN" "adbutil is not installed on your system"
    read -p "Do you want to install it? [y/N]: " -r
    if [[  $REPLY =~ ^[Yy]$ ]]; then
        downloadUrl="https://gist.githubusercontent.com/marosige/3df88ffe29b8f5e8d93389d0ab0991e5/raw/a79108f34c2262240e703f93105ec2e9d85d961b/adbutil"
        downloadLocation="/usr/local/bin/adbutil"
        if curl -L -o "$downloadLocation" "$downloadUrl"; then
            sudo chmod +x "$downloadLocation"
            log "$LOG_DONE" "adbutil installed successfully."
        else
            log "$LOG_FAIL" "Failed to download adbutil."
        fi
    else
        log "$LOG_WARN" "You can disable this prompt by setting ADBUTIL_SKIP_ASK_INSTALL=true in $ADBUTIL_CONFIG"
    fi
fi

## Menu

menu() {
    # Check if options are passed as arguments
    if [ -z "$1" ]; then
        echo "Usage: $0 <option1> <option2> ..."
        exit 1
    fi

    # Ensure options are in an array
    options=("$@")

    # Use gum if enabled, otherwise fall back to select
    if [ "$USE_GUM" = true ] ; then
        choice=$(gum choose "${options[@]}")
    else
        PS3="Please select an option: "
        select choice in "${options[@]}"; do
            [ -n "$choice" ] && break
            echo -e "Invalid option. Please try again."
        done
    fi

    # Output the selected choice (to be used by the calling script)
    echo "$choice"
}

### Device Management

# Global variable to store selected devices
SELECTED_DEVICES=()

# Function to list connected ADB devices
list_devices() {
    adb devices | awk 'NR>1 {if ($2 == "device") print $1}'  # Lists only connected devices
}

# Function to select devices
select_devices() {
    echo "Detecting connected devices..."
    DEVICES=($(list_devices))

    if [ ${#DEVICES[@]} -eq 0 ]; then
        echo "No devices found."
        exit 1
    fi

    # Use gum if available, otherwise fall back to select
    if command -v gum &> /dev/null; then
        echo "Using gum for selection..."
        SELECTED_DEVICES=($(gum choose --no-limit "${DEVICES[@]}"))
    else
        echo "Gum not found. Using traditional select."
        PS3="Please select devices (enter numbers separated by space, or type 'all'): "
        select choice in "${DEVICES[@]}" "All"; do
            if [[ "$choice" == "All" ]]; then
                SELECTED_DEVICES=("${DEVICES[@]}")
                break
            elif [[ -n "$choice" ]]; then
                SELECTED_DEVICES+=("$choice")
            else
                echo "Invalid option. Please try again."
            fi

            # Stop selection if we have at least one valid device
            if [ ${#SELECTED_DEVICES[@]} -gt 0 ]; then
                break
            fi
        done
    fi

    if [ ${#SELECTED_DEVICES[@]} -eq 0 ]; then
        echo "No valid devices selected."
        exit 1
    fi

    echo "Selected devices: ${SELECTED_DEVICES[*]}"
}

# Function to send ADB command to selected devices
send_adb_command() {
    local command="$@"
    for device in "${SELECTED_DEVICES[@]}"; do
        echo "Running on $device: adb -s $device $command"
        adb -s "$device" $command
    done
}

# Example usage
select_devices
send_adb_command shell getprop ro.product.model
