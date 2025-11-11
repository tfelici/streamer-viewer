# Streamer Viewer USB Autolaunch System for Linux

A professional USB autolaunch system that automatically detects and launches Streamer Viewer when a USB drive containing `streamerData` is inserted. Features a sophisticated loading experience, Wayland/X11 compatibility, and reliable process management.

## 🎯 Overview

The USB autolaunch system provides a seamless plug-and-play experience for Streamer Viewer deployment:

### ✨ Key Features
- **🔌 Plug-and-Play Operation**: Automatic detection when USB with `streamerData` is inserted
- **🎬 Professional Loading Experience**: Animated loading screen with connection status
- **🖥️ Desktop Environment Support**: Compatible with Wayland and X11 systems
- **⚡ Smart Process Management**: Uses systemd-run for reliable background operation
- **🔄 Auto-Update System**: Automatically updates viewer executable from USB
- **🧹 Intelligent Cleanup**: Proper cleanup and unmounting on USB removal
- **📊 Comprehensive Logging**: Detailed logging for monitoring and troubleshooting

### 🏗️ System Architecture
- **udev Rules**: Detect USB insertion/removal events
- **systemd Services**: Manage process lifecycle with persistence
- **Mini HTTP Server**: Professional loading page on `localhost:5000`
- **Main Application**: Launches in server-only mode on `localhost:5001`
- **Browser Integration**: Firefox kiosk mode for seamless presentation

## 🚀 Quick Installation

### One-Line Installation

**Stable Version (main branch):**
```bash
# Download and install in one command (cache-busted)
curl -sSL "https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/install_usb_autolaunch.sh?$(date +%s)" | bash
```

**Development Version (develop branch):**
```bash
# Download and install development version (cache-busted)
curl -sSL "https://raw.githubusercontent.com/tfelici/streamer-viewer/develop/linux/install_usb_autolaunch.sh?$(date +%s)" | bash
```

### What Gets Installed
The installer creates a complete autolaunch system:

| Component | Location | Purpose |
|-----------|----------|---------|
| **udev Rules** | `/etc/udev/rules.d/99-rpi-streamer-usb.rules` | USB detection triggers |
| **Handler Script** | `/usr/local/bin/rpi-streamer-usb-handler.sh` | Main autolaunch logic |
| **systemd Services** | `/etc/systemd/system/rpi-streamer-usb*.service` | Process management |
| **Log File** | `/var/log/rpi-streamer-usb.log` | Activity logging |
| **Mount Point** | `/mnt/rpistreamer` | USB mounting location |

## 📋 Prerequisites

### System Requirements
- **Linux Distribution**: Any modern Linux with systemd and udev
- **Desktop Environment**: X11 or Wayland compatible
- **Permissions**: sudo access for installation
- **Browser**: Firefox (for kiosk presentation)
- **Python**: Python 3.6+ (for mini-server and main application)

### Supported Desktop Environments
✅ **Fully Tested:**
- GNOME (Ubuntu, Fedora)
- KDE Plasma (KDE Neon, openSUSE)
- XFCE (Xubuntu)
- Cinnamon (Linux Mint)

✅ **Compatible:**
- MATE, LXDE, LXQt, Budgie
- Wayland and X11 sessions
- Most systemd-based distributions

## � USB Drive Setup

### Required Directory Structure
Your USB drive must contain a `streamerData` folder with GPS tracks and video recordings:

```
USB_Drive/
├── streamerData/              # Required: Main data directory
│   ├── tracks/                # GPS track files (.tsv format)
│   │   ├── 2024-01-15_10-30-45.tsv
│   │   ├── flight_001.tsv
│   │   └── ...
│   └── recordings/            # Video recordings
│       └── webcam/            # Webcam video files
│           ├── 2024-01-15_10-30-45.mp4
│           ├── 2024-01-15_10-35-12.mp4
│           └── ...
└── Viewer-linux               # Optional: Latest executable
```

### Getting the Viewer-linux Executable

**Option 1: Download from Releases**
```bash
# Download latest release
wget https://github.com/tfelici/streamer-viewer/releases/latest/download/Viewer-linux

# Make executable and place on USB
chmod +x Viewer-linux
cp Viewer-linux /path/to/your/usb/
```

