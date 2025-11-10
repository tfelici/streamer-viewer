# Linux Host Requirements for Streamer Viewer with Qt5 Webview

This document outlines the system requirements and installation steps needed on the target Linux machine to run the Streamer Viewer executable with Qt5 webview support. This build is optimized for KDE desktop environments.

## Quick Install Commands

### For Ubuntu/Debian-based systems:

#### KDE/Qt-based desktops (recommended):
```bash
sudo apt update
sudo apt install qtbase5-dev libqt5webenginewidgets5 libqt5webenginecore5 libqt5gui5
```

#### For KDE/Qt-based desktops (recommended and optimized):
```bash
sudo apt update
sudo apt install qtbase5-dev libqt5webenginewidgets5 libqt5webenginecore5
```

#### For other desktop environments:
The application will automatically fall back to browser mode if Qt5 is not available. No additional packages required for browser fallback.

### For Red Hat/Fedora/CentOS systems:

#### KDE/Qt-based desktops:
```bash
sudo dnf install qt5-qtbase qt5-qtwebengine qt5-qtwebkit
```

#### GNOME/GTK-based desktops:
```bash
sudo dnf install gtk3 webkit2gtk4.1
```

### For Arch Linux:

#### KDE/Qt-based desktops:
```bash
sudo pacman -S qt5-base qt5-webengine
```

#### GNOME/GTK-based desktops:
```bash
sudo pacman -S gtk3 webkit2gtk
```

## Detailed Requirements

### Core GUI Libraries

The Streamer Viewer executable requires either Qt or GTK libraries to display the webview interface:

**Qt5 Libraries (preferred for KDE):**
- `qtbase5-dev` or `qt5-qtbase` (replaces deprecated `qt5-default`)
- `libqt5webenginewidgets5` or `qt5-qtwebengine`
- `libqt5webenginecore5`
- `libqt5gui5`
- `libqt5core5a`
- `libqt5widgets5`

**Browser Fallback:**
- No additional libraries required
- Uses system default web browser if Qt5 unavailable

### Additional Runtime Dependencies

Some additional libraries that may be needed:
```bash
# Graphics and display
sudo apt install libegl1 libxkbcommon-x11-0 libxcb-xinerama0

# Audio (if needed)
sudo apt install libasound2-dev

# Common desktop libraries  
sudo apt install libxss1 libxrandr2 libatk1.0-0
```

## Testing Installation

After installing the required packages, you can test if webview will work by checking for the libraries:

### Test Qt5 availability:
```bash
python3 -c "
try:
    import sys
    sys.path.append('/usr/lib/python3/dist-packages')
    from PyQt5.QtCore import *
    print('✅ Qt5 libraries available')
except ImportError as e:
    print('❌ Qt5 not available:', e)
"
```

### Test GTK3 availability:
```bash
python3 -c "
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
    print('✅ GTK3 libraries available')
except ImportError as e:
    print('❌ GTK3 not available:', e)
"
```

## What the Application Will Do

1. **First Choice: Qt5 Webview**
   - If Qt5 libraries are available, the app will use PyQt5 for native-looking windows
   - Best integration with KDE desktop environments
   - Hardware-accelerated web rendering

2. **Second Choice: GTK3 Webview**
   - If Qt5 is not available but GTK3 is, uses GTK backend
   - Good integration with GNOME desktop environments
   - Fallback web rendering

3. **Final Fallback: Browser**
   - If neither Qt5 nor GTK3 are available, opens in default web browser
   - Still fully functional, just not in a native app window
   - No additional dependencies required

## Desktop Environment Compatibility

| Desktop Environment | Recommended Libraries | Notes |
|--------------------|--------------------|-------|
| KDE Plasma | Qt5 libraries | Native integration |
| GNOME | GTK3 libraries | Native integration |
| XFCE | Either Qt5 or GTK3 | Both work well |
| LXDE/LXQt | Qt5 libraries | LXQt is Qt-based |
| Cinnamon | GTK3 libraries | GTK-based |
| MATE | GTK3 libraries | GTK-based |
| Budgie | GTK3 libraries | GTK-based |

## Troubleshooting

### If webview fails to start:
1. Check the console output for specific error messages
2. Install both Qt5 and GTK3 libraries for maximum compatibility
3. The application will automatically fall back to browser mode if webview fails

### Common issues:

**"No module named 'PyQt5'"**
```bash
sudo apt install python3-pyqt5 python3-pyqt5.qtwebengine
```

**"No module named 'gi'"**  
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

**"Cannot find Qt platform plugin"**
```bash
sudo apt install qtbase5-dev libqt5gui5 qt5-qmake
export QT_QPA_PLATFORM=xcb  # Add to ~/.bashrc if needed
```

## Verification Script

Save this as `test-webview.sh` and run it to check your system:

```bash
#!/bin/bash
echo "Testing Streamer Viewer webview requirements..."

# Test Qt5
echo -n "Qt5: "
python3 -c "
try:
    from PyQt5.QtCore import *
    print('✅ Available')
except ImportError:
    print('❌ Not available')
" 2>/dev/null

# Test GTK3  
echo -n "GTK3: "
python3 -c "
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
    print('✅ Available')
except ImportError:
    print('❌ Not available')
" 2>/dev/null

echo "Done. If both show ❌, the application will use browser fallback mode."
```

Make it executable and run:
```bash
chmod +x test-webview.sh
./test-webview.sh
```