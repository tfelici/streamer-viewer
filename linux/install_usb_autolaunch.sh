#!/bin/bash

# RPI Streamer USB Autolaunch Installation Script
# This script sets up automatic launching of the Streamer Viewer when a USB drive with streamerData is inserted

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME=$(whoami)
MOUNT_POINT="/mnt/rpistreamer"
DESKTOP_DIR="$HOME/Desktop"
UDEV_RULE_FILE="/etc/udev/rules.d/99-rpi-streamer-usb.rules"
USB_HANDLER_SCRIPT="/usr/local/bin/rpi-streamer-usb-handler.sh"
SYSTEMD_SERVICE="/etc/systemd/system/rpi-streamer-usb@.service"
SYSTEMD_REMOVAL_SERVICE="/etc/systemd/system/rpi-streamer-usb-remove@.service"

echo "=== RPI Streamer USB Autolaunch Setup ==="
echo "Username: $USERNAME"
echo "Mount point: $MOUNT_POINT"
echo "Desktop directory: $DESKTOP_DIR"
echo

# Check if running as root for udev rule installation
if [[ $EUID -eq 0 ]]; then
   echo "Error: This script should not be run as root. Run as regular user, it will ask for sudo when needed."
   exit 1
fi

# Function to create the USB handler script
create_usb_handler() {
    echo "Creating USB handler script..."
    
    sudo tee "$USB_HANDLER_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash

# RPI Streamer USB Handler
# Triggered by udev when USB storage device is inserted

DEVICE="$1"
ACTION="$2"
USERNAME="$3"
LOGFILE="/var/log/rpi-streamer-usb.log"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Function to wait for device to be ready
wait_for_device() {
    local device="$1"
    local timeout=3
    local count=0
    
    log_message "Waiting for device $device to be ready..."
    
    while [ $count -lt $timeout ]; do
        # Check if device exists and has a filesystem
        if [ -b "$device" ] && blkid "$device" >/dev/null 2>&1; then
            log_message "Device $device is ready"
            return 0
        fi
        sleep 0.5
        count=$((count + 1))
        log_message "Waiting for device... ($count/$timeout)"
    done
    
    log_message "Timeout waiting for device $device to be ready"
    return 1
}

# Function to safely mount USB device
mount_usb() {
    local device="$1"
    local mount_point="/mnt/rpistreamer"
    
    log_message "Attempting to mount $device to $mount_point"
    
    # Wait for device to be ready
    if ! wait_for_device "$device"; then
        log_message "Device $device is not ready, aborting mount"
        return 1
    fi
    
    # Check if mount point is already in use
    if mountpoint -q "$mount_point"; then
        # Check if the same device is already mounted
        local current_device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null)
        if [ "$current_device" = "$device" ]; then
            log_message "Device $device is already mounted at $mount_point, skipping mount"
            return 0
        else
            log_message "Different device ($current_device) mounted at $mount_point, unmounting"
            
            # Just log that we're unmounting a different device
            log_message "Unmounting different device to mount new one"
            
            # Try normal unmount first
            if sudo umount "$mount_point" 2>/dev/null; then
                log_message "Successfully unmounted $mount_point"
            elif sudo umount -f "$mount_point" 2>/dev/null; then
                log_message "Successfully force unmounted $mount_point"
            elif sudo umount -l "$mount_point" 2>/dev/null; then
                log_message "Successfully lazy unmounted $mount_point"
            else
                log_message "Failed to unmount $mount_point completely"
                return 1
            fi
        fi
    fi
    
    # Create mount point if it doesn't exist
    sudo mkdir -p "$mount_point"
    sudo chown "$USERNAME:$USERNAME" "$mount_point"
    
    # Detect filesystem type
    local fs_type=$(blkid -o value -s TYPE "$device" 2>/dev/null)
    log_message "Detected filesystem type: $fs_type"
    
    # Try to mount the device with appropriate filesystem type
    local mount_cmd
    if [ -n "$fs_type" ]; then
        mount_cmd="mount -t $fs_type $device $mount_point"
    else
        mount_cmd="mount $device $mount_point"
    fi
    
    log_message "Mount command: $mount_cmd"
    
    if error_output=$(sudo $mount_cmd 2>&1); then
        log_message "Successfully mounted $device to $mount_point"
        return 0
    else
        log_message "Failed to mount $device - Error: $error_output"
        log_message "Trying fallback mount without fs type"
        # Fallback: try without specifying filesystem type
        if error_output2=$(sudo mount "$device" "$mount_point" 2>&1); then
            log_message "Successfully mounted $device to $mount_point (fallback)"
            return 0
        else
            log_message "Failed to mount $device completely - Error: $error_output2"
            return 1
        fi
    fi
}