**Option 2: Build from Source** 
```bash
# Clone and build
git clone https://github.com/tfelici/streamer-viewer.git
cd streamer-viewer
pip install -r requirements.txt
pyinstaller StreamerViewer.spec

# Copy to USB
cp dist/StreamerViewer/StreamerViewer /path/to/your/usb/Viewer-linux
```

## 🎬 How It Works

### Complete Autolaunch Flow

1. **🔌 USB Detection**
   - udev detects USB insertion event
   - Triggers systemd service for device processing

2. **📁 Content Verification**  
   - Mounts USB device to `/mnt/rpistreamer`
   - Searches for `streamerData` folder
   - Validates directory structure

3. **🔄 Executable Management**
   - Checks for `Viewer-linux` on USB drive
   - Compares with existing desktop version
   - Updates if newer version found

4. **🖥️ Desktop Session Detection**
   - Identifies active X11 or Wayland session
   - Locates correct user and display environment
   - Sets appropriate environment variables

5. **🎭 Professional Loading Experience**
   - Creates mini HTTP server on `localhost:5000`
   - Generates animated loading page with connection status
   - Opens Firefox in kiosk mode immediately

6. **⚡ Application Launch**
   - Launches Viewer-linux in server-only mode (`--server-only`)
   - Main application runs on `localhost:5001`
   - Uses systemd-run for persistent background operation

7. **🔗 Seamless Transition**
   - Loading page polls main server until ready
   - Automatic redirect to full application
   - User sees smooth, professional startup experience

### Process Architecture

**systemd-run Management:**
```bash
# Example of how processes are launched
sudo systemd-run --uid=user --gid=user \
    --setenv=DISPLAY=:0 \
    --setenv=XDG_RUNTIME_DIR=/run/user/1000 \
    --working-directory=/home/user/Desktop \
    bash -c "
        # Mini loading server
        python3 loading-server.py &
        
        # Firefox kiosk mode  
        firefox --kiosk http://localhost:5000 &
        
        # Main Streamer Viewer application
        ./Viewer-linux --data-dir=/mnt/rpistreamer/streamerData --server-only &
        
        wait  # Keep systemd service alive
    "
```

### USB Removal Handling

1. **🔍 Detection**: udev detects USB removal event
2. **🛑 Process Termination**: Kills all related processes (viewer, Firefox, mini-server)
3. **🧹 Cleanup**: Removes cache files and temporary data
4. **📤 Unmounting**: Safely unmounts USB device
5. **📝 Logging**: Records removal event and cleanup status

## � Monitoring & Troubleshooting

### Real-Time Log Monitoring
```bash
# Follow autolaunch activity in real-time
tail -f /var/log/rpi-streamer-usb.log

# View recent activity
tail -50 /var/log/rpi-streamer-usb.log

# Search for specific events
grep -i "error\|failed\|success" /var/log/rpi-streamer-usb.log
```

### System Status Checks
```bash
# Verify installation components
ls -la /etc/udev/rules.d/99-rpi-streamer-usb.rules
ls -la /usr/local/bin/rpi-streamer-usb-handler.sh
ls -la /etc/systemd/system/rpi-streamer-usb*.service

# Check systemd services status
systemctl status rpi-streamer-usb@sdb1.service
systemctl status rpi-streamer-usb-remove@sdb1.service

# Reload udev rules if needed
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### USB Detection Testing
```bash
# Monitor USB events in real-time
sudo udevadm monitor --property --subsystem-match=block

# Test specific USB device (replace sdb1 with your device)
sudo udevadm test /sys/block/sdb/sdb1

# List currently mounted USB devices
lsblk
mount | grep /media
findmnt -D
```

### Process Management
```bash
# Check running Streamer Viewer processes
pgrep -f "Viewer-linux"
ps aux | grep -E "(Viewer-linux|firefox.*localhost|python3.*loading-server)"

# Kill processes manually if needed
pkill -f "Viewer-linux"
pkill -f "firefox.*localhost"
pkill -f "python3.*loading-server"

# Check systemd-run processes
systemctl list-units --type=service | grep run-
```

## � Common Issues & Solutions

### USB Not Being Detected

**Problem**: USB drive inserted but nothing happens
```bash
# Check udev rule is active
sudo udevadm control --reload-rules
sudo udevadm trigger

