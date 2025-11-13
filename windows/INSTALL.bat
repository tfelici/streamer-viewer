@echo off
REM Windows USB Autolaunch Installer Launcher
REM Double-click this file to install (handles execution policy automatically)

echo.
echo ========================================
echo   Streamer Viewer USB Autolaunch
echo   Installation Launcher
echo ========================================
echo.
echo Starting installation...
echo (You will be prompted for administrator privileges)
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0install_usb_autolaunch.ps1"

echo.
echo Installation complete!
echo.
pause