# Function to check for streamerData folder
check_streamer_data() {
    local mount_point="/mnt/rpistreamer"
    
    if [ -d "$mount_point/streamerData" ]; then
        log_message "streamerData folder found on USB drive"
        return 0
    else
        log_message "streamerData folder not found, ignoring this drive"
        return 1
    fi
}

# Function to copy and update Viewer-linux
copy_viewer() {
    local mount_point="/mnt/rpistreamer"
    local cache_dir="/home/$USERNAME/.cache/streamer-viewer"
    local source_file="$mount_point/Viewer-linux"
    local dest_file="$cache_dir/Viewer-linux"
    
    if [ ! -f "$source_file" ]; then
        log_message "Viewer-linux not found on USB drive"
        return 1
    fi
    
    # Check if we need to copy (file doesn't exist or is different)
    if [ ! -f "$dest_file" ] || ! cmp -s "$source_file" "$dest_file"; then
        log_message "New version detected - terminating existing Viewer-linux processes"
        pkill -f "Viewer-linux" 2>/dev/null || true
        sleep 1
        
        log_message "Copying new version of Viewer-linux to cache directory"
        mkdir -p "$cache_dir"
        cp "$source_file" "$dest_file"
        chmod +x "$dest_file"
        chown "$USERNAME:$USERNAME" "$dest_file"
        log_message "Viewer-linux copied to cache and made executable"
        return 2  # Return 2 to indicate new version was copied
    else
        log_message "Viewer-linux is already up to date"
        return 0  # Return 0 to indicate no update needed
    fi
}

# Function to prepare for viewer launch
prepare_viewer() {
    local mount_point="/mnt/rpistreamer"
    local cache_dir="/home/$USERNAME/.cache/streamer-viewer"
    local viewer_executable="$cache_dir/Viewer-linux"
    
    if [ ! -f "$viewer_executable" ]; then
        log_message "Viewer-linux executable not found in cache directory"
        return 1
    fi
    
    log_message "Viewer preparation complete - systemd will start the service"
    return 0
}

# Function to handle USB device removal
handle_removal() {
    local device="$1"
    local mount_point="/mnt/rpistreamer"
    
    log_message "USB device removal detected: $device"
    
    # Check if our mount point is mounted
    if mountpoint -q "$mount_point"; then
        # Check if the removed device is the one mounted at our mount point
        local mounted_device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null)
        if [ "$mounted_device" = "$device" ]; then
            log_message "Removed device $device matches mounted device at $mount_point, unmounting"
            
            # Note: systemd service will stop the viewer service
            log_message "Preparing for viewer service stop and unmount"
            
            # Try gentle unmount first, then lazy unmount as fallback
            if sudo umount "$mount_point" 2>/dev/null; then
                log_message "Successfully unmounted $mount_point"
            elif sudo umount -l "$mount_point" 2>/dev/null; then
                log_message "Successfully lazy unmounted $mount_point"
            else
                log_message "Failed to unmount $mount_point - may still be in use"
            fi
        else
            log_message "Removed device $device does not match mounted device $mounted_device, ignoring"
        fi
    else
        log_message "Mount point $mount_point was not mounted, ignoring removal"
    fi
}

# Main execution
# Clear log file at start of each execution
> "$LOGFILE"

if [ "$ACTION" = "add" ] && [ -n "$DEVICE" ]; then
    log_message "USB device insertion detected: $DEVICE"
    
    # Always kill existing Viewer processes on USB insertion to ensure new data directory is used
    log_message "Terminating any existing Viewer-linux processes"
    pkill -f "Viewer-linux" 2>/dev/null || true
    sleep 2
    
    # Try to mount the device
    if mount_usb "$DEVICE"; then
        # Check for streamerData folder
        if check_streamer_data; then
            # Copy viewer executable and check if new version
            copy_result=$(copy_viewer)
            copy_exit_code=$?
            
            if [ $copy_exit_code -eq 0 ] || [ $copy_exit_code -eq 2 ]; then
                # Only launch if no existing viewer is running, or if we just updated
                if [ $copy_exit_code -eq 0 ] || [ $copy_exit_code -eq 2 ]; then
                    # Prepare for viewer launch (systemd will start the service)
                    prepare_viewer
                fi
            fi
        else
            # Unmount if this isn't an RPI Streamer drive
            umount "/media/$USERNAME/RPISTREAMER" 2>/dev/null || true
        fi
    fi