# Monitor USB events (insert USB while running)
sudo udevadm monitor --property --subsystem-match=block

# Verify streamerData folder exists
find /media /mnt /run/media -name "streamerData" -type d 2>/dev/null
```

**Solution**: Verify USB has correct folder structure and udev rules are loaded

### Application Won't Start

**Problem**: USB detected but Viewer-linux doesn't launch
```bash
# Check log for errors
tail -20 /var/log/rpi-streamer-usb.log | grep -i error

# Verify executable permissions
ls -la ~/Desktop/Viewer-linux
chmod +x ~/Desktop/Viewer-linux

# Test manual launch
~/Desktop/Viewer-linux --data-dir=/mnt/rpistreamer/streamerData --server-only
```

**Solution**: Ensure executable has proper permissions and dependencies

### Firefox/Loading Page Issues

**Problem**: Firefox doesn't open or loading page not working
```bash
# Test Firefox availability
which firefox
firefox --version

# Check if loading server started
ss -tlnp | grep :5000
curl -s http://localhost:5000

# Test kiosk mode manually
firefox --kiosk http://localhost:5000
```

**Solution**: Install Firefox or configure alternative browser in handler script

### Wayland/X11 Compatibility

**Problem**: Application launches but no window appears
```bash
# Check current session type
echo $XDG_SESSION_TYPE
loginctl list-sessions

# Verify display environment
echo $DISPLAY
echo $WAYLAND_DISPLAY

# Check running user processes
ps aux | grep -E "(gnome|kde|xfce)" | head -5
```

**Solution**: systemd-run handles environment automatically, but verify user session is active

### Process Persistence Issues

**Problem**: Processes die when terminal closes
```bash
# Check if systemd-run is working
systemctl list-units --type=service | grep run-

# View systemd journal for errors
journalctl -u "run-*" -n 20

# Test systemd-run manually
sudo systemd-run --uid=$USER --gid=$USER bash -c "sleep 30 & wait"
```

**Solution**: systemd-run provides process persistence - check systemd configuration

### Permission Problems

**Problem**: "Permission denied" errors in logs
```bash
# Check file ownership
ls -la /mnt/rpistreamer/
ls -la ~/Desktop/Viewer-linux

# Verify user groups
groups $USER
id $USER

# Fix ownership if needed
sudo chown $USER:$USER ~/Desktop/Viewer-linux
sudo chmod +x ~/Desktop/Viewer-linux
```

**Solution**: Ensure proper file permissions and user groups

## ⚙️ Advanced Configuration

### Customizing the Handler Script

Edit `/usr/local/bin/rpi-streamer-usb-handler.sh` to customize behavior:

```bash
# Edit handler script
sudo nano /usr/local/bin/rpi-streamer-usb-handler.sh
```

**Common Customizations:**

**Change Desktop Location:**
```bash
# Around line 15
DESKTOP_DIR="$HOME/Desktop"
# Change to:
DESKTOP_DIR="$HOME/Applications"  # or your preferred location
```

**Custom Executable Name:**
```bash
# Around line 180
local viewer_executable="$desktop_dir/Viewer-linux"  
# Change to:
local viewer_executable="$desktop_dir/MyCustomName"
```

**Alternative Browser:**
```bash
# Around line 370
firefox --kiosk http://localhost:5000 &
# Change to:
chromium --kiosk --app=http://localhost:5000 &
# or:
google-chrome --kiosk --app=http://localhost:5000 &
```

**Custom Loading Server Port:**
```bash
# Around line 300 (in loading server script)
with socketserver.TCPServer(("", 5000), LoadingHandler) as httpd:
# Change to:
with socketserver.TCPServer(("", 8080), LoadingHandler) as httpd:
```

### Environment-Specific Settings

**KDE Plasma Integration:**
```bash
# Disable KDE device notifier conflicts
# System Settings → Hardware → Removable Storage
# Uncheck "Enable automatic mounting of removable media"
```

**GNOME Settings:**
```bash
# Configure GNOME automount behavior
gsettings set org.gnome.desktop.media-handling automount false
gsettings set org.gnome.desktop.media-handling autorun-never true
```

**Network Access Configuration:**
If deploying on systems without internet access, modify the loading server to use local resources:
```bash
# Edit loading server HTML (around line 250 in handler script)
# Remove external CDN references and use local assets
```

## 🗂️ Directory Structure Expected

### Minimal USB Structure
```
USB_Drive/
└── streamerData/
    ├── tracks/           # GPS tracks (.tsv files)
    └── recordings/       # Video recordings
        └── webcam/       # Organized by domain/rtmpkey/
            └── domain/
                └── rtmpkey/
                    └── timestamp.mp4
