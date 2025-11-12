#!/bin/bash

# Uninstall script for RPI Streamer USB Autolaunch (New Strategy)
# Removes systemd user services, udev rules, and scripts

set -e

USERNAME=$(whoami)
MOUNT_POINT="/mnt/rpistreamer"
UDEV_RULE_FILE="/etc/udev/rules.d/99-rpi-streamer-usb-new.rules"
SYSTEMD_USER_SERVICE="$HOME/.config/systemd/user/rpi-streamer-viewer.service"
SYSTEMD_USB_TEMPLATE="$HOME/.config/systemd/user/rpi-streamer-usb-handler@.service"
LAUNCHER_SCRIPT="$HOME/.local/bin/rpi-streamer-launcher.sh"
USB_HANDLER_SCRIPT="$HOME/.local/bin/rpi-streamer-usb-handler.sh"

echo "=== RPI Streamer USB Autolaunch Uninstall (New Strategy) ==="
echo "Username: $USERNAME"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Error: This script should not be run as root. Run as regular user, it will ask for sudo when needed."
   exit 1
fi

# Function to stop and disable services
stop_services() {
    echo "Stopping and disabling services..."
    
    # Stop any running instances
    systemctl --user stop rpi-streamer-viewer.service 2>/dev/null || true
    systemctl --user stop "rpi-streamer-usb-handler@*.service" 2>/dev/null || true
    
    # Disable the viewer service
    systemctl --user disable rpi-streamer-viewer.service 2>/dev/null || true
    
    # Kill any running processes
    pkill -f "Viewer-linux" 2>/dev/null || true
    pkill -f "rpi-streamer-launcher.sh" 2>/dev/null || true
    pkill -f "rpi-streamer-usb-handler.sh" 2>/dev/null || true
    
    echo "Services stopped and disabled"
}

# Function to remove systemd service files
remove_services() {
    echo "Removing systemd service files..."
    
    if [ -f "$SYSTEMD_USER_SERVICE" ]; then
        rm -f "$SYSTEMD_USER_SERVICE"
        echo "Removed: $SYSTEMD_USER_SERVICE"
    fi
    
    if [ -f "$SYSTEMD_USB_TEMPLATE" ]; then
        rm -f "$SYSTEMD_USB_TEMPLATE"
        echo "Removed: $SYSTEMD_USB_TEMPLATE"
    fi
    
    # Reload systemd
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Systemd user services removed"
}

# Function to remove scripts
remove_scripts() {
    echo "Removing scripts..."
    
    if [ -f "$LAUNCHER_SCRIPT" ]; then
        rm -f "$LAUNCHER_SCRIPT"
        echo "Removed: $LAUNCHER_SCRIPT"
    fi
    
    if [ -f "$USB_HANDLER_SCRIPT" ]; then
        rm -f "$USB_HANDLER_SCRIPT"
        echo "Removed: $USB_HANDLER_SCRIPT"
    fi
    
    echo "Scripts removed"
}

# Function to remove udev rule
remove_udev_rule() {
    echo "Removing udev rule..."
    
    if [ -f "$UDEV_RULE_FILE" ]; then
        sudo rm -f "$UDEV_RULE_FILE"
        echo "Removed: $UDEV_RULE_FILE"
        
        # Reload udev rules
        echo "Reloading udev rules..."
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=block
        echo "Udev rules reloaded"
    else
        echo "Udev rule file not found, skipping"
    fi
}

# Function to clean up cache (optional)
cleanup_cache() {
    local cache_dir="$HOME/.cache/streamer-viewer"
    
    if [ -d "$cache_dir" ]; then
        echo "Cache directory found at: $cache_dir"
        read -p "Do you want to remove the cache directory (contains logs and cached executable)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$cache_dir"
            echo "Cache directory removed"
        else
            echo "Cache directory preserved"
        fi
    fi
}

# Function to disable user lingering
disable_lingering() {
    echo "Checking user lingering..."
    if sudo loginctl show-user "$USERNAME" -p Linger --value | grep -q "yes"; then
        read -p "Disable user lingering (allows services to run when not logged in)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo loginctl disable-linger "$USERNAME"
            echo "User lingering disabled"
        else
            echo "User lingering preserved"
        fi
    else
        echo "User lingering not enabled, skipping"
    fi
}

# Function to unmount if mounted
unmount_device() {
    echo "Checking mount point..."
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Device mounted at $MOUNT_POINT, unmounting..."
        sudo umount "$MOUNT_POINT" 2>/dev/null || true
        echo "Device unmounted"
    else
        echo "No device mounted at $MOUNT_POINT"
    fi
}

# Main uninstallation
main() {
    echo "Starting uninstallation..."
    echo
    
    # Stop services first
    stop_services
    echo
    
    # Remove systemd services
    remove_services
    echo
    
    # Remove scripts
    remove_scripts
    echo
    
    # Remove udev rule
    remove_udev_rule
    echo
    
    # Unmount device if mounted
    unmount_device
    echo
    
    # Optional cleanup
    cleanup_cache
    echo
    
    # Optional lingering disable
    disable_lingering
    echo
    
    echo "=== Uninstallation Complete ==="
    echo "The USB autolaunch system has been removed."
    echo
    echo "Note: The mount point directory $MOUNT_POINT is preserved."
    echo "You can manually remove it with: sudo rmdir $MOUNT_POINT"
    echo
}

# Run main uninstallation
main