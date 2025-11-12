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
            if umount "$mount_point" 2>/dev/null; then
                log_message "Successfully unmounted $mount_point"
            elif umount -f "$mount_point" 2>/dev/null; then
                log_message "Successfully force unmounted $mount_point"
            elif umount -l "$mount_point" 2>/dev/null; then
                log_message "Successfully lazy unmounted $mount_point"
            else
                log_message "Failed to unmount $mount_point completely"
                return 1
            fi
        fi
    fi
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point"
    chown "$USERNAME:$USERNAME" "$mount_point"
    
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
    
    if error_output=$($mount_cmd 2>&1); then
        log_message "Successfully mounted $device to $mount_point"
        return 0
    else
        log_message "Failed to mount $device - Error: $error_output"
        log_message "Trying fallback mount without fs type"
        # Fallback: try without specifying filesystem type
        if error_output2=$(mount "$device" "$mount_point" 2>&1); then
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
    local desktop_dir="/home/$USERNAME/Desktop"
    local source_file="$mount_point/Viewer-linux"
    local dest_file="$desktop_dir/Viewer-linux"
    
    if [ ! -f "$source_file" ]; then
        log_message "Viewer-linux not found on USB drive"
        return 1
    fi
    
    # Check if we need to copy (file doesn't exist or is different)
    if [ ! -f "$dest_file" ] || ! cmp -s "$source_file" "$dest_file"; then
        log_message "New version detected - killing existing Viewer-linux processes"
        pkill -f "Viewer-linux" 2>/dev/null || true
        sleep 1
        
        log_message "Copying new version of Viewer-linux to desktop"
        cp "$source_file" "$dest_file"
        chmod +x "$dest_file"
        chown "$USERNAME:$USERNAME" "$dest_file"
        log_message "Viewer-linux copied and made executable"
        return 2  # Return 2 to indicate new version was copied
    else
        log_message "Viewer-linux is already up to date"
        return 0  # Return 0 to indicate no update needed
    fi
}

