#!/bin/bash
#
# Streamer Viewer USB Auto-Launch Uninstaller for Linux
# 
# This script removes the udev rule and scripts installed by install_usb_autolaunch.sh
#
# Usage: sudo ./uninstall_usb_autolaunch.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - must match install script
UDEV_RULE_FILE="/etc/udev/rules.d/99-streamer-viewer-usb.rules"
HANDLER_SCRIPT="/usr/local/bin/streamer-viewer-usb-handler.sh"
DESKTOP_ENTRY="/usr/share/applications/streamer-viewer-usb.desktop"
MANUAL_LAUNCH_SCRIPT="/usr/local/bin/streamer-viewer-manual-usb-launch.sh"
LOG_FILE="/var/log/streamer-viewer-usb.log"

echo -e "${BLUE}Streamer Viewer USB Auto-Launch Uninstaller${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   echo "Usage: sudo ./uninstall_usb_autolaunch.sh"
   exit 1
fi

echo -e "${YELLOW}Removing Streamer Viewer USB auto-launch components...${NC}"
echo ""

# Remove udev rule
if [ -f "$UDEV_RULE_FILE" ]; then
    rm -f "$UDEV_RULE_FILE"
    echo -e "${GREEN}✓ Removed udev rule: $UDEV_RULE_FILE${NC}"
else
    echo -e "${YELLOW}• udev rule not found: $UDEV_RULE_FILE${NC}"
fi

# Remove handler script
if [ -f "$HANDLER_SCRIPT" ]; then
    rm -f "$HANDLER_SCRIPT"
    echo -e "${GREEN}✓ Removed handler script: $HANDLER_SCRIPT${NC}"
else
    echo -e "${YELLOW}• Handler script not found: $HANDLER_SCRIPT${NC}"
fi

# Remove manual launch script
if [ -f "$MANUAL_LAUNCH_SCRIPT" ]; then
    rm -f "$MANUAL_LAUNCH_SCRIPT"
    echo -e "${GREEN}✓ Removed manual launch script: $MANUAL_LAUNCH_SCRIPT${NC}"
else
    echo -e "${YELLOW}• Manual launch script not found: $MANUAL_LAUNCH_SCRIPT${NC}"
fi

# Remove desktop entry
if [ -f "$DESKTOP_ENTRY" ]; then
    rm -f "$DESKTOP_ENTRY"
    echo -e "${GREEN}✓ Removed desktop entry: $DESKTOP_ENTRY${NC}"
else
    echo -e "${YELLOW}• Desktop entry not found: $DESKTOP_ENTRY${NC}"
fi

# Ask about log file
if [ -f "$LOG_FILE" ]; then
    echo ""
    echo -e "${YELLOW}Log file found: $LOG_FILE${NC}"
    read -p "Do you want to remove the log file? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_FILE"
        echo -e "${GREEN}✓ Removed log file: $LOG_FILE${NC}"
    else
        echo -e "${YELLOW}• Keeping log file: $LOG_FILE${NC}"
    fi
fi

# Reload udev rules
echo ""
echo -e "${BLUE}Reloading udev rules...${NC}"
udevadm control --reload-rules
udevadm trigger
echo -e "${GREEN}✓ udev rules reloaded${NC}"

echo ""
echo -e "${GREEN}Uninstallation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The Streamer-Viewer-Linux executable on user desktops was not removed."
echo "Users can manually delete ~/Desktop/Streamer-Viewer-Linux if desired."