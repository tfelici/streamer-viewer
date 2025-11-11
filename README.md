# Streamer Viewer v2.2

A comprehensive GPS track analysis and video synchronization application with advanced deployment options. Features both desktop GUI and headless server modes, professional USB autolaunch system, and seamless integration with the RPI Streamer ecosystem.

## 🎯 Overview

The Streamer Viewer transforms GPS tracking data into interactive visualizations with synchronized video playbook. Designed for flight analysis, surveillance review, and GPS track management, it offers flexible deployment options from desktop applications to automated USB-triggered launches and headless server deployments.

## ✨ What's New in v2.2

### 🖥️ Server-Only Mode
- **Headless Operation**: Run without GUI for server deployments
- **Web-Only Interface**: Access via browser at `http://localhost:5001`
- **Command Line Control**: `--server-only` flag for automated deployments
- **Resource Efficient**: Skips UI components when running headless
- **Perfect for**: Remote servers, Docker containers, automated systems

### 🔌 USB Autolaunch System (Linux)
- **Plug-and-Play**: Automatically launches when USB with `streamerData` is inserted
- **Professional Loading Experience**: Mini-server with animated loading page  
- **Cross-Desktop Compatible**: Works on Wayland and X11 environments
- **Smart Process Management**: Reliable background operation with cleanup
- See [Linux USB Autolaunch Documentation](linux/README.md) for detailed setup

### 🚀 Enhanced Deployment Options
- **Flexible Execution Modes**: Desktop GUI, browser-only, or headless server
- **USB Portability**: Complete system on USB drives with autolaunch
- **Cross-Platform**: Windows, macOS, Linux with platform-specific optimizations
- **Zero-Configuration**: Intelligent defaults with override options

## 🚀 Key Features

### 🗺️ Advanced GPS Track Visualization
- **Interactive Mapping**: Professional-grade track visualization using Leaflet.js with OpenStreetMap tiles
- **Real-time Playback Engine**: 
  - Timeline scrubbing with millisecond precision
  - Variable speed playback (0.5x to 4x speed)
  - Play/pause controls with position indicators
- **Multi-Track Analysis**: Browse and compare multiple GPS tracks simultaneously
- **Track Statistics**: Distance, duration, altitude profiles, and speed analysis
- **Zoom & Navigation**: Full pan/zoom capabilities with position markers

### 📹 Video Synchronization System
- **Precision Sync**: Frame-accurate synchronization between GPS position and video playback
- **Timeline Integration**: Unified timeline controlling both GPS position and video playback
- **Video Controls**: Full video player with seek, volume, and fullscreen support
- **Multi-Format Support**: Compatible with MP4, WebM, and other HTML5 video formats
- **Performance Optimized**: Smooth playback with efficient memory management

### 📡 Professional Recording Management
- **Server Integration**: Direct upload to RPI Streamer server infrastructure
- **Upload Progress Monitoring**: 
  - Real-time progress bars with transfer speeds
  - Cancellation support for large file uploads
  - Error handling with retry capabilities
- **Bulk Upload Operations**: Multi-file selection and batch processing
- **Hierarchical Organization**: Automatic organization by domain/device/timestamp structure
- **Metadata Extraction**: Automatic video duration and format detection using pymediainfo

### 🎨 Modern Web Interface
- **Professional UI Design**: 
  - Font Awesome icon system (offline-compatible)
  - Modern gradient themes with smooth CSS animations
  - Responsive layout adapting to different screen sizes
- **Cross-Platform Access**: Works in any modern web browser
- **Intuitive Navigation**: 
  - Seamless mode switching between viewing and upload operations
  - Context-sensitive menus and controls
  - Keyboard shortcuts for common operations

### 🔧 Advanced Technical Features
- **High-Performance Rendering**: Optimized for large GPS datasets with thousands of points
- **Memory Management**: Efficient handling of large video files and track data
- **Cross-Platform Compatibility**: PyWebView engine with browser fallback
- **API Integration**: RESTful API endpoints for programmatic access and automation
- **Server-Sent Events**: Real-time progress updates using modern web technologies

