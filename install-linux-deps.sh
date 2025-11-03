#!/bin/bash
# Linux Dependencies Installer for Streamer Viewer
# This script installs the required Qt dependencies for the Linux version

echo "🚀 Installing Streamer Viewer Linux Dependencies..."
echo

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "❌ Cannot detect Linux distribution"
    exit 1
fi

echo "📋 Detected: $OS $VER"

# Install Qt5 dependencies based on distribution
case $OS in
    *"Ubuntu"*|*"Debian"*)
        echo "🔧 Installing Qt5 dependencies for Debian/Ubuntu..."
        sudo apt update
        sudo apt install -y \
            python3-pyqt5 \
            python3-pyqt5.qtwebengine \
            python3-pyqt5.qtwebchannel \
            libqt5webkit5-dev
        ;;
    *"Fedora"*|*"Red Hat"*|*"CentOS"*)
        echo "🔧 Installing Qt5 dependencies for Fedora/RHEL..."
        sudo dnf install -y \
            python3-qt5 \
            python3-qt5-webkit \
            qt5-qtwebengine-devel
        ;;
    *"Arch"*|*"Manjaro"*)
        echo "🔧 Installing Qt5 dependencies for Arch Linux..."
        sudo pacman -S --noconfirm \
            python-pyqt5 \
            qt5-webkit \
            qt5-webengine
        ;;
    *)
        echo "⚠️  Distribution not automatically supported."
        echo "Please install these packages manually:"
        echo "  - PyQt5"
        echo "  - Qt5 WebEngine"
        echo "  - Qt5 WebKit (optional)"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo
    echo "✅ Dependencies installed successfully!"
    echo "📦 You can now run StreamerViewer-linux"
    echo
    echo "Usage:"
    echo "  chmod +x StreamerViewer-linux"
    echo "  ./StreamerViewer-linux"
else
    echo
    echo "❌ Installation failed. Please install Qt5 dependencies manually."
    exit 1
fi