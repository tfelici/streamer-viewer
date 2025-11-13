<#
.SYNOPSIS
    Installs USB autolaunch system for Streamer Viewer on Windows

.DESCRIPTION
    This installer sets up a Task Scheduler task that automatically:
    - Detects USB drive insertion
    - Checks for Viewer-windows.exe and streamerData directory
    - Launches the application automatically
    - Stops the application when USB is removed
    
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
$MonitorScriptName = "usb-monitor.ps1"
$TaskName = "StreamerViewer USB Monitor"
$TaskDescription = "Automatically launches Streamer Viewer when USB drive is inserted"

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

function Install-MonitorScript {
    Write-Status "Creating installation directory..."
    
    if (!(Test-Path $InstallPath)) {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Status "Copying monitor script..."
    $sourcePath = Join-Path $PSScriptRoot $MonitorScriptName
    $destPath = Join-Path $InstallPath $MonitorScriptName
    
    if (!(Test-Path $sourcePath)) {
        throw "Monitor script not found at: $sourcePath"
    }
    
    Copy-Item -Path $sourcePath -Destination $destPath -Force
    Write-Status "Monitor script installed to: $destPath" "Success"
}

function Install-ScheduledTask {
    Write-Status "Checking for existing task..."
    
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Removing existing task..." "Warning"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    Write-Status "Creating scheduled task..."
    
    # Task action - run PowerShell with the monitor script
    $monitorPath = Join-Path $InstallPath $MonitorScriptName
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorPath`""
    
    # Task trigger - at user logon
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Days 0)
    
    # Task principal - run with highest privileges
    $principal = New-ScheduledTaskPrincipal `
        -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive `
        -RunLevel Highest
    
    # Register the task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description $TaskDescription `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null
    
    Write-Status "Scheduled task created successfully" "Success"
}

function Set-ExecutionPolicyIfNeeded {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
        Write-Status "Setting PowerShell execution policy..." "Warning"
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Status "Execution policy set to RemoteSigned" "Success"
    }
}

function Test-Installation {
    Write-Status "`nVerifying installation..."
    
    $monitorPath = Join-Path $InstallPath $MonitorScriptName
    if (!(Test-Path $monitorPath)) {
        Write-Status "Monitor script not found!" "Error"
        return $false
    }
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (!$task) {
        Write-Status "Scheduled task not found!" "Error"
        return $false
    }
    
    Write-Status "Installation verified successfully" "Success"
    return $true
}

# Main installation process
try {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Streamer Viewer USB Autolaunch Installer" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Status "Running with Administrator privileges" "Success"
    
    # Install components
    Install-MonitorScript
    Set-ExecutionPolicyIfNeeded
    Install-ScheduledTask
    
    # Verify installation
    if (Test-Installation) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Installation completed successfully!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
        
        Write-Host "The USB monitor will start automatically at next login." -ForegroundColor Cyan
        Write-Host "`nTo start it now, you can:" -ForegroundColor Cyan
        Write-Host "  1. Log out and log back in, OR" -ForegroundColor White
        Write-Host "  2. Run this command:" -ForegroundColor White
        Write-Host "     Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
        
        Write-Host "`nLog file location:" -ForegroundColor Cyan
        Write-Host "  $env:TEMP\streamer-viewer-usb-monitor.log" -ForegroundColor White
        
        Write-Host "`nTo uninstall, run: uninstall_usb_autolaunch.ps1" -ForegroundColor Cyan
        Write-Host ""
        
        # Ask if user wants to start now
        $response = Read-Host "`nWould you like to start the USB monitor now? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            Write-Status "Starting USB monitor..."
            Start-ScheduledTask -TaskName $TaskName
            Start-Sleep -Seconds 2
            
            # Check if task is running
            $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
            if ($taskInfo.LastTaskResult -eq 267009) {
                Write-Status "USB monitor is now running!" "Success"
            }
            else {
                Write-Status "Task started. Check log file for details." "Success"
            }
        }
    }
    else {
        Write-Status "Installation verification failed!" "Error"
        exit 1
    }
}
catch {
    Write-Status "Installation failed: $_" "Error"
    Write-Status $_.ScriptStackTrace "Error"
    exit 1
}