## 🚀 Quick Start

### Desktop Mode (Default)
```bash
# Run with native desktop window (if webview available)
python main.py

# Open in default browser if webview not available
python main.py
```

### Server-Only Mode (Headless)
```bash
# Run headless server (no GUI components)
python main.py --server-only

# Access via browser at http://localhost:5001
```

### Custom Data Directory
```bash
# Use custom path for GPS tracks and recordings
python main.py --data-dir "/path/to/your/streamerData"
python main.py --server-only --data-dir "/mnt/usb/streamerData"
```

### USB Autolaunch (Linux Only)
```bash
# See linux/README.md for complete installation guide
cd linux/
./install_usb_autolaunch.sh
```

## 📁 Directory Structure

```
Streamer Viewer/
├── main.py                          # Main Flask application with server modes
├── requirements.txt                 # Python dependencies
├── templates/                       # HTML templates
│   ├── index.html                   # Track list & navigation
│   ├── viewer.html                  # GPS track viewer with maps
│   └── uploader.html                # Recording upload interface
├── static/                          # Static assets
│   ├── style.css                    # Main application styles
│   ├── css/
│   │   └── fontawesome-minimal.css  # Offline Font Awesome icons
│   └── webfonts/                    # Font files
│       ├── fa-solid-900.woff2       # Web font (optimized)
│       └── fa-solid-900.ttf         # Fallback font
├── linux/                          # Linux USB autolaunch system
│   ├── install_usb_autolaunch.sh   # USB autolaunch setup with systemd
│   └── uninstall_usb_autolaunch.sh # Complete USB autolaunch removal
├── streamerData/                    # Data directory (configurable)
│   ├── tracks/                      # GPS track files (*.tsv)
│   └── recordings/
│       └── webcam/                  # Video files (*.mp4)
├── .github/
│   └── workflows/                   # Automated build system
│       ├── build-windows.yml        # Windows executable build
│       └── build-macos.yml          # macOS app bundle build
└── StreamerViewer.spec             # PyInstaller spec for all platforms
```

## 📊 Data Format & Sources

### GPS Track Format (TSV)
GPS tracks are stored in tab-separated values format with the following columns:
```
timestamp	latitude	longitude	altitude	accuracy	altitudeAccuracy	heading	speed
```

**Example:**
```
1638360000000	40.7589	-73.9851	10.5	3.0	5.0	45.2	2.1
1638360001000	40.7590	-73.9850	10.6	3.0	5.0	46.1	2.3
```

### Data Directory Structure
```
streamerData/                        # Configurable with --data-dir
├── tracks/                          # GPS track files
│   ├── 2023-12-25_14-30-45.tsv    # Timestamp-named tracks
│   ├── flight_001.tsv              # Custom named tracks
│   └── ...
└── recordings/                      # Video files
    └── webcam/                      # Webcam recordings
        ├── 2023-12-25_14-30-45.mp4 # Timestamp-matched videos
        ├── 2023-12-25_14-31-12.mp4
        └── ...
```

### Video Synchronization
- **Automatic Matching**: Videos matched to tracks by timestamp overlap
- **Flexible Naming**: Supports both timestamp and custom naming
- **Format Support**: MP4, WebM, and other HTML5-compatible formats

## 💻 Deployment Options

### 1. Desktop Application Mode
```bash
# Default: Opens in native window (webview) or browser
python main.py
```
- **Webview Available**: Native desktop window with integrated browser
- **No Webview**: Opens in default system browser
- **URL**: `http://localhost:5001`
- **Use Case**: Interactive desktop usage, development

### 2. Server-Only Mode (Headless)
```bash
# Headless server without GUI components
python main.py --server-only
```
- **No Desktop UI**: Skips webview and splash screen initialization
- **Browser Access**: Navigate to `http://localhost:5001`
- **Resource Efficient**: Lower memory usage, faster startup
- **Use Case**: Remote servers, Docker containers, automated systems

