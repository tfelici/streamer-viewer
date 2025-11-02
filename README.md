# Streamer Viewer

A comprehensive standalone Python application for viewing GPS tracks with synchronized video playback and uploading recordings from the RPI Streamer project. This unified application provides complete GPS track management and recording upload functionality in a single, user-friendly interface.

## Features

### 🗺️ GPS Track Visualization
- **Interactive Maps**: Display GPS tracks as lines on Leaflet.js maps with OpenStreetMap tiles
- **Track Management**: Browse, view, and delete GPS tracks with an intuitive interface
- **Real-time Playback**: Timeline slider with play/pause controls and variable speed playback
- **Video Synchronization**: Synchronized video playback with GPS position tracking

### 📡 Recording Upload & Sync
- **Server Upload**: Upload recordings directly to your RPI Streamer server
- **Progress Monitoring**: Real-time upload progress with cancel capability
- **Bulk Operations**: Select and upload multiple recordings simultaneously
- **Server Integration**: Seamless integration with Streamer Admin backend

### 🎨 Modern Interface
- **Font Awesome Icons**: Beautiful, offline-compatible icon system
- **Responsive Design**: Works perfectly on desktop and mobile devices
- **Gradient Themes**: Modern CSS styling with smooth animations
- **Intuitive Navigation**: Easy switching between track viewing and recording upload modes

### 🚀 Deployment
- **Standalone Executable**: Single-file Windows executable (~19MB)
- **No Dependencies**: No Python installation required for end users
- **Offline Compatible**: All assets bundled for complete offline functionality

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
