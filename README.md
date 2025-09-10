# Streamer Viewer

A standalone Python executable for viewing GPS tracks with synchronized video playback from the RPI Streamer project.

## Features

- **GPS Track Visualization**: Display GPS tracks stored in `../streamerData/tracks/` as lines on an interactive map using Leaflet.js
- **Video Synchronization**: Show videos from `../streamerData/recordings/webcam/` synchronized with GPS track timeline
- **Interactive Playback**: Timeline slider with play/pause controls and variable speed playback
- **Automatic Matching**: Automatically finds and matches video files with GPS tracks based on timestamps
- **Standalone Executable**: No Python installation required for end users

## Directory Structure

The application expects the following directory structure:
```
Streamer Viewer/
├── main.py                 # Main application
├── requirements.txt        # Python dependencies
├── templates/             # HTML templates
│   ├── index.html         # Track list page
│   └── viewer.html        # Track viewer page
├── static/
│   └── style.css          # Application styles
├── streamerData/          # Data directory
│   ├── tracks/            # GPS track files (*.tsv)
│   └── recordings/
│       └── webcam/        # Video files (*.mp4)
└── windows/
    ├── build_standalone.bat
    ├── StreamerViewer_onefile.spec
    └── version_info.txt
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

1. **Development**: Run `python main.py`
2. **Standalone**: Build executable with `windows/build_standalone.bat`

## Building Standalone Executable

### Windows
```bash
cd windows
build_standalone.bat
```

The executable will be created in `windows/dist/StreamerViewer_Standalone.exe`

## Dependencies

- Flask (web framework)
- pywebview (desktop app wrapper)
- pyinstaller (for building executables)

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

## File Size

The standalone executable is optimized for size and should be comparable to the Streamer Uploader (~16MB).

## Related Projects

This application is part of the RPI Streamer ecosystem:
- **RPI Streamer**: Records GPS tracks and videos
- **Streamer Uploader**: Uploads recordings to server
- **Streamer Viewer**: Views tracks and videos (this application)
- **Streamer Admin**: Server administration