elif [ "$ACTION" = "remove" ]; then
    handle_removal "$DEVICE"
else
    log_message "Ignoring event: ACTION=$ACTION, DEVICE=$DEVICE"
fi
EOF

    sudo chmod +x "$USB_HANDLER_SCRIPT"
    echo "USB handler script created at $USB_HANDLER_SCRIPT"
}

# Function to create systemd services
create_systemd_service() {
    echo "Creating systemd services..."
    
    # Get user ID for running in desktop environment
    local user_id=$(id -u "$USERNAME")
    
    # Service for USB insertion (add) - directly triggers user service
    sudo tee "$SYSTEMD_SERVICE" > /dev/null << EOF
[Unit]
Description=RPI Streamer USB Handler for %i (Add)
DefaultDependencies=no

[Service]
Type=oneshot
User=$USERNAME
Environment=XDG_RUNTIME_DIR=/run/user/$user_id
ExecStartPre=/bin/bash -c '$USB_HANDLER_SCRIPT /dev/%i add $USERNAME'
ExecStart=/usr/bin/systemctl --user start viewer.service
RemainAfterExit=no
TimeoutSec=30

# Note: No [Install] section - this service is only started by udev USB events
EOF

    # Service for USB removal (remove) - directly stops user service
    sudo tee "$SYSTEMD_REMOVAL_SERVICE" > /dev/null << EOF
[Unit]
Description=RPI Streamer USB Handler for %i (Remove)
DefaultDependencies=no

[Service]
Type=oneshot
User=$USERNAME
Environment=XDG_RUNTIME_DIR=/run/user/$user_id
ExecStart=/usr/bin/systemctl --user stop viewer.service
ExecStartPost=/bin/bash -c '$USB_HANDLER_SCRIPT /dev/%i remove $USERNAME'
RemainAfterExit=no
TimeoutSec=10

# Note: No [Install] section - this service is only started by udev events
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    echo "Systemd services created and reloaded:"
    echo "  - Add service: $SYSTEMD_SERVICE"
    echo "  - Remove service: $SYSTEMD_REMOVAL_SERVICE"
}

# Function to create udev rule
create_udev_rule() {
    echo "Creating udev rule..."
    
    sudo tee "$UDEV_RULE_FILE" > /dev/null << EOF
# RPI Streamer USB Autolaunch Rule  
# Triggers systemd services when USB storage devices are inserted or removed

# Match USB storage devices partitions and trigger systemd service for ADD events
SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_FS_USAGE}=="filesystem", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}="rpi-streamer-usb@%k.service"

# Match USB storage devices partitions and trigger systemd service for REMOVE events  
SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ACTION=="remove", RUN+="/bin/systemctl start rpi-streamer-usb-remove@%k.service"
EOF

    echo "Udev rule created at $UDEV_RULE_FILE"
}

# Function to reload udev rules
reload_udev() {
    echo "Reloading udev rules..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "Udev rules reloaded"
}

# Function to create log file and set permissions
setup_logging() {
    echo "Setting up logging..."
    sudo touch /var/log/rpi-streamer-usb.log
    sudo chmod 666 /var/log/rpi-streamer-usb.log
    echo "Log file created at /var/log/rpi-streamer-usb.log"
}

# Function to create desktop directory if it doesn't exist
setup_desktop() {
    echo "Setting up desktop directory..."
    mkdir -p "$DESKTOP_DIR"
    echo "Desktop directory ready: $DESKTOP_DIR"
}

# Function to setup passwordless sudo for mount operations
setup_sudo_permissions() {
    echo "Setting up passwordless sudo for mount operations..."
    local sudoers_file="/etc/sudoers.d/rpi-streamer-mount"
    
    sudo tee "$sudoers_file" > /dev/null << EOF
# Allow $USERNAME to run mount/umount commands without password for RPI Streamer
$USERNAME ALL=(ALL) NOPASSWD: /bin/mount
$USERNAME ALL=(ALL) NOPASSWD: /bin/umount
$USERNAME ALL=(ALL) NOPASSWD: /bin/mkdir
$USERNAME ALL=(ALL) NOPASSWD: /bin/chown
EOF
    
    sudo chmod 440 "$sudoers_file"
    echo "Sudo permissions configured for mount operations"
}