# Function to launch the viewer application
launch_viewer() {
    local mount_point="/mnt/rpistreamer"
    local data_dir="$mount_point/streamerData"
    local desktop_dir="/home/$USERNAME/Desktop"
    local viewer_executable="$desktop_dir/Viewer-linux"
    
    if [ ! -f "$viewer_executable" ]; then
        log_message "Viewer-linux executable not found on desktop"
        return 1
    fi
    
    log_message "Launching Viewer-linux with data-dir=$data_dir"
    
    # Create a temporary output file to capture launch output
    local temp_output="/tmp/viewer-launch-$$.log"
    
    # Find active desktop session
    local active_display=""
    local session_user=""
    
    # Try to find active X11 session
    for display_socket in /tmp/.X11-unix/X*; do
        if [ -S "$display_socket" ]; then
            local display_num=":$(basename "$display_socket" | sed 's/X//')"
            local display_user=$(ps aux | grep "Xorg $display_num" | grep -v grep | awk '{print $1}' | head -1)
            if [ "$display_user" = "$USERNAME" ]; then
                active_display="$display_num"
                session_user="$USERNAME"
                break
            fi
        fi
    done
    
    # If no X11 found, check for Wayland
    if [ -z "$active_display" ]; then
        # Check for active Wayland session
        local wayland_session=$(loginctl list-sessions --no-legend | grep "$USERNAME" | grep "seat0" | awk '{print $1}' | head -1)
        if [ -n "$wayland_session" ]; then
            local session_type=$(loginctl show-session "$wayland_session" -p Type --value 2>/dev/null)
            if [ "$session_type" = "wayland" ]; then
                active_display="wayland-0"
                session_user="$USERNAME"
                log_message "Found wayland session: $wayland_session"
            elif [ "$session_type" = "x11" ]; then
                active_display=":0"
                session_user="$USERNAME"  
                log_message "Found x11 session: $wayland_session"
            fi
        fi
    fi
    
    if [ -z "$active_display" ]; then
        log_message "No active desktop session found for user $USERNAME"
        return 1
    fi
    
    log_message "Found active desktop session: $active_display for user $session_user"
    
    # Create mini-server script for loading page in cache directory
    local cache_dir="/home/$USERNAME/.cache/streamer-viewer"
    mkdir -p "$cache_dir"
    local loading_server="$cache_dir/loading-server.py"
    cat > "$loading_server" << 'LOADING_SERVER'
#!/usr/bin/env python3
import sys
import http.server
import socketserver
import json
import urllib.request
from urllib.parse import urlparse

class LoadingHandler(http.server.BaseHTTPRequestHandler):
    def __init__(self, *args, viewer_port=5001, **kwargs):
        self.viewer_port = viewer_port
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        if self.path == '/':
            self.serve_loading_page()
        elif self.path == '/check':
            self.check_main_server()
        else:
            self.send_error(404)
    
    def serve_loading_page(self):
        html = f'''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Streamer Viewer Loading</title>
<style>
body{{margin:0;padding:0;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);
font-family:Arial,sans-serif;display:flex;justify-content:center;align-items:center;
height:100vh;color:white;}}
.container{{text-align:center;}}
.loader{{border:4px solid rgba(255,255,255,0.3);border-radius:50%;border-top:4px solid white;
width:60px;height:60px;animation:spin 1s linear infinite;margin:0 auto 30px;}}
@keyframes spin{{0%{{transform:rotate(0deg)}}100%{{transform:rotate(360deg)}}}}
h1{{font-size:2.5em;margin-bottom:20px;font-weight:300;}}
p{{font-size:1.2em;opacity:0.8;margin:10px 0;}}
.status{{margin-top:30px;font-size:1em;opacity:0.6;}}
</style></head><body>
<div class="container"><div class="loader"></div><h1>Streamer Viewer</h1>
<p>Starting application...</p><p class="status" id="status">Initializing...</p></div>
<script>
let attempt=0;const maxAttempts=30;const status=document.getElementById('status');
function checkServer(){{
attempt++;status.textContent=`Connecting... (${{attempt}}/${{maxAttempts}})`;
fetch('/check').then(r=>r.json()).then(data=>{{
if(data.ready){{status.textContent='Ready! Redirecting...';
setTimeout(()=>window.location.href='http://localhost:{self.viewer_port}',500);}}
else throw new Error('Not ready');}}).catch(()=>{{
if(attempt<maxAttempts)setTimeout(checkServer,1000);
else{{status.textContent='Connection failed';status.style.color='#ffcccb';}}}});}}
setTimeout(checkServer,2000);
</script></body></html>'''
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def check_main_server(self):
        try:
            response = urllib.request.urlopen(f'http://localhost:{self.viewer_port}', timeout=1)
            ready = response.getcode() == 200
        except:
            ready = False
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'ready': ready}).encode())
    
    def log_message(self, format, *args): pass

if __name__ == '__main__':
    server_port = int(sys.argv[1])
    viewer_port = int(sys.argv[2])
    
    def handler_factory(*args, **kwargs):
        return LoadingHandler(*args, viewer_port=viewer_port, **kwargs)
    
    with socketserver.TCPServer(("", server_port), handler_factory) as httpd:
        httpd.serve_forever()
