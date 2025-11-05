# Streamer Viewer v2.1

A comprehensive standalone desktop application for GPS track analysis, synchronized video playback, and recording management from the RPI Streamer ecosystem. This unified application provides complete track visualization, video synchronization, and upload capabilities in a single, professional desktop interface.

## 🎯 Overview

The Streamer Viewer transforms GPS tracking data into interactive visualizations with synchronized video playback. Perfect for flight analysis, surveillance review, and GPS track management, providing desktop-grade functionality with no installation requirements.

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

### 🎨 Modern Desktop Interface
- **Professional UI Design**: 
  - Font Awesome icon system (offline-compatible)
  - Modern gradient themes with smooth CSS animations
  - Responsive layout adapting to different screen sizes
- **Intuitive Navigation**: 
  - Seamless mode switching between viewing and upload operations
  - Context-sensitive menus and controls
  - Keyboard shortcuts for common operations
- **Dark/Light Themes**: Automatic theme detection with manual override options

### 🚀 Zero-Installation Deployment
- **Standalone Windows Executable**: Single-file deployment (~19MB) with no external dependencies
- **Complete Offline Functionality**: All assets, fonts, and libraries bundled
- **No Python Required**: End users don't need Python installation or technical knowledge
- **Instant Launch**: Double-click execution with immediate availability
- **Portable Operation**: Run from USB drives or network shares without installation

### 🔧 Advanced Technical Features
- **High-Performance Rendering**: Optimized for large GPS datasets with thousands of points
- **Memory Management**: Efficient handling of large video files and track data
- **Cross-Platform Compatibility**: PyWebView engine supporting Windows, macOS, and Linux
- **API Integration**: RESTful API endpoints for programmatic access and automation
- **Server-Sent Events**: Real-time progress updates using modern web technologies

## Directory Structure

```
Streamer Viewer/
├── main.py                          # Main Flask application
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
├── streamerData/                    # Data directory
│   ├── tracks/                      # GPS track files (*.tsv)
│   └── recordings/
│       └── webcam/                  # Video files (*.mp4)
└── windows/                         # Build system
    ├── build_standalone.bat         # Build script
    ├── StreamerViewer_onefile.spec  # PyInstaller spec
    ├── version_info.txt             # Version metadata
    └── dist/
        └── StreamerViewer.exe       # Final executable
```

## Data Sources

- **GPS Tracks**: `streamerData/tracks/*.tsv` (tab-separated values format)
- **Videos**: `streamerData/recordings/webcam/*.mp4` (timestamp-named files)

## GPS Track Format

The application reads GPS tracks in TSV format with the following columns:
```
timestamp	latitude	longitude	altitude	accuracy	altitudeAccuracy	heading	speed
```

## Usage

### 🖥️ Running the Application

**Development Mode:**
```bash
python main.py
```
Opens webview window at `http://127.0.0.1:5001`

**Standalone Executable:**
```bash
cd windows
build_standalone.bat
```
Creates `windows/dist/StreamerViewer.exe`

### 🧭 Navigation

1. **Main Page**: Browse GPS tracks, switch between viewing and recording upload modes
2. **View Tracks**: Click track entries to view on interactive maps with video sync
3. **Upload Recordings**: Select files, monitor upload progress, sync to server

### 🔧 Configuration

Set your server URL in the upload interface:
- Default: `https://gyropilots.com/streameradmin/`
- Custom servers supported for private deployments

## Building Standalone Executable

### Windows
```bash
cd windows
build_standalone.bat
```

The executable will be created in `windows/dist/StreamerViewer_Standalone.exe`

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

## How It Works

1. **Track Discovery**: Scans `streamerData/tracks/` for TSV files
2. **Video Matching**: Matches videos with tracks based on timestamp overlap
3. **Map Display**: Uses Leaflet.js to display GPS tracks as polylines
4. **Synchronization**: Timeline slider controls both map position and video playback
5. **Playback Controls**: Variable speed playback with play/pause functionality

## Browser Compatibility

The application uses a built-in web browser (pywebview) and is compatible with modern web standards including:
- Leaflet.js for mapping
- HTML5 video for playback
- CSS Grid and Flexbox for responsive layout

## Technical Details

### Performance
- **Executable Size**: ~19MB (includes all dependencies and assets)
- **Font Assets**: Minimal Font Awesome build (~148KB vs 600KB+ full version)
- **Offline Ready**: All assets bundled for complete offline functionality

### API Endpoints
- `GET /` - Main navigation page
- `GET /uploader` - Recording upload interface  
- `GET /view/<track_id>` - Track viewer with maps
- `POST /upload_recording` - File upload handler
- `GET /upload_progress` - Server-Sent Events progress stream

### Browser Compatibility
- Modern web standards (ES6+, CSS Grid, Flexbox)
- HTML5 video and canvas support
- WebView2 engine on Windows

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

## Version History

- **v2.0.0**: Major feature expansion
  - Integrated comprehensive recording upload functionality
  - Added Font Awesome icon system (offline)
  - Enhanced UI with gradients and animations
  - Improved navigation and user experience
  
- **v1.x**: Initial GPS track viewer releases

## Support

For issues, feature requests, or questions:
- **Repository**: https://github.com/tfelici/streamer-viewer
- **Issues**: Use GitHub Issues for bug reports
- **Documentation**: See this README and inline code comments
