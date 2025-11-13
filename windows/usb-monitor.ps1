# USB Monitor for Streamer Viewer
# Monitors USB insertion/removal and launches Viewer-windows.exe automatically

$LogFile = "$env:TEMP\streamer-viewer-usb-monitor.log"
$ProcessName = "Viewer-windows"
$CurrentDriveLetter = $null

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Host "$timestamp - $Message"
}

function Test-StreamerUSB {
    param($DriveLetter)
    
    $exePath = "${DriveLetter}:\Viewer-windows.exe"
    $dataPath = "${DriveLetter}:\streamerData"
    
    if ((Test-Path $exePath) -and (Test-Path $dataPath)) {
        return @{
            Found = $true
            ExePath = $exePath
            DataPath = $dataPath
        }
    }
    return @{ Found = $false }
}

function Start-StreamerViewer {
    param($ExePath, $DataPath, $DriveLetter)
    
    try {
        Write-Log "Starting Streamer Viewer: $ExePath --data-dir `"$DataPath`" --fullscreen"
        $process = Start-Process -FilePath $ExePath -ArgumentList "--data-dir", "`"$DataPath`"", "--fullscreen" -PassThru
        Write-Log "Started process with PID: $($process.Id) (app will open in fullscreen)"
        
        # Wait for window to appear and bring to foreground
        Start-Sleep -Seconds 2
        
        # Define Windows API to bring window to foreground
        if (-not ([System.Management.Automation.PSTypeName]'User32').Type) {
            Add-Type @"
                using System;
                using System.Runtime.InteropServices;
                public class User32 {
                    [DllImport("user32.dll")]
                    [return: MarshalAs(UnmanagedType.Bool)]
                    public static extern bool SetForegroundWindow(IntPtr hWnd);
                    
                    [DllImport("user32.dll")]
                    [return: MarshalAs(UnmanagedType.Bool)]
                    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                }
"@
        }
        
        # Try to bring window to foreground for up to 10 seconds
        for ($i = 0; $i -lt 20; $i++) {
            try {
                $process.Refresh()
                if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                    [User32]::ShowWindow($process.MainWindowHandle, 9) # 9 = SW_RESTORE (if minimized)
                    [User32]::SetForegroundWindow($process.MainWindowHandle)
                    Write-Log "Window brought to foreground"
                    break
                }
            }
            catch { }
            Start-Sleep -Milliseconds 500
        }
        
        return $DriveLetter
    }
    catch {
        Write-Log "ERROR starting viewer: $_"
        return $null
    }
}

function Stop-StreamerViewer {
    # Find all Viewer-windows processes
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    
    if ($processes) {
        foreach ($proc in $processes) {
            try {
                Write-Log "Stopping Streamer Viewer (PID: $($proc.Id))"
                $proc.Kill()
                $proc.WaitForExit(5000)
                Write-Log "Process stopped successfully"
            }
            catch {
                Write-Log "ERROR stopping viewer: $_"
            }
        }
    }
    $script:CurrentDriveLetter = $null
}

function Scan-AllDrives {
    Write-Log "Scanning all USB drives..."
    
    # Stop any existing process first
    Stop-StreamerViewer
    
    # Get all removable drives
    $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
    
    foreach ($drive in $drives) {
        $letter = $drive.DeviceID -replace ":", ""
        Write-Log "Checking drive $letter..."
        
        $result = Test-StreamerUSB -DriveLetter $letter
        if ($result.Found) {
            Write-Log "Found Streamer Viewer USB on drive $letter"
            $script:CurrentDriveLetter = Start-StreamerViewer -ExePath $result.ExePath -DataPath $result.DataPath -DriveLetter $letter
            return
        }
    }
    
    Write-Log "No Streamer Viewer USB found"
}

# Initialize
Write-Log "=== USB Monitor Starting ==="
Write-Log "Log file: $LogFile"

# Initial scan
Scan-AllDrives

# Set up WMI event watchers for USB insertion and removal
Write-Log "Setting up USB event monitoring..."

# Query for USB volume events (more reliable for drive letters)
$insertQuery = "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_Volume' AND TargetInstance.DriveType = 2"
$removeQuery = "SELECT * FROM __InstanceDeletionEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_Volume' AND TargetInstance.DriveType = 2"

try {
    # Register for insertion events
    Register-WmiEvent -Query $insertQuery -SourceIdentifier "USBInserted" -Action {
        Start-Sleep -Seconds 3  # Wait for drive to be ready
        $Global:NeedRescan = $true
    } | Out-Null
    
    # Register for removal events  
    Register-WmiEvent -Query $removeQuery -SourceIdentifier "USBRemoved" -Action {
        $Global:NeedRescan = $true
    } | Out-Null
    
    Write-Log "USB event monitoring active"
    Write-Log "Waiting for USB events (Press Ctrl+C to stop)..."
    
    # Keep script running and check for rescan flag
    $Global:NeedRescan = $false
    while ($true) {
        Start-Sleep -Seconds 2
        
        # Check if rescan needed
        if ($Global:NeedRescan) {
            Write-Log "USB change detected, rescanning..."
            $Global:NeedRescan = $false
            Scan-AllDrives
        }
        
        # Periodic check if process is still running
        if ($CurrentDriveLetter) {
            $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if (!$proc) {
                Write-Log "WARNING: Viewer process exited unexpectedly"
                $script:CurrentDriveLetter = $null
                # Try to find another USB drive
                Scan-AllDrives
            }
        }
    }
}
finally {
    Write-Log "=== USB Monitor Stopping ==="
    Stop-StreamerViewer
    
    # Cleanup event subscriptions
    Get-EventSubscriber -SourceIdentifier "USBInserted" -ErrorAction SilentlyContinue | Unregister-Event
    Get-EventSubscriber -SourceIdentifier "USBRemoved" -ErrorAction SilentlyContinue | Unregister-Event
}
