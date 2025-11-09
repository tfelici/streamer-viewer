#!/bin/bash
#
# Streamer Viewer USB Auto-Launch Installer for Linux
# 
# This script installs a udev rule that automatically detects USB sticks
# containing streamerData folders and launches the Streamer Viewer application
# with the correct --data-dir parameter.
#
# Usage: sudo ./install_usb_autolaunch.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UDEV_RULE_FILE="/etc/udev/rules.d/99-streamer-viewer-usb.rules"
HANDLER_SCRIPT="/usr/local/bin/streamer-viewer-usb-handler.sh"
DESKTOP_ENTRY="/usr/share/applications/streamer-viewer-usb.desktop"

echo -e "${BLUE}Streamer Viewer USB Auto-Launch Installer${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   echo "Usage: sudo ./install_usb_autolaunch.sh"
   exit 1
fi

# Get the actual user (not root when using sudo)
if [ "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME="/home/$SUDO_USER"
else
    echo -e "${RED}Error: Please run with sudo to maintain proper user context${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing for user: $ACTUAL_USER${NC}"
echo -e "${YELLOW}User home directory: $ACTUAL_HOME${NC}"
echo ""

# Create the USB handler script
echo -e "${BLUE}Creating USB detection handler script...${NC}"
cat > "$HANDLER_SCRIPT" << 'EOF'
#!/bin/bash
#
# Streamer Viewer USB Handler Script
# Automatically launched by udev when USB devices are inserted
#

# Logging
LOG_FILE="/var/log/streamer-viewer-usb.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "$(date): USB device event - $ACTION $DEVNAME"

# Only handle add events for block devices
if [ "$ACTION" != "add" ] || [ -z "$DEVNAME" ]; then
    exit 0
fi

# Wait a moment for the device to be fully mounted
sleep 2

# Get the actual user from environment or fallback
ACTUAL_USER="${SUDO_USER:-$USER}"
if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
    # Try to find the user from who's logged in
    ACTUAL_USER=$(who | grep -E "(:0|tty)" | head -n1 | awk '{print $1}')
fi

if [ -z "$ACTUAL_USER" ]; then
    echo "$(date): Error - Cannot determine actual user"
    exit 1
fi

ACTUAL_HOME="/home/$ACTUAL_USER"
echo "$(date): Detected user: $ACTUAL_USER"

# Function to check and launch viewer
check_and_launch() {
    local mount_point="$1"
    local streamer_data_dir="$mount_point/streamerData"
    
    echo "$(date): Checking mount point: $mount_point"
    
    if [ ! -d "$streamer_data_dir" ]; then
        echo "$(date): No streamerData folder found at $mount_point"
        return 1
    fi
    
    echo "$(date): Found streamerData folder at: $streamer_data_dir"
    
    # Check for required subdirectories
    if [ ! -d "$streamer_data_dir/tracks" ] && [ ! -d "$streamer_data_dir/recordings" ]; then
        echo "$(date): streamerData folder exists but missing tracks/recordings subdirectories"
        return 1
    fi
    
    # Desktop path
    DESKTOP_DIR="$ACTUAL_HOME/Desktop"
    VIEWER_EXECUTABLE="$DESKTOP_DIR/Streamer-Viewer-Linux"
    
    # Ensure Desktop directory exists
    if [ ! -d "$DESKTOP_DIR" ]; then
        sudo -u "$ACTUAL_USER" mkdir -p "$DESKTOP_DIR"
    fi
    
    # Check if we need to copy/update the executable
    USB_EXECUTABLE="$mount_point/Streamer-Viewer-Linux"
    if [ -f "$USB_EXECUTABLE" ]; then
        COPY_NEEDED=false
        
        if [ ! -f "$VIEWER_EXECUTABLE" ]; then
            echo "$(date): Viewer executable not found on desktop, copying from USB"
            COPY_NEEDED=true
        else
            # Compare modification times or checksums
            USB_SIZE=$(stat -c%s "$USB_EXECUTABLE" 2>/dev/null || echo "0")
            DESKTOP_SIZE=$(stat -c%s "$VIEWER_EXECUTABLE" 2>/dev/null || echo "0")
            
            if [ "$USB_SIZE" != "$DESKTOP_SIZE" ]; then
                echo "$(date): Viewer executable size differs, updating from USB"
                COPY_NEEDED=true
            else
                USB_MTIME=$(stat -c%Y "$USB_EXECUTABLE" 2>/dev/null || echo "0")
                DESKTOP_MTIME=$(stat -c%Y "$VIEWER_EXECUTABLE" 2>/dev/null || echo "0")
                
                if [ "$USB_MTIME" -gt "$DESKTOP_MTIME" ]; then
                    echo "$(date): USB executable is newer, updating"
                    COPY_NEEDED=true
                fi
            fi
        fi
        
        if [ "$COPY_NEEDED" = "true" ]; then
            echo "$(date): Copying executable to desktop..."
            cp "$USB_EXECUTABLE" "$VIEWER_EXECUTABLE"
            chown "$ACTUAL_USER:$ACTUAL_USER" "$VIEWER_EXECUTABLE"
            chmod +x "$VIEWER_EXECUTABLE"
            echo "$(date): Executable copied and made executable"
        fi
    else
        # Check if executable exists on desktop already
        if [ ! -f "$VIEWER_EXECUTABLE" ]; then
            echo "$(date): No Streamer-Viewer-Linux found on USB or Desktop"
            
            # Send notification to user
            sudo -u "$ACTUAL_USER" DISPLAY=:0 notify-send \
                "Streamer Viewer USB" \
                "Found streamerData but no Streamer-Viewer-Linux executable. Please copy the executable to the USB drive." \
                --icon=dialog-information \
                --urgency=normal 2>/dev/null || true
            
            return 1
        fi
    fi
    
    # Make sure executable has proper permissions
    chmod +x "$VIEWER_EXECUTABLE"
    
    # Check if Streamer Viewer is already running with this data directory
    if pgrep -f "Streamer-Viewer-Linux.*--data-dir.*$streamer_data_dir" > /dev/null; then
        echo "$(date): Streamer Viewer already running with this data directory"
        return 0
    fi
    
    echo "$(date): Launching Streamer Viewer with data directory: $streamer_data_dir"
    
    # Launch the application as the actual user
    sudo -u "$ACTUAL_USER" DISPLAY=:0 "$VIEWER_EXECUTABLE" --data-dir "$streamer_data_dir" &
    
    # Send notification to user
    sudo -u "$ACTUAL_USER" DISPLAY=:0 notify-send \
        "Streamer Viewer" \
        "Auto-launched with USB data from: $mount_point" \
        --icon=dialog-information \
        --urgency=normal 2>/dev/null || true
    
    echo "$(date): Streamer Viewer launched successfully"
    return 0
}

# Check all possible mount points
found_streamer_data=false

# Check if the device is already mounted
for mount_point in $(mount | grep "^$DEVNAME" | awk '{print $3}'); do
    if check_and_launch "$mount_point"; then
        found_streamer_data=true
        break
    fi
done

# If not found in existing mounts, try to mount and check
if [ "$found_streamer_data" = "false" ]; then
    # Try to mount the device temporarily
    TEMP_MOUNT="/tmp/streamer-usb-check-$$"
    mkdir -p "$TEMP_MOUNT"
    
    if mount "$DEVNAME" "$TEMP_MOUNT" 2>/dev/null; then
        echo "$(date): Temporarily mounted $DEVNAME at $TEMP_MOUNT"
        
        if check_and_launch "$TEMP_MOUNT"; then
            found_streamer_data=true
        fi
        
        # Don't unmount if we found streamerData, let the user handle it
        if [ "$found_streamer_data" = "false" ]; then
            umount "$TEMP_MOUNT" 2>/dev/null || true
        fi
    fi
    
    rmdir "$TEMP_MOUNT" 2>/dev/null || true
fi

if [ "$found_streamer_data" = "false" ]; then
    echo "$(date): No streamerData folder found on device $DEVNAME"
fi

echo "$(date): USB handler completed"
EOF

chmod +x "$HANDLER_SCRIPT"
echo -e "${GREEN}✓ Created USB handler script: $HANDLER_SCRIPT${NC}"

# Create the udev rule
echo -e "${BLUE}Creating udev rule...${NC}"
cat > "$UDEV_RULE_FILE" << EOF
# Streamer Viewer USB Auto-Launch Rule
# Triggers when USB storage devices are inserted
# 
# This rule detects USB storage devices and runs a script to check
# for streamerData folders and launch Streamer Viewer accordingly

ACTION=="add", KERNEL=="sd[a-z][0-9]*", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="$HANDLER_SCRIPT"
ACTION=="add", KERNEL=="nvme[0-9]*p[0-9]*", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="$HANDLER_SCRIPT"
EOF

echo -e "${GREEN}✓ Created udev rule: $UDEV_RULE_FILE${NC}"

# Create desktop entry for manual launch
echo -e "${BLUE}Creating desktop entry...${NC}"
cat > "$DESKTOP_ENTRY" << EOF
[Desktop Entry]
Name=Streamer Viewer USB
Comment=Launch Streamer Viewer with USB data directory
Exec=/usr/local/bin/streamer-viewer-manual-usb-launch.sh
Icon=media-removable
Terminal=false
Type=Application
Categories=AudioVideo;Video;
Keywords=GPS;Video;Tracking;USB;
EOF

# Create manual USB launch script
MANUAL_LAUNCH_SCRIPT="/usr/local/bin/streamer-viewer-manual-usb-launch.sh"
cat > "$MANUAL_LAUNCH_SCRIPT" << 'EOF'
#!/bin/bash
#
# Manual USB Launch Script for Streamer Viewer
# Allows users to manually select USB drives with streamerData
#

# Find USB drives with streamerData
USB_DRIVES=()
while IFS= read -r -d '' mount_point; do
    if [ -d "$mount_point/streamerData" ]; then
        USB_DRIVES+=("$mount_point")
    fi
done < <(find /media /mnt -maxdepth 3 -name "streamerData" -type d -print0 2>/dev/null)

if [ ${#USB_DRIVES[@]} -eq 0 ]; then
    zenity --info --text="No USB drives with streamerData folders found." --title="Streamer Viewer USB" 2>/dev/null || \
    notify-send "Streamer Viewer USB" "No USB drives with streamerData folders found." --icon=dialog-information
    exit 1
fi

if [ ${#USB_DRIVES[@]} -eq 1 ]; then
    SELECTED="${USB_DRIVES[0]}"
else
    # Multiple drives found, let user choose
    CHOICE=$(zenity --list --title="Select USB Drive" --text="Multiple USB drives with streamerData found:" --column="USB Drive" "${USB_DRIVES[@]}" 2>/dev/null)
    if [ -z "$CHOICE" ]; then
        exit 1
    fi
    SELECTED="$CHOICE"
fi

VIEWER_EXECUTABLE="$HOME/Desktop/Streamer-Viewer-Linux"
if [ ! -f "$VIEWER_EXECUTABLE" ]; then
    zenity --error --text="Streamer-Viewer-Linux not found on Desktop. Please install it first." --title="Streamer Viewer USB" 2>/dev/null || \
    notify-send "Streamer Viewer USB" "Streamer-Viewer-Linux not found on Desktop." --icon=dialog-error
    exit 1
fi

# Launch with selected USB data directory
"$VIEWER_EXECUTABLE" --data-dir "$SELECTED/streamerData" &
EOF

chmod +x "$MANUAL_LAUNCH_SCRIPT"
echo -e "${GREEN}✓ Created manual launch script: $MANUAL_LAUNCH_SCRIPT${NC}"

# Reload udev rules
echo -e "${BLUE}Reloading udev rules...${NC}"
udevadm control --reload-rules
udevadm trigger
echo -e "${GREEN}✓ udev rules reloaded${NC}"

# Create log file with proper permissions
touch /var/log/streamer-viewer-usb.log
chmod 644 /var/log/streamer-viewer-usb.log
echo -e "${GREEN}✓ Created log file: /var/log/streamer-viewer-usb.log${NC}"

echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}What was installed:${NC}"
echo "• udev rule: $UDEV_RULE_FILE"
echo "• USB handler: $HANDLER_SCRIPT" 
echo "• Manual launcher: $MANUAL_LAUNCH_SCRIPT"
echo "• Desktop entry: $DESKTOP_ENTRY"
echo "• Log file: /var/log/streamer-viewer-usb.log"
echo ""
echo -e "${YELLOW}How it works:${NC}"
echo "1. Insert a USB drive containing a 'streamerData' folder"
echo "2. The system will automatically detect it"
echo "3. If 'Streamer-Viewer-Linux' exists on the USB, it will be copied to ~/Desktop"
echo "4. Streamer Viewer will launch automatically with --data-dir pointing to the USB"
echo ""
echo -e "${YELLOW}Manual usage:${NC}"
echo "• Run 'Streamer Viewer USB' from the applications menu"
echo "• Or execute: $MANUAL_LAUNCH_SCRIPT"
echo ""
echo -e "${YELLOW}Logs and troubleshooting:${NC}"
echo "• Check logs: tail -f /var/log/streamer-viewer-usb.log"
echo "• Test udev: sudo udevadm test /sys/block/sdX (replace X with your USB device)"
echo ""
echo -e "${BLUE}Ready! Insert a USB drive with streamerData to test.${NC}"