### 3. USB Autolaunch System (Linux)
Professional plug-and-play system for automatic launching when USB drives with `streamerData` are inserted.

**Key Features:**
- Automatic detection and mounting
- Professional loading experience with animated screen
- Cross-desktop compatibility (Wayland/X11)
- Smart process management with systemd-run
- Complete cleanup on USB removal

**Setup:** See [Linux USB Autolaunch Documentation](linux/README.md) for complete installation and configuration guide.

### 4. Standalone Executables
Download pre-built executables from GitHub Actions artifacts or releases:
- **Windows**: `StreamerViewer-windows.exe`
- **macOS**: `StreamerViewer-macos-x86_64` / `StreamerViewer-macos-arm64`  
- **Linux**: Use Python installation (more flexible)

**Command Line Options:**
- `--data-dir PATH` - Custom path to streamer data directory (default: `./streamerData`)
- `--server-only` - Run in headless mode without desktop UI components

### 🧭 Navigation

1. **Main Page**: Browse GPS tracks, switch between viewing and recording upload modes
2. **View Tracks**: Click track entries to view on interactive maps with video sync
3. **Upload Recordings**: Select files, monitor upload progress, sync to server

### 🔧 Configuration

Set your server URL in the upload interface:
- Default: `https://gyropilots.com/streameradmin/`
- Custom servers supported for private deployments

## Building Standalone Executables

Executables are automatically built using GitHub Actions workflows:

### 📦 Automated Builds
- **Windows**: `.github/workflows/build-windows.yml` → `StreamerViewer-windows.exe`
- **macOS**: `.github/workflows/build-macos.yml` → `StreamerViewer-macos-x86_64` / `StreamerViewer-macos-arm64`

### 🔧 Manual Build
```bash
# Build for current platform (Windows/macOS)
pyinstaller StreamerViewer.spec
```

The executable will be created in `dist/StreamerViewer`

## �️ Installation & Setup

### Standard Python Installation
```bash
# Clone the repository
git clone https://github.com/tfelici/streamer-viewer.git
cd streamer-viewer

# Install Python dependencies
pip install -r requirements.txt

# Run in desktop mode
python main.py

# Run in server-only mode
python main.py --server-only
```

### Linux USB Autolaunch Setup
```bash
# See linux/README.md for complete setup guide
cd linux/
./install_usb_autolaunch.sh
```

For detailed installation, configuration, and troubleshooting, see the [Linux USB Autolaunch Documentation](linux/README.md).

### Optional Webview Support (Desktop Mode)
```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt install qtbase5-dev libqt5webenginewidgets5

# Install Python webview with Qt backend  
pip install pywebview[qt]

# Without webview: automatically falls back to default browser
```

## Dependencies

### Core Framework
- **Flask**: Web framework and routing
- **pywebview**: Desktop application wrapper
- **PyInstaller**: Executable building

### Recording Upload Features
- **requests**: HTTP client for server communication
- **requests-toolbelt**: Multipart upload with progress tracking
- **pymediainfo**: Media file metadata extraction

### Frontend Assets
- **Leaflet.js**: Interactive mapping (CDN)
- **Font Awesome**: Icon system (bundled offline)
- **OpenStreetMap**: Map tile provider

## 🔧 Technical Architecture

### Application Modes

**Desktop Mode (`python main.py`)**
- Flask web server on `localhost:5001`
- PyWebView native window wrapper (if available)
- Fallback to default browser if webview unavailable
- PyInstaller splash screen (in executable builds)
- Full UI initialization and desktop integration

**Server-Only Mode (`python main.py --server-only`)**
- Flask web server on `localhost:5001` 
- No desktop UI components loaded
- No webview or splash screen initialization
- Optimized for headless/remote deployment
- Access via any web browser

**USB Autolaunch Mode (Linux)**
- Automatic detection via udev rules
- systemd-run for persistent process management
- Mini HTTP server on `localhost:5000` with loading screen
- Main application launched in server-only mode
- Firefox kiosk mode for presentation

