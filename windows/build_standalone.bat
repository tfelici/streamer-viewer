@echo off
echo Building Streamer Viewer Standalone Executable...

REM Change to the project root directory
cd /d "%~dp0\.."

REM Install/upgrade dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Build the executable
echo Building executable...
cd windows
python -m PyInstaller StreamerViewer_onefile.spec --clean

REM Check if build was successful
if exist "dist\StreamerViewer.exe" (
    echo.
    echo ================================
    echo Build completed successfully!
    echo ================================
    echo.
    echo Executable location: windows\dist\StreamerViewer.exe
    echo.
    echo You can now run the standalone executable without Python installed.
    echo.
    pause
) else (
    echo.
    echo ================================
    echo Build failed!
    echo ================================
    echo.
    echo Please check the error messages above.
    echo.
    pause
)
