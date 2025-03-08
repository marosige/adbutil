# ADBUtil - ADB Utility for Android Development

ADBUtil is a powerful command-line tool designed to simplify ADB (Android Debug Bridge) operations for Android developers. It provides a menu-driven interface to interact with ADB, manage packages, handle credentials, configure proxies, and more.

## Features
- Launch, force stop, uninstall, and clear app data
- Store and autofill credentials
- Enable/disable layout bounds debugging
- Manage HTTP proxy settings
- Control media sessions
- Toggle Android demo mode
- Open Fire TV Developer Tools
- Sync system time

## Installation
To install ADBUtil, use the following command to run it and it will install itself:

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/adbutil/refs/heads/main/adbutil.sh)"

### Prerequisites
Ensure you have the following installed on your system:
- **ADB** (Android Debug Bridge)
- **gum** (optional, for a better UI experience)

## Configuration
ADBUtil stores its configuration in `~/.adbutil`. If the file does not exist, it will be automatically generated with default settings.

Example `~/.adbutil` configuration:
```bash
# ADB Utility Configuration
ADBUTIL_SKIP_ASK_INSTALL=false
ADBUTIL_USE_GUM=true
ADBUTIL_CREDENTIALS=(
    "Set your credentials in $ADBUTIL_CONFIG config file|Username|Password"
    "Admin|admin|admin123"
    "User 1|user1|password1"
    "User 2|user2|password2"
)
```

## Credential Management
ADBUtil allows you to store login credentials securely inside the `~/.adbutil` file. You can autofill stored usernames and passwords in Android applications via ADB commands.

## Usage
Run `adbutil` in your terminal to launch the interactive menu.

```bash
adbutil
```
Navigate through the menu to perform actions such as:
- Managing installed applications
- Inputting stored credentials
- Adjusting proxy settings
- Controlling media sessions
- Enabling demo mode

## License
This project is licensed under the MIT License.

## Author
Developed by **Gergely Marosi** - [GitHub](https://github.com/marosige)

## Contributions
Contributions are welcome! Feel free to submit pull requests or report issues in the GitHub repository.

