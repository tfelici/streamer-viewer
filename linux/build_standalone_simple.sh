#!/bin/bash
# Simple Linux Standalone Build Script for Streamer Viewer
# Usage: bash build_standalone_simple.sh
#
# This script creates a standalone Linux executable using system Python
# Requirements: Linux system with Python 3.7+ and pip

set -e

echo "🐧 Building Streamer Viewer for Linux (Simple Version)..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📁 Project directory: $PROJECT_DIR"

# Check for required system packages
echo "🔧 Checking system requirements..."

if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found. Installing..."
    sudo apt update && sudo apt install -y python3
fi

if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 not found. Installing..."
    sudo apt update && sudo apt install -y python3-pip
fi

# Check Python version
python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Python version: $python_version"

# Verify Python version is 3.7+
python3 -c "
import sys
if (sys.version_info.major == 3 and sys.version_info.minor >= 7) or sys.version_info.major > 3:
    exit(0)
else:
    print('❌ Error: Python 3.7 or higher is required')
    exit(1)
"

# Change to project directory
cd "$PROJECT_DIR"

echo "📦 Using system Python (no virtual environment for simplicity)..."

# Install dependencies directly to system/user
echo "📦 Installing dependencies..."

# Install requirements
if [ -f "requirements.txt" ]; then
    echo "📦 Installing from requirements.txt..."
    pip3 install -r requirements.txt --user --break-system-packages 2>/dev/null || \
    pip3 install -r requirements.txt --user 2>/dev/null || \
    pip3 install -r requirements.txt 2>/dev/null || {
        echo "⚠️  Requirements installation failed, trying individual packages..."
        pip3 install Flask requests requests-toolbelt pymediainfo --user --break-system-packages 2>/dev/null || \
        pip3 install Flask requests requests-toolbelt pymediainfo --user 2>/dev/null || \
        pip3 install Flask requests requests-toolbelt pymediainfo
    }
else
    echo "📦 Installing basic dependencies..."
    pip3 install Flask requests requests-toolbelt pymediainfo --user --break-system-packages 2>/dev/null || \
    pip3 install Flask requests requests-toolbelt pymediainfo --user 2>/dev/null || \
    pip3 install Flask requests requests-toolbelt pymediainfo
fi

# Install PyInstaller
echo "📦 Installing PyInstaller..."
pip3 install pyinstaller --user --break-system-packages 2>/dev/null || \
pip3 install pyinstaller --user 2>/dev/null || \
pip3 install pyinstaller

# Clean previous builds
echo "🧹 Cleaning previous builds..."
sudo rm -rf build/ 2>/dev/null || rm -rf build/ 2>/dev/null || echo "⚠️  Could not remove build directory"
sudo rm -rf dist/ 2>/dev/null || rm -rf dist/ 2>/dev/null || echo "⚠️  Could not remove dist directory"  
rm -rf __pycache__/ 2>/dev/null || echo "⚠️  Could not remove __pycache__ directory"
rm -rf *.spec 2>/dev/null || echo "⚠️  Could not remove spec files"

# Create the executable
echo "🔨 Building executable..."
python3 -m PyInstaller \
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
    
    echo ""
    echo "🚀 To run the executable:"
    echo "   ./dist/StreamerViewer"
    echo ""
    echo "📋 Build completed successfully!"
    
else
    echo "❌ Build failed - executable not found"
    echo "📋 Check the PyInstaller output above for errors"
    exit 1
fi

echo "🎉 All done!"