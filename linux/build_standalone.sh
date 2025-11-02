#!/bin/bash
# Linux Standalone Build Script for Streamer Viewer
# Usage: bash build_standalone.sh
#
# This script creates a standalone Linux executable for Streamer Viewer
# Requirements: Linux system with Python 3.7+ and pip

set -e

echo "🐧 Building Streamer Viewer for Linux..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project directory: $PROJECT_DIR"

# Check for required system packages
echo "🔧 Checking system requirements..."
missing_packages=""

if ! command -v python3 &> /dev/null; then
    missing_packages="$missing_packages python3"
fi

if ! command -v pip3 &> /dev/null; then
    missing_packages="$missing_packages python3-pip"
fi

# Check if python3-venv is available (try creating a test venv)
if ! python3 -c "import venv" &> /dev/null; then
    # Get the specific Python version for venv package
    python_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    missing_packages="$missing_packages python${python_ver}-venv"
fi

if [ -n "$missing_packages" ]; then
    echo "📦 Installing required packages:$missing_packages"
    sudo apt update
    sudo apt install -y $missing_packages
fi

# Check Python version
python_version_check=$(python3 -c "
import sys
major, minor = sys.version_info.major, sys.version_info.minor
print(f'{major}.{minor}')
if (major == 3 and minor >= 7) or major > 3:
    print('OK')
else:
    print('FAIL')
")

python_version=$(echo "$python_version_check" | head -n1)
version_status=$(echo "$python_version_check" | tail -n1)

echo "🐍 Python version: $python_version"

if [ "$version_status" = "FAIL" ]; then
    echo "❌ Error: Python 3.7 or higher is required (found $python_version)"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

# Try to use virtual environment, fall back to system-wide if needed
USE_VENV=true

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create virtual environment"
        # Get the specific Python version for venv package
        python_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        echo "💡 Trying to install python${python_ver}-venv..."
        sudo apt update && sudo apt install -y "python${python_ver}-venv"
        echo "🔧 Retrying virtual environment creation..."
        python3 -m venv venv
        if [ $? -ne 0 ]; then
            echo "❌ Still failed to create virtual environment"
            echo "⚠️  Falling back to system-wide Python installation"
            USE_VENV=false
        fi
    fi
fi

# Check if virtual environment was created successfully
if [ ! -f "venv/bin/activate" ]; then
    echo "❌ Virtual environment activation script not found"
    echo "🔧 Attempting to recreate virtual environment..."
    
    # Try to remove venv directory with different methods
    if [ -d "venv" ]; then
        echo "🧹 Removing existing venv directory..."
        sudo rm -rf venv 2>/dev/null || {
            echo "⚠️  Cannot remove venv directory, trying alternative location..."
            # Use a different directory name to avoid conflicts
            VENV_DIR="venv_build_$(date +%s)"
            echo "🔧 Using alternative venv directory: $VENV_DIR"
        }
    fi
    
    # Set venv directory name (default or alternative)
    VENV_DIR="${VENV_DIR:-venv}"
    
    echo "🔧 Creating virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
    
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        echo "❌ Failed to create working virtual environment"
        exit 1
    fi
    
    # Update venv reference for the rest of the script
    if [ "$VENV_DIR" != "venv" ]; then
        echo "📝 Using alternative venv directory for this build"
    fi
else
    VENV_DIR="venv"
fi

# Activate virtual environment if available
if [ "$USE_VENV" = "true" ]; then
    echo "🔧 Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
else
    echo "🔧 Using system-wide Python installation..."
    VENV_DIR=""  # Clear venv directory for system-wide installation
fi

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip --user --break-system-packages 2>/dev/null || pip install --upgrade pip --user 2>/dev/null || {
    echo "⚠️  Pip upgrade failed, continuing with existing version..."
}

# Install requirements
if [ -f "requirements.txt" ]; then
    echo "📦 Installing from requirements.txt..."
    pip install -r requirements.txt --break-system-packages 2>/dev/null || pip install -r requirements.txt 2>/dev/null || {
        echo "⚠️  Requirements installation failed, trying individual packages..."
        pip install Flask requests requests-toolbelt pymediainfo --break-system-packages 2>/dev/null || pip install Flask requests requests-toolbelt pymediainfo
    }
else
    echo "📦 Installing basic dependencies..."
    pip install Flask requests requests-toolbelt pymediainfo --break-system-packages 2>/dev/null || pip install Flask requests requests-toolbelt pymediainfo
fi

# Install PyInstaller
echo "📦 Installing PyInstaller..."
pip install pyinstaller --break-system-packages 2>/dev/null || pip install pyinstaller

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf dist/
rm -rf __pycache__/
rm -rf *.spec

# Create the executable
echo "🔨 Building executable..."
pyinstaller \
    --onefile \
    --windowed \
    --name StreamerViewer \
    --add-data "templates:templates" \
    --add-data "static:static" \
    --hidden-import=pymediainfo \
    main.py

# Check if build was successful
if [ -f "dist/StreamerViewer" ]; then
    echo "✅ Build successful!"
    echo "📂 Executable location: $(pwd)/dist/StreamerViewer"
    echo "📊 Executable size: $(du -h dist/StreamerViewer | cut -f1)"
    
    # Make executable
    chmod +x dist/StreamerViewer
    
    # Test the executable
    echo "🧪 Testing executable..."
    if ./dist/StreamerViewer --help > /dev/null 2>&1; then
        echo "✅ Executable test passed!"
    else
        echo "⚠️  Executable created but may have runtime issues"
    fi
    
    echo ""
    echo "🎉 Linux build complete!"
    echo "📋 To distribute:"
    echo "   • Copy dist/StreamerViewer to target Linux systems"
    echo "   • Ensure target systems have glibc 2.17+ (most modern Linux distributions)"
    echo "   • The executable includes all dependencies except system libraries"
    
else
    echo "❌ Build failed!"
    echo "Check the output above for errors"
    exit 1
fi

# Deactivate virtual environment if it was used
if [ "$USE_VENV" = "true" ]; then
    deactivate
    
    # Cleanup alternative venv directory if used
    if [ "$VENV_DIR" != "venv" ] && [ -n "$VENV_DIR" ]; then
        echo "🧹 Cleaning up temporary venv directory..."
        
        # Try multiple cleanup methods
        if rm -rf "$VENV_DIR" 2>/dev/null; then
            echo "✅ Temporary venv directory cleaned up successfully"
        elif sudo rm -rf "$VENV_DIR" 2>/dev/null; then
            echo "✅ Temporary venv directory cleaned up with sudo"
        elif chmod -R 755 "$VENV_DIR" 2>/dev/null && rm -rf "$VENV_DIR" 2>/dev/null; then
            echo "✅ Temporary venv directory cleaned up after chmod"
        else
            echo "⚠️  Could not clean up $VENV_DIR"
            echo "💡 You can manually remove it later with: sudo rm -rf $PROJECT_DIR/$VENV_DIR"
        fi
    fi
fi