LOADING_SERVER

    chmod +x "$loading_server"
    chown "$session_user:$session_user" "$loading_server" 2>/dev/null || true

    # Find working port by actually trying to start mini-server
    log_message "Finding working port for mini-server starting from 5000..."
    local miniserver_port=""
    local viewer_port=""
    local server_pid=""
    
    # Try ports starting from 5000
    for port in $(seq 5000 5099); do
        log_message "Trying to start mini-server on port $port..."
        
        # Try to start the mini-server on this port
        python3 "$loading_server" "$port" "$((port + 1))" &
        server_pid=$!
        
        # Give it a moment to start
        sleep 0.5
        
        # Check if the process is still running and port is listening
        local port_listening=false
        if command -v ss >/dev/null 2>&1; then
            ss -tuln 2>/dev/null | grep -q ":$port " && port_listening=true
        else
            # Fallback: try to connect to the port using bash built-in
            (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null && port_listening=true
        fi
        
        if kill -0 "$server_pid" 2>/dev/null && [ "$port_listening" = "true" ]; then
            miniserver_port="$port"
            viewer_port="$((port + 1))"
            log_message "Mini-server successfully started on port $port, will use port $viewer_port for viewer"
            break
        else
            # Kill the process if it's still running but failed to bind
            kill "$server_pid" 2>/dev/null || true
            wait "$server_pid" 2>/dev/null || true
            log_message "Port $port failed, trying next port..."
        fi
    done
    
    if [ -z "$miniserver_port" ]; then
        log_message "ERROR: Could not start mini-server on any port from 5000-5099"
        return 1
    fi
    
    log_message "Using ports: mini-server=$miniserver_port, viewer=$viewer_port (PID: $server_pid)"

    # Launch application in user session
    # Get user ID for XDG_RUNTIME_DIR
    local user_id=$(id -u "$session_user")
    
    # Set appropriate display environment variable based on session type
    local display_var display_value
    if [ "$active_display" = "wayland-0" ]; then
        log_message "Starting wayland mini-server and launching Viewer application"
        # Detect actual Wayland display
        local wayland_display=$(sudo -u "$session_user" bash -c 'echo $WAYLAND_DISPLAY' 2>/dev/null)
        if [ -z "$wayland_display" ]; then
            wayland_display="wayland-0"
        fi
        display_var="WAYLAND_DISPLAY"
        display_value="$wayland_display"
    else
        log_message "Starting X11 mini-server and launching Viewer application"
        display_var="DISPLAY"
        display_value="$active_display"
    fi
    
    # Use systemd-run to create persistent user processes that survive sudo session termination
    # Note: mini-server is already running (PID: $server_pid), we just need to start Firefox and viewer
    sudo systemd-run --uid="$session_user" --gid="$session_user" \
        --setenv="$display_var=$display_value" \
        --setenv=XDG_RUNTIME_DIR="/run/user/$user_id" \
        --working-directory="$desktop_dir" \
        bash -c "
            # Mini-server is already running, just open Firefox with loading page
            firefox --kiosk http://localhost:$miniserver_port &
            FIREFOX_PID=\$!
            sleep 1
            
            # Start the main Viewer application in server-only mode with custom port
            '$viewer_executable' --data-dir='$data_dir' --server-only --port='$viewer_port' &
            VIEWER_PID=\$!
            
            # Wait for viewer process to keep systemd service alive
            wait \$VIEWER_PID
        "
    log_message "Viewer application launched successfully"
    
    # Wait a moment for initial output
    sleep 2
    
    # Log any initial output
    if [ -f "$temp_output" ]; then
        local output_content=$(cat "$temp_output" 2>/dev/null)
        if [ -n "$output_content" ]; then
            log_message "Viewer-linux initial output: $output_content"
        else
            log_message "Viewer-linux started with no initial output"
        fi
        rm -f "$temp_output"
    fi
    
    # Check if process is running
    local pid_file="/tmp/viewer-pid-$$"
    if [ -f "$pid_file" ]; then
        local viewer_pid=$(cat "$pid_file" 2>/dev/null)
        rm -f "$pid_file"
        if [ -n "$viewer_pid" ] && kill -0 "$viewer_pid" 2>/dev/null; then
            log_message "Viewer-linux launched successfully with PID: $viewer_pid"
        else
            log_message "Viewer-linux process not found after launch attempt"
            return 1
        fi
    else
        log_message "Viewer-linux launched in background"
    fi
    
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
            
            # Kill any running Viewer-linux processes that might be using the mount
            pkill -f "Viewer-linux" 2>/dev/null || true
            
            # Kill Firefox browser processes (kiosk mode)
            pkill -f "firefox.*localhost:" 2>/dev/null || true
            pkill firefox 2>/dev/null || true
            
            # Kill mini loading server (both systemd and standalone processes)
            pkill -f "loading-server.py" 2>/dev/null || true
            pkill -f "python3.*loading-server.py" 2>/dev/null || true
            # Also kill any python processes listening on ports 5000-5099 (our mini-servers)
            if command -v ss >/dev/null 2>&1; then
                for port in $(seq 5000 5099); do
                    local pids=$(ss -tlnp 2>/dev/null | grep ":$port " | grep -o 'pid=[0-9]*' | cut -d= -f2)
                    for pid in $pids; do
                        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
                    done
                done 2>/dev/null || true
            fi
            # Note: Without ss or netstat, we rely on pkill to catch the processes by name
            sleep 1
            
            # Clean up cache directory and temporary files
            local cache_dir="/home/$USERNAME/.cache/streamer-viewer"
            if [ -d "$cache_dir" ]; then
                log_message "Cleaning up cache directory: $cache_dir"
                rm -rf "$cache_dir"
                log_message "Cache directory cleaned up"
            fi
            
            # Clean up any remaining temporary files
            rm -f /tmp/viewer-launch-*.log 2>/dev/null || true
            rm -f /tmp/viewer-pid-* 2>/dev/null || true
            
            # Try gentle unmount first, then lazy unmount as fallback
            if umount "$mount_point" 2>/dev/null; then
                log_message "Successfully unmounted $mount_point"
            elif umount -l "$mount_point" 2>/dev/null; then
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
                if [ $copy_exit_code -eq 2 ] || ! pgrep -f "Viewer-linux.*rpistreamer" >/dev/null; then
                    # Launch the viewer
                    launch_viewer
                else
                    log_message "Viewer-linux already running with same version, not launching duplicate"
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
    
    # Service for USB insertion (add)
    sudo tee "$SYSTEMD_SERVICE" > /dev/null << EOF
[Unit]
Description=RPI Streamer USB Handler for %i (Add)
DefaultDependencies=false

[Service]
Type=oneshot
ExecStart=/bin/bash -c '$USB_HANDLER_SCRIPT /dev/%i add $USERNAME'
RemainAfterExit=no
TimeoutSec=30
EOF

    # Service for USB removal (remove)
    sudo tee "$SYSTEMD_REMOVAL_SERVICE" > /dev/null << EOF
[Unit]
Description=RPI Streamer USB Handler for %i (Remove)
DefaultDependencies=false

[Service]
Type=oneshot
ExecStart=/bin/bash -c '$USB_HANDLER_SCRIPT /dev/%i remove $USERNAME'
RemainAfterExit=no
TimeoutSec=10
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    echo "Systemd services created:"
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

# Main installation process
main() {
    echo "Starting installation..."
    
    # Create necessary directories and setup
    setup_desktop
    setup_logging
    
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
    echo "The USB autolaunch system is now installed and active."
    echo
    echo "What happens when you insert a USB drive:"
    echo "1. System detects USB insertion"
    echo "2. Mounts drive to: $MOUNT_POINT"
    echo "3. Checks for 'streamerData' folder"
    echo "4. If found, copies 'Viewer-linux' to desktop (if different)"
    echo "5. Launches: Viewer-linux --data-dir=$MOUNT_POINT/streamerData"
    echo
    echo "Log file location: /var/log/rpi-streamer-usb.log"
    echo "To monitor activity: tail -f /var/log/rpi-streamer-usb.log"
    echo
    echo "To uninstall, run: $SCRIPT_DIR/uninstall_usb_autolaunch.sh"
}

# Run main installation
main