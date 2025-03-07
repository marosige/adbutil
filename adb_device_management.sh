### ADB Device Management

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
    if isCommandExist gum; then
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