# Function to create user systemd service for viewer
create_user_systemd_service() {
    echo "Creating user systemd service for viewer..."
    
    # Create user systemd directory
    sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.config/systemd/user"
    
    # Create cache directory and loading page
    sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.cache/streamer-viewer"
    
    # Create loading page directly
    sudo -u "$USERNAME" tee "/home/$USERNAME/.cache/streamer-viewer/loading.html" > /dev/null << 'EOF'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Streamer Viewer Loading</title>
<style>
body{margin:0;padding:0;
background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);
font-family:Arial,sans-serif;display:flex;justify-content:center;align-items:center;
height:100vh;color:white;
animation:backgroundPulse 3s ease-in-out infinite;}
.container{text-align:center;}
.loader{border:4px solid rgba(255,255,255,0.3);border-radius:50%;border-top:4px solid white;
width:60px;height:60px;animation:spin 1s linear infinite;margin:0 auto 30px;}
@keyframes spin{0%{transform:rotate(0deg)}100%{transform:rotate(360deg)}}
@keyframes backgroundPulse{
0%{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);}
50%{background:linear-gradient(135deg,#7b8ff0 0%,#8a5cb8 100%);}
100%{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);}}
h1{font-size:2.5em;margin-bottom:20px;font-weight:300;}
p{font-size:1.2em;opacity:0.8;margin:10px 0;}
</style></head><body>
<div class="container"><div class="loader"></div><h1>Streamer Viewer</h1>
<p>Loading GPS tracks and video recordings...</p></div>
</body></html>
EOF
    
    # Create the viewer service file
    sudo -u "$USERNAME" tee "/home/$USERNAME/.config/systemd/user/viewer.service" > /dev/null << EOF
[Unit]
Description=Start Streamer Viewer desktop app
DefaultDependencies=no

[Service]
Type=forking
ExecStartPre=/bin/sleep 3
ExecStart=/bin/bash -c 'firefox --kiosk file:///home/$USERNAME/.cache/streamer-viewer/loading.html & /home/$USERNAME/.cache/streamer-viewer/Viewer-linux --data-dir=/mnt/rpistreamer/streamerData &'
WorkingDirectory=/home/$USERNAME/.cache/streamer-viewer
Environment=QT_QPA_PLATFORM=wayland
Environment=MOZ_ENABLE_WAYLAND=1
ExecStop=/bin/bash -c 'pkill -f "firefox" || true; pkill -f "Viewer-linux" || true'
TimeoutStopSec=15
Restart=no

# Note: No [Install] section - this service is ONLY started manually by USB detection
# NEVER auto-starts on boot, login, or session start
EOF

    echo "User systemd service file created at /home/$USERNAME/.config/systemd/user/viewer.service"
    echo ""
    echo "IMPORTANT: You need to reload user systemd from your desktop session:"
    echo "  systemctl --user daemon-reload"
    echo ""
    echo "After installation, run this command from a desktop terminal (not SSH):"
    echo "  systemctl --user daemon-reload"
}

# Main installation process
main() {
    echo "Starting installation..."
    
    # Create necessary directories and setup
    setup_desktop
    setup_logging
    
    # Setup passwordless sudo for mount operations
    setup_sudo_permissions
    
    # Create user systemd service for viewer
    create_user_systemd_service
    
    # Create the USB handler script
    create_usb_handler
    
    # Create the systemd service
    create_systemd_service
    
    # Create the udev rule
    create_udev_rule
    
    # Reload udev rules
    reload_udev
    
    echo
    echo "=== Installation Complete ==="
    echo "System services have been installed and reloaded."
    echo
    echo "NEXT STEP: From your desktop terminal (not SSH), run:"
    echo "  systemctl --user daemon-reload"
    echo
    echo "What happens when you insert a USB drive:"
    echo "1. System detects USB insertion"
    echo "2. Mounts drive to: $MOUNT_POINT"
    echo "3. Checks for 'streamerData' folder"
    echo "4. If found, copies 'Viewer-linux' to cache"
    echo "5. Starts viewer.service via systemd --user"
    echo
    echo "To test manually:"
    echo "  sudo systemctl start rpi-streamer-usb@sdb1.service"
    echo
    echo "Log file location: /var/log/rpi-streamer-usb.log"
    echo "To monitor activity: tail -f /var/log/rpi-streamer-usb.log"
    echo
    echo "To uninstall, run: $SCRIPT_DIR/uninstall_usb_autolaunch.sh"
}

# Run main installation
main