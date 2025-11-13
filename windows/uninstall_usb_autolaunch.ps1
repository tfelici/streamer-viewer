<#
.SYNOPSIS
    Uninstalls USB autolaunch system for Streamer Viewer on Windows

.DESCRIPTION
    Removes the Task Scheduler task and monitor script installed by the autolaunch installer.
    
.NOTES
    Requires Administrator privileges - will auto-elevate if needed
#>

$ErrorActionPreference = "Stop"

# Check if running as administrator, if not, re-launch as admin
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (!(Test-Administrator)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -Wait
    exit
}

# Configuration
$InstallPath = "C:\Program Files\StreamerViewer"
$TaskName = "StreamerViewer USB Monitor"

function Write-Status {
    param($Message, $Type = "Info")
    
    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Stop-MonitorProcess {
    Write-Status "Checking for running monitor processes..."
    
    $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*usb-monitor.ps1*" }
    
    if ($processes) {
        Write-Status "Stopping monitor process(es)..." "Warning"
        $processes | Stop-Process -Force
        Write-Status "Monitor process stopped" "Success"
    }
}

function Remove-ScheduledTask {
    Write-Status "Checking for scheduled task..."
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Status "Stopping task if running..."
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        Write-Status "Removing scheduled task..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Status "Scheduled task removed" "Success"
    }
    else {
        Write-Status "Scheduled task not found (already removed?)" "Warning"
    }
}

function Remove-InstallationFiles {
    Write-Status "Checking for installation directory..."
    
    if (Test-Path $InstallPath) {
        Write-Status "Removing installation files..."
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-Status "Installation files removed" "Success"
    }
    else {
        Write-Status "Installation directory not found (already removed?)" "Warning"
    }
}

function Remove-LogFile {
    $logFile = "$env:TEMP\streamer-viewer-usb-monitor.log"
    if (Test-Path $logFile) {
        Write-Status "Removing log file..."
        Remove-Item -Path $logFile -Force
        Write-Status "Log file removed" "Success"
    }
}

# Main uninstallation process
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Streamer Viewer USB Autolaunch Uninstaller" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Status "Running with Administrator privileges" "Success"
    
    # Confirm uninstallation
    Write-Host ""
    $response = Read-Host "Are you sure you want to uninstall the USB autolaunch system? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Status "Uninstallation cancelled" "Warning"
        exit 0
    }
    
    # Uninstall components
    Stop-MonitorProcess
    Remove-ScheduledTask
    Remove-InstallationFiles
    Remove-LogFile
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Uninstallation completed successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-Status "The USB autolaunch system has been completely removed."
    Write-Status "The Streamer Viewer application itself has not been affected."
    Write-Host ""
}
catch {
    Write-Status "Uninstallation failed: $_" "Error"
    Write-Status $_.ScriptStackTrace "Error"
    exit 1
}
