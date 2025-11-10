# Streamer Viewer USB Auto-Launch for Linux

This directory contains scripts to set up automatic launching of Streamer Viewer when a USB drive containing `streamerData` is inserted on Linux systems.

## 📋 Overview

The USB auto-launch system consists of:

- **udev rule**: Detects USB device insertion
- **Handler script**: Checks for `streamerData` folder and manages executable
- **Auto-launch**: Automatically runs Streamer Viewer with correct `--data-dir`
- **Manual launcher**: GUI option for manual USB selection

## � Download

### Get Streamer Viewer Linux Executable

Before setting up USB auto-launch, you need the Linux executable:

**Download Options:**
- 🔗 **[Latest Release](https://github.com/tfelici/streamer-viewer/releases/latest)** - Download `Viewer-linux` from GitHub Releases
- 📦 **[All Releases](https://github.com/tfelici/streamer-viewer/releases)** - Browse all versions

**Setup:**
1. Download the `Viewer-linux` executable
2. Place it on your USB drive alongside the `streamerData` folder, OR
3. Copy it to `~/Desktop/Viewer-linux` manually
4. Make executable: `chmod +x Viewer-linux`

The USB auto-launch system will automatically copy/update the executable from USB to desktop when needed.

## 📥 Quick Download

**Installation Scripts:**
- 🔗 **[install_usb_autolaunch.sh](https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/install_usb_autolaunch.sh)** - Right-click → Save As
- 🔗 **[uninstall_usb_autolaunch.sh](https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/uninstall_usb_autolaunch.sh)** - Right-click → Save As

**Quick Installation:**
```bash
# Using curl
curl -O https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/install_usb_autolaunch.sh
chmod +x install_usb_autolaunch.sh
sudo ./install_usb_autolaunch.sh

# Or using wget
wget https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/install_usb_autolaunch.sh
chmod +x install_usb_autolaunch.sh
sudo ./install_usb_autolaunch.sh
```

## 🚀 Installation

### Prerequisites

- Linux system with udev (most modern distributions)
- Root/sudo access for installation
- Desktop environment with notification support (recommended)

### Install

```bash
# Make the installer executable
chmod +x install_usb_autolaunch.sh

# Run the installer with sudo
sudo ./install_usb_autolaunch.sh
```

## 📱 Usage

### Automatic Launch

1. **Prepare USB Drive**:
   ```
   USB Drive/
   ├── streamerData/
   │   ├── tracks/          # GPS track files (.tsv)
   │   └── recordings/      # Video files
   │       └── webcam/
   └── Viewer-linux  # (optional) Executable
   ```

2. **Insert USB Drive**: System automatically detects and launches Streamer Viewer

3. **Executable Management**:
   - If `Streamer-Viewer-Linux` exists on USB → copied to `~/Desktop`
   - If executable on USB is newer → updates desktop version
   - If no executable on USB → uses existing desktop version

### Manual Launch

- **Applications Menu**: Look for "Streamer Viewer USB"
- **Command Line**: `/usr/local/bin/streamer-viewer-manual-usb-launch.sh`

## 🔧 What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| udev rule | `/etc/udev/rules.d/99-streamer-viewer-usb.rules` | USB detection |
| Handler script | `/usr/local/bin/streamer-viewer-usb-handler.sh` | Main logic |
| Manual launcher | `/usr/local/bin/streamer-viewer-manual-usb-launch.sh` | GUI selection |
| Desktop entry | `/usr/share/applications/streamer-viewer-usb.desktop` | Menu entry |
| Log file | `/var/log/streamer-viewer-usb.log` | Activity logging |

## 📊 Monitoring and Troubleshooting

### View Logs
```bash
# Follow real-time logs
sudo tail -f /var/log/streamer-viewer-usb.log

# View recent activity
sudo tail -50 /var/log/streamer-viewer-usb.log
```

### Debug USB Auto-Launch Issues

**Step 1: Verify Installation**
```bash
# Check if udev rule exists
ls -la /etc/udev/rules.d/99-streamer-viewer-usb.rules

# Check if handler script exists
ls -la /usr/local/bin/streamer-viewer-usb-handler.sh

# Check if log file exists
ls -la /var/log/streamer-viewer-usb.log
```

**Step 2: Check udev Rule Status**
```bash
# Test if udev rules are loaded
sudo udevadm control --reload-rules
sudo udevadm trigger

# Check udev rule syntax
sudo udevadm test-builtin path_id /sys/block/sda  # Replace sda with your USB device
```

**Step 3: Monitor USB Events**
```bash
# Watch udev events in real-time (run this, then insert USB)
sudo udevadm monitor --property --subsystem-match=block

# Alternative: monitor all USB events
sudo udevadm monitor --kernel --udev --property
```

**Step 4: Manual USB Device Testing**
```bash
# Find your USB device
lsblk
sudo fdisk -l

# Check if your USB has the expected structure
mount | grep /media
ls -la /media/$USER/*/  # Check mounted USB drives
ls -la /media/$USER/*/streamerData/  # Look for streamerData folder
```

**Step 5: Test Handler Script Manually**
```bash
# Set environment variables and test handler directly
export ACTION="add"
export DEVNAME="/dev/sdb1"  # Replace with your USB device
sudo -E /usr/local/bin/streamer-viewer-usb-handler.sh
```

**Step 6: KDE Neon Specific Checks**
```bash
# Check if udisks2 is managing USB mounts (common in KDE)
systemctl status udisks2

# Check KDE's device notifier settings
# Go to System Settings → Hardware → Removable Storage

# Verify user is in plugdev group (needed for some USB operations)
groups $USER
```

### Test USB Detection
```bash
# Test udev rule (replace sdX with your USB device)
sudo udevadm test /sys/block/sdX

# Reload udev rules manually
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Manual Troubleshooting
```bash
# Check if USB drives are mounted
mount | grep /media
mount | grep /mnt

# Find streamerData folders
find /media /mnt -name "streamerData" -type d 2>/dev/null

# Check running instances
pgrep -f "Streamer-Viewer-Linux"
ps aux | grep -i streamer
```

## 🔄 How It Works

### Detection Flow
1. **USB Insertion** → udev detects block device
2. **Handler Script** → checks for filesystem
3. **Mount Check** → looks for existing mounts
4. **Temporary Mount** → mounts device if needed
5. **Folder Check** → searches for `streamerData/`
6. **Executable Management** → copies/updates if needed
7. **Launch** → starts Streamer Viewer with `--data-dir`

### Security Features
- Runs as actual user (not root)
- Checks file sizes and timestamps for updates
- Prevents multiple instances with same data directory
- Proper file permissions and ownership

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

## 🚫 Uninstallation

**Quick Uninstall:**
```bash
# Download and run uninstaller
curl -O https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/uninstall_usb_autolaunch.sh
chmod +x uninstall_usb_autolaunch.sh
sudo ./uninstall_usb_autolaunch.sh

# Or using wget
wget https://raw.githubusercontent.com/tfelici/streamer-viewer/main/linux/uninstall_usb_autolaunch.sh
chmod +x uninstall_usb_autolaunch.sh
sudo ./uninstall_usb_autolaunch.sh
```

**What gets removed**:
- udev rule and handler scripts
- Desktop entries and manual launcher
- Optionally: log file

**What remains**:
- `~/Desktop/Streamer-Viewer-Linux` (user can delete manually)
- User data and configurations

## 🐛 Common Issues

### USB Not Detected
- Check if device is properly mounted: `mount | grep /media`
- Verify udev rules are active: `sudo udevadm control --reload-rules`
- Check logs for errors: `sudo tail /var/log/streamer-viewer-usb.log`

### KDE Neon / Plasma Specific Issues
- **Device Notifier Conflict**: KDE's device notifier may interfere
  ```bash
  # Disable KDE's auto-actions temporarily
  # System Settings → Hardware → Removable Storage → uncheck auto-actions
  ```
- **udisks2 Integration**: KDE uses udisks2 for USB management
  ```bash
  # Check udisks2 service
  systemctl status udisks2
  
  # Monitor udisks2 events
  udisksctl monitor
  ```
- **Polkit Permissions**: Check if polkit is blocking udev actions
  ```bash
  # Check polkit rules
  sudo ls -la /etc/polkit-1/rules.d/
  
  # Add user to plugdev group if needed
  sudo usermod -a -G plugdev $USER
  ```

### Executable Not Copying
- Verify executable exists on USB and has correct name
- Check file permissions: `ls -la /path/to/usb/Streamer-Viewer-Linux`
- Ensure Desktop directory exists: `mkdir -p ~/Desktop`

### Application Won't Start  
- Check executable permissions: `chmod +x ~/Desktop/Streamer-Viewer-Linux`
- Verify data directory structure on USB
- Check for missing dependencies: `ldd ~/Desktop/Streamer-Viewer-Linux`

### Multiple Instances
- System prevents multiple instances with same data directory
- Close existing instance or use different USB drive
- Check running processes: `pgrep -f Streamer-Viewer-Linux`

## 💡 Tips

- **Performance**: Keep USB drives formatted as ext4 or NTFS for best compatibility
- **Backup**: Regularly backup `streamerData` from USB drives  
- **Updates**: New USB executable automatically updates desktop version
- **Monitoring**: Use log file to track USB usage and troubleshoot issues

## 🔗 Related Documentation

- [Main Streamer Viewer README](../README.md)
- [Command Line Arguments](../README.md#command-line-options)
- [udev Rules Documentation](https://wiki.archlinux.org/title/Udev)