# Windows USB Autolaunch System

Automatically launches Streamer Viewer when a USB drive containing the application is inserted.

## Features

- **Automatic Detection**: Monitors USB insertion/removal in real-time using WMI events
- **Background Operation**: Runs silently via Task Scheduler, no console windows
- **Admin Support**: Properly requests and handles elevated privileges
- **Auto-Start**: Launches automatically at user login
- **Clean Shutdown**: Automatically stops the application when USB is removed
- **Robust Logging**: Detailed logs for troubleshooting

## Requirements

- Windows 10 or later
- Administrator privileges (for installation only)
- PowerShell 5.1 or later

## Installation

### Quick Install (Recommended)

**Option 1: Double-Click the Batch File (Easiest!)**
1. Extract the zip file
2. **Double-click** `INSTALL.bat`
3. Click "Yes" when prompted for administrator privileges
4. Done!

**Option 2: Right-click Method**
1. Extract the zip file
2. **Right-click** `install_usb_autolaunch.ps1`
3. Select **"Run with PowerShell"**
4. If you see a security error, try Option 1 or Option 3

**Option 3: Command Line (Works if other methods fail)**
1. Extract the zip file
2. Open PowerShell (no need for admin - script will auto-elevate)
3. Navigate to the extracted folder:
   ```powershell
   cd "C:\Users\YourName\Downloads\Windows-USB-Autolaunch"
   ```
4. Run with bypass:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install_usb_autolaunch.ps1
   ```

The installer will:
- Automatically request administrator privileges
- Copy the monitor script to `C:\Program Files\StreamerViewer\`
- Create a Task Scheduler task that runs at login
- Set appropriate PowerShell execution policy if needed
- Start the USB monitor (if requested)

### Troubleshooting Installation

**"Cannot be loaded. The file is not digitally signed"**
- Use Option 2 above with `-ExecutionPolicy Bypass`
- This is a Windows security feature for unsigned scripts

**"Access Denied" or "Requires Administrator"**
- The script will automatically request admin privileges
- Click "Yes" when the UAC prompt appears

## How It Works

### Architecture

```
User Login
    ↓
Task Scheduler starts usb-monitor.ps1
    ↓
Monitor registers WMI event watchers
    ↓
USB Inserted → Scan drive for Viewer-windows.exe + streamerData
    ↓
If found → Launch: Viewer-windows.exe --data-dir "X:\streamerData"
    ↓
USB Removed → Kill Viewer-windows.exe process
```

### USB Detection

The system looks for two items on the USB drive:
- `Viewer-windows.exe` - The application executable
- `streamerData/` - The data directory

If both are found, the application launches automatically with the correct data directory path.

### Background Monitoring

The monitor runs as a scheduled task with these characteristics:
- **Trigger**: At user logon
- **Privileges**: Highest (to access USB events)
- **Restart**: Auto-restarts on failure (up to 3 times)
- **Power**: Continues running on battery
- **Hidden**: No visible console window

## Usage

### Manual Control

**Start the monitor:**
```powershell
Start-ScheduledTask -TaskName "StreamerViewer USB Monitor"
```

**Stop the monitor:**
```powershell
Stop-ScheduledTask -TaskName "StreamerViewer USB Monitor"
```

**Check status:**
```powershell
Get-ScheduledTask -TaskName "StreamerViewer USB Monitor" | Get-ScheduledTaskInfo
```

### View Logs

The monitor creates detailed logs at:
```
%TEMP%\streamer-viewer-usb-monitor.log
```

To view the log in PowerShell:
```powershell
Get-Content "$env:TEMP\streamer-viewer-usb-monitor.log" -Tail 50 -Wait
```

Or open in Notepad:
```powershell
notepad "$env:TEMP\streamer-viewer-usb-monitor.log"
```

## Uninstallation

1. **Right-click** `uninstall_usb_autolaunch.ps1`
2. Select **"Run with PowerShell"** (will request admin privileges)
3. Confirm when prompted

The uninstaller will:
- Stop any running monitor processes
- Remove the scheduled task
- Delete installation files from `C:\Program Files\StreamerViewer\`
- Remove log files
- Leave the main Streamer Viewer application intact

## Troubleshooting

### Monitor Not Starting

1. Check if task exists:
   ```powershell
   Get-ScheduledTask -TaskName "StreamerViewer USB Monitor"
   ```

2. Check task history in Task Scheduler:
   - Press `Win + R`, type `taskschd.msc`
   - Navigate to "Task Scheduler Library"
   - Find "StreamerViewer USB Monitor"
   - Check "History" tab

3. Check execution policy:
   ```powershell
   Get-ExecutionPolicy -List
   ```

### USB Not Detected

1. Check the log file for errors
2. Verify USB drive contains both `Viewer-windows.exe` and `streamerData/` directory
3. Try manually running the monitor script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\Program Files\StreamerViewer\usb-monitor.ps1"
   ```

### Application Not Launching

1. Check if `Viewer-windows.exe` is executable (not corrupted)
2. Verify the `streamerData` directory has proper permissions
3. Check Windows Defender or antivirus isn't blocking execution
4. Review the log file for specific error messages

### Permission Issues

If you see "Access Denied" errors:
1. Re-run the installer as Administrator
2. Check that the Task Scheduler task has "Run with highest privileges" enabled
3. Verify your user account has proper permissions

## Technical Details

### WMI Event Queries

The monitor uses these WMI queries:

**USB Insertion:**
```sql
SELECT * FROM __InstanceCreationEvent WITHIN 2 
WHERE TargetInstance ISA 'Win32_USBHub'
```

**USB Removal:**
```sql
SELECT * FROM __InstanceDeletionEvent WITHIN 2 
WHERE TargetInstance ISA 'Win32_USBHub'
```

### Drive Detection

Uses `Win32_LogicalDisk` with `DriveType = 2` (Removable) to identify USB drives.

### Process Management

- Application launched via `Start-Process` with `-PassThru` to track the process
- Process terminated via `.Kill()` method when USB is removed
- Periodic health checks ensure process hasn't crashed

## Comparison with Linux Version

| Feature | Windows | Linux |
|---------|---------|-------|
| Detection Method | WMI Events | udev Rules |
| Service Manager | Task Scheduler | systemd |
| Privileges | Admin (install only) | sudo (install only) |
| Background Mode | Hidden PS Window | systemd service |
| Logging | %TEMP% directory | systemd journal |
| Auto-Start | Task Scheduler | systemd enable |

## Files

- `install_usb_autolaunch.ps1` - Installer script (requires admin)
- `uninstall_usb_autolaunch.ps1` - Uninstaller script (requires admin)
- `usb-monitor.ps1` - Background monitoring service
- `README.md` - This documentation

## Support

If you encounter issues:
1. Check the log file first
2. Verify admin privileges were used during installation
3. Ensure PowerShell execution policy allows scripts
4. Review Windows Event Viewer for system-level errors
