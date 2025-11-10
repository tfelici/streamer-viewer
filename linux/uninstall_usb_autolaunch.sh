#!/bin/bash

# RPI Streamer USB Auto-Launch Uninstaller for Linux
# This script removes the udev rule and scripts installed by install_usb_autolaunch.sh
# Usage: sudo ./uninstall_usb_autolaunch.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - must match install script
UDEV_RULE_FILE="/etc/udev/rules.d/99-rpi-streamer-usb.rules"
HANDLER_SCRIPT="/usr/local/bin/rpi-streamer-usb-handler.sh"
SYSTEMD_SERVICE="/etc/systemd/system/rpi-streamer-usb@.service"
SYSTEMD_REMOVAL_SERVICE="/etc/systemd/system/rpi-streamer-usb-remove@.service"
LOG_FILE="/var/log/rpi-streamer-usb.log"

echo -e "${BLUE}RPI Streamer USB Auto-Launch Uninstaller${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   echo "Usage: sudo ./uninstall_usb_autolaunch.sh"
   exit 1
fi

echo -e "${YELLOW}Removing RPI Streamer USB auto-launch components...${NC}"
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

# Remove systemd services
if [ -f "$SYSTEMD_SERVICE" ]; then
    systemctl stop "rpi-streamer-usb@*.service" 2>/dev/null || true
    rm -f "$SYSTEMD_SERVICE"
    echo -e "${GREEN}✓ Removed systemd add service: $SYSTEMD_SERVICE${NC}"
else
    echo -e "${YELLOW}• Systemd add service not found: $SYSTEMD_SERVICE${NC}"
fi

if [ -f "$SYSTEMD_REMOVAL_SERVICE" ]; then
    systemctl stop "rpi-streamer-usb-remove@*.service" 2>/dev/null || true
    rm -f "$SYSTEMD_REMOVAL_SERVICE"
    echo -e "${GREEN}✓ Removed systemd remove service: $SYSTEMD_REMOVAL_SERVICE${NC}"
else
    echo -e "${YELLOW}• Systemd remove service not found: $SYSTEMD_REMOVAL_SERVICE${NC}"
fi

# Reload systemd after removing services
systemctl daemon-reload

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
echo -e "${YELLOW}Note:${NC} The Viewer-linux executable on user desktops was not removed."
echo "Users can manually delete ~/Desktop/Viewer-linux if desired."