```

### Full USB Structure
```
USB_Drive/
├── streamerData/
│   ├── tracks/
│   │   ├── 1234567890.tsv
│   │   └── 1234567891.tsv
│   └── recordings/
│       └── webcam/
│           └── gyropilots/
│               └── 12345678/
│                   ├── 1634567890.mp4
│                   └── 1634567891.mp4
└── Viewer-linux     # Auto-copied to Desktop
```

## ⚙️ Configuration

### Customization Options

Edit `/usr/local/bin/streamer-viewer-usb-handler.sh` to customize:

- **Desktop Location**: Change `DESKTOP_DIR` variable
- **Executable Name**: Modify `Streamer-Viewer-Linux` references  
- **Mount Points**: Add custom mount paths to search
- **Notification Settings**: Adjust `notify-send` parameters

### Multiple Executables

To support different executable names:
```bash
# Edit the handler script
sudo nano /usr/local/bin/streamer-viewer-usb-handler.sh

# Change the executable detection logic around line 80
USB_EXECUTABLE="$mount_point/Your-Custom-Executable-Name"
```

## 🗑️ Uninstallation

### Complete Removal

**One-Line Uninstall:**
```bash
# Stable version
curl -sSL "https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/uninstall_usb_autolaunch.sh?$(date +%s)" | bash

# Development version  
curl -sSL "https://raw.githubusercontent.com/tfelici/streamer-viewer/develop/linux/uninstall_usb_autolaunch.sh?$(date +%s)" | bash
```

### Manual Uninstallation
If the uninstaller is unavailable, remove components manually:

```bash
# Remove udev rules
sudo rm -f /etc/udev/rules.d/99-rpi-streamer-usb.rules

# Remove systemd services  
sudo systemctl stop rpi-streamer-usb@*.service 2>/dev/null
sudo systemctl disable rpi-streamer-usb@*.service 2>/dev/null
sudo rm -f /etc/systemd/system/rpi-streamer-usb*.service
sudo systemctl daemon-reload

# Remove handler script
sudo rm -f /usr/local/bin/rpi-streamer-usb-handler.sh

# Remove log file (optional)
sudo rm -f /var/log/rpi-streamer-usb.log

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### What Remains After Uninstallation
- **~/Desktop/Viewer-linux**: User executable (remove manually if desired)
- **~/.cache/streamer-viewer**: Cache directory (cleaned automatically)
- **User Data**: streamerData folders on USB drives remain unchanged

## 🔗 Integration with Main Application

### Server-Only Mode Integration
The autolaunch system leverages the main application's server-only mode:

```bash
# How the autolaunch calls the main application
./Viewer-linux --data-dir="/mnt/rpistreamer/streamerData" --server-only
```

This integration provides:
- **Headless Operation**: No GUI components loaded
- **Resource Efficiency**: Lower memory usage  
- **Browser Access**: Full functionality via web interface
- **API Access**: RESTful endpoints available

### Cross-Platform Compatibility
While this autolaunch system is Linux-specific, the main Streamer Viewer application supports:
- **Windows**: Desktop mode with webview or browser
- **macOS**: Native app bundles with webview
- **Linux**: Both desktop and server-only modes

See the [main README](../README.md) for complete cross-platform usage information.

## 📚 Technical References