### Core Functionality

1. **Track Discovery**: Scans `streamerData/tracks/` for TSV files
2. **Video Matching**: Matches videos with tracks based on timestamp overlap  
3. **Map Display**: Uses Leaflet.js to display GPS tracks as polylines
4. **Synchronization**: Timeline slider controls both map position and video playback
5. **Playback Controls**: Variable speed playback with play/pause functionality
6. **Upload Management**: Multipart file uploads with progress tracking

### API Endpoints

**Core Routes:**
- `GET /` - Main navigation page
- `GET /uploader` - Recording upload interface
- `GET /view/<track_id>` - Track viewer with maps and video sync

**Upload System:**
- `POST /upload_recording` - Multipart file upload handler
- `GET /upload_progress` - Server-Sent Events progress stream
- Real-time progress tracking with transfer speeds

**Static Assets:**
- Offline Font Awesome icons and fonts
- Optimized CSS and JavaScript
- All dependencies bundled for offline operation

### Performance & Compatibility

**Resource Usage:**
- **Desktop Mode**: ~50-100MB RAM (includes webview)
- **Server-Only Mode**: ~30-50MB RAM (Flask only)
- **Executable Size**: ~19MB (all dependencies bundled)
- **Font Assets**: Minimal Font Awesome build (~148KB vs 600KB+)

**Browser Compatibility:**
- Modern web standards (ES6+, CSS Grid, Flexbox)
- HTML5 video and canvas support
- Leaflet.js mapping library
- Server-Sent Events for real-time updates
- WebView2 engine on Windows, Qt WebEngine on Linux

## Related Projects

**RPI Streamer Ecosystem:**
- **RPI Streamer**: Records GPS tracks and videos on Raspberry Pi
- **Streamer Admin**: Server-side administration and API backend  
- **Streamer Viewer**: Complete client application (viewing + recording upload)

## Architecture Notes

**Unified Application**: This application provides complete GPS track viewing and recording upload functionality in a single, comprehensive interface. All features are seamlessly integrated for optimal user experience.

## Screenshots

### Main Interface
- 🗺️ **Track List**: Browse GPS tracks with icons and modern styling
- 📡 **Upload Interface**: Drag-and-drop file upload with progress monitoring
- 🧭 **Navigation**: Seamless switching between track viewing and recording upload modes

### Track Viewer
- 📍 **Interactive Maps**: Real-time GPS position tracking on OpenStreetMap
- 🎥 **Video Sync**: Timeline scrubbing with synchronized video playback
- ⏯️ **Controls**: Play/pause, speed adjustment, and timeline navigation

## 📋 Version History

### v2.2 (Current) - Advanced Deployment & USB Autolaunch
- **Server-Only Mode**: Headless operation with `--server-only` flag
- **USB Autolaunch System**: Complete Linux autolaunch with professional loading
- **Enhanced Process Management**: systemd-run integration for Wayland compatibility
- **Code Optimization**: Consolidated UI initialization, improved performance
- **Cross-Platform Improvements**: Better compatibility across desktop environments

### v2.1 - Integration & Performance
- **Comprehensive Recording Upload**: Integrated upload functionality
- **Modern UI System**: Font Awesome icons with offline support
- **Enhanced User Experience**: Improved navigation and visual design
- **Performance Optimization**: Faster loading and better resource management

### v2.0 - Major Feature Expansion
- **Unified Interface**: Combined viewing and upload in single application
- **Professional UI**: Gradient themes and smooth animations
- **Offline Operation**: Complete offline functionality with bundled assets
- **Cross-Platform**: Windows, macOS, Linux support

### v1.x - Initial Releases
- **GPS Track Viewer**: Basic track visualization and video synchronization
- **Core Functionality**: Map display and timeline controls

## Support

For issues, feature requests, or questions:
- **Repository**: https://github.com/tfelici/streamer-viewer
- **Issues**: Use GitHub Issues for bug reports
- **Documentation**: See this README and inline code comments