### systemd-run Documentation
- **Process Management**: [systemd-run man page](https://www.freedesktop.org/software/systemd/man/systemd-run.html)
- **User Services**: [systemd user services guide](https://wiki.archlinux.org/title/Systemd/User)

### udev Documentation  
- **Rules Syntax**: [udev rules writing guide](https://wiki.archlinux.org/title/Udev)
- **USB Device Detection**: [Linux USB device handling](https://www.kernel.org/doc/html/latest/driver-api/usb/hotplug.html)

### Desktop Environment Integration
- **Wayland Protocol**: [Wayland display server](https://wayland.freedesktop.org/)
- **X11 Display**: [X Window System](https://www.x.org/wiki/)
- **Desktop Files**: [Desktop entry specification](https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html)

## � Best Practices & Tips

### USB Drive Optimization
- **File System**: Use ext4, NTFS, or exFAT for best compatibility
- **Performance**: USB 3.0+ recommended for large video files
- **Labeling**: Use descriptive labels (optional) - system detects by content
- **Backup**: Regularly backup `streamerData` folders

### Security Considerations
- **File Permissions**: System runs as user (not root) for security
- **Network Access**: Only local ports used (5000, 5001)
- **Process Isolation**: systemd-run provides process containerization
- **Clean Shutdown**: USB removal properly terminates all processes

### Performance Tuning
```bash
# Monitor resource usage
htop
iostat -x 1

# Check USB transfer speeds
sudo hdparm -tT /dev/sdb  # Replace with your USB device

# Optimize mount options in handler script if needed
mount -o noatime,nodiratime /dev/sdb1 /mnt/rpistreamer
```

### Multi-User Environments
- Each user needs separate installation
- Log files are system-wide in `/var/log/`
- Desktop executables are per-user in `~/Desktop/`
- Mount point `/mnt/rpistreamer` is shared

### Development & Testing
```bash
# Test autolaunch without USB insertion
sudo ACTION=add DEVICE=/dev/sdb1 USERNAME=$USER /usr/local/bin/rpi-streamer-usb-handler.sh

# Simulate USB removal
sudo ACTION=remove DEVICE=/dev/sdb1 USERNAME=$USER /usr/local/bin/rpi-streamer-usb-handler.sh

# Debug mode (add to handler script)
set -x  # Enable bash debugging

# Test mini-server independently
cd ~/.cache/streamer-viewer
python3 loading-server.py
# Visit http://localhost:5000
```

## 📈 Version History

### v2.2 (Current) - Professional USB Autolaunch
- **systemd-run Integration**: Reliable process management with session persistence
- **Professional Loading Experience**: Animated loading screen with connection status
- **Wayland Compatibility**: Full support for modern desktop environments  
- **Server-Only Mode**: Integrated headless operation support
- **Enhanced Cleanup**: Comprehensive USB removal handling

### v2.1 - Enhanced Reliability
- **Improved Detection**: Better USB device recognition
- **Process Management**: Enhanced background process handling
- **Cross-Desktop Support**: KDE, GNOME, XFCE compatibility

### v2.0 - Initial USB Autolaunch
- **Basic Autolaunch**: Simple USB detection and application launch
- **Desktop Integration**: Application menu entries
- **Logging System**: Basic activity logging

## 🤝 Support & Contributing

### Getting Help
- **Documentation**: [Main Streamer Viewer README](../README.md)
- **Issues**: [GitHub Issues](https://github.com/tfelici/streamer-viewer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tfelici/streamer-viewer/discussions)

### Reporting Issues
When reporting autolaunch issues, include:
```bash
# System information
uname -a
lsb_release -a
systemctl --version

# USB device info
lsblk
mount | grep /media

# Recent log entries
tail -50 /var/log/rpi-streamer-usb.log

# udev rule status
sudo udevadm control --reload-rules
sudo udevadm test /sys/block/sdb/sdb1  # Replace with your device
```

### Contributing Improvements
- **Fork & PR**: Standard GitHub workflow
- **Testing**: Test on different Linux distributions
- **Documentation**: Update this README for new features

### Linux Distribution Testing
**Confirmed Working:**
- Ubuntu 20.04, 22.04, 24.04
- KDE Neon (latest)
- Linux Mint 21, 22
- Fedora 38, 39
- openSUSE Tumbleweed

**Community Testing Needed:**
- Arch Linux, Manjaro
- Debian 12
- CentOS Stream, Rocky Linux
- Elementary OS

## 📄 License & Credits

This USB autolaunch system is part of the Streamer Viewer project and inherits the same license terms.

**Key Technologies:**
- **systemd**: Process management and service lifecycle
- **udev**: USB device detection and rule processing  
- **Python**: Mini-server implementation and main application
- **Firefox**: Kiosk mode presentation layer
- **Linux Desktop Standards**: FreeDesktop.org specifications

---

*For the complete Streamer Viewer documentation, see the [main README](../README.md).*