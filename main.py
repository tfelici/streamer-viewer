#!/usr/bin/env python3
"""
Streamer Viewer - Standalone GPS Track and Video Viewer
Displays GPS tracks as lines on a map with synchronized video playback
"""

import webview
import threading
import time
import sys
import os
import socket
import json
import glob
import re
from datetime import datetime
from flask import Flask, render_template, request, jsonify, Response, send_file
import csv

# Splash screen support
try:
    import pyi_splash
    SPLASH_AVAILABLE = True
except ImportError:
    SPLASH_AVAILABLE = False

# Add the current directory to Python path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)

# Configuration
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    BASE_DIR = os.path.dirname(sys.executable)
else:
    # Running as script
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

STREAMER_DATA_DIR = os.path.join(BASE_DIR, 'streamerData')
TRACKS_DIR = os.path.join(STREAMER_DATA_DIR, 'tracks')
RECORDINGS_DIR = os.path.join(STREAMER_DATA_DIR, 'recordings', 'webcam')

def get_track_files():
    """Get list of GPS track files (.tsv format)"""
    tracks = []
    if os.path.exists(TRACKS_DIR):
        track_files = glob.glob(os.path.join(TRACKS_DIR, '*.tsv'))
        for track_file in track_files:
            try:
                # Extract track ID from filename
                track_id = os.path.splitext(os.path.basename(track_file))[0]
                
                # Get file stats
                stat = os.stat(track_file)
                created = datetime.fromtimestamp(stat.st_ctime)
                modified = datetime.fromtimestamp(stat.st_mtime)
                size = stat.st_size
                
                # Count coordinates by reading the file
                coord_count = 0
                start_time = None
                end_time = None
                
                with open(track_file, 'r') as f:
                    for line in f:
                        if line.startswith('#') or line.strip() == '':
                            continue
                        if line.startswith('timestamp'):  # Header line
                            continue
                        
                        parts = line.strip().split('\t')
                        if len(parts) >= 3:  # At least timestamp, lat, lon
                            try:
                                timestamp = int(parts[0])
                                if start_time is None:
                                    start_time = timestamp
                                end_time = timestamp
                                coord_count += 1
                            except ValueError:
                                continue
                
                tracks.append({
                    'track_id': track_id,
                    'filename': os.path.basename(track_file),
                    'filepath': track_file,
                    'created': created,
                    'modified': modified,
                    'size': size,
                    'coord_count': coord_count,
                    'start_time': start_time,
                    'end_time': end_time,
                    'duration': end_time - start_time if start_time and end_time else 0
                })
            except Exception as e:
                print(f"Error processing track file {track_file}: {e}")
                continue
    
    # Sort by creation time, newest first
    tracks.sort(key=lambda x: x['created'], reverse=True)
    return tracks

def get_video_files():
    """Get list of video recording files"""
    videos = []
    if os.path.exists(RECORDINGS_DIR):
        video_files = glob.glob(os.path.join(RECORDINGS_DIR, '*.mp4'))
        for video_file in video_files:
            try:
                # Extract timestamp from filename (format: timestamp.mp4)
                filename = os.path.basename(video_file)
                match = re.match(r'^(\d+)\.mp4$', filename)
                if match:
                    timestamp = int(match.group(1))
                    
                    # Get file stats
                    stat = os.stat(video_file)
                    size = stat.st_size
                    
                    videos.append({
                        'filename': filename,
                        'filepath': video_file,
                        'timestamp': timestamp,
                        'datetime': datetime.fromtimestamp(timestamp),
                        'size': size
                    })
            except Exception as e:
                print(f"Error processing video file {video_file}: {e}")
                continue
    
    # Sort by timestamp, newest first
    videos.sort(key=lambda x: x['timestamp'], reverse=True)
    return videos

def load_track_data(track_file):
    """Load GPS track data from TSV file"""
    coordinates = []
    
    try:
        with open(track_file, 'r') as f:
            # Skip comments and header
            lines = f.readlines()
            header_found = False
            
            for line in lines:
                line = line.strip()
                if line.startswith('#') or line == '':
                    continue
                    
                if line.startswith('timestamp') and not header_found:
                    header_found = True
                    continue
                
                parts = line.split('\t')
                if len(parts) >= 3:  # At least timestamp, lat, lon
                    try:
                        coordinate = {
                            'timestamp': int(parts[0]),
                            'location': {
                                'latitude': float(parts[1]),
                                'longitude': float(parts[2]),
                                'altitude': float(parts[3]) if parts[3] and parts[3] != '' else None,
                                'accuracy': float(parts[4]) if len(parts) > 4 and parts[4] and parts[4] != '' else None,
                                'altitudeAccuracy': float(parts[5]) if len(parts) > 5 and parts[5] and parts[5] != '' else None,
                                'heading': float(parts[6]) if len(parts) > 6 and parts[6] and parts[6] != '' else None,
                                'speed': float(parts[7]) if len(parts) > 7 and parts[7] and parts[7] != '' else None
                            }
                        }
                        coordinates.append(coordinate)
                    except ValueError as e:
                        print(f"Error parsing line: {line} - {e}")
                        continue
    
    except Exception as e:
        print(f"Error loading track data: {e}")
        return []
    
    return coordinates

def find_closest_video(track_start_time, track_end_time, videos):
    """Find the video file that best matches the track timing"""
    if not videos:
        return None
    
    best_match = None
    best_score = float('inf')
    
    for video in videos:
        video_timestamp = video['timestamp']
        
        # Calculate overlap or proximity score
        if track_start_time <= video_timestamp <= track_end_time:
            # Video starts during the track - perfect match
            score = 0
        else:
            # Calculate distance from track time range
            if video_timestamp < track_start_time:
                score = track_start_time - video_timestamp
            else:
                score = video_timestamp - track_end_time
        
        if score < best_score:
            best_score = score
            best_match = video
    
    return best_match

@app.template_filter('datetimeformat')
def datetimeformat(value):
    """Format timestamp for display"""
    if value is None:
        return ""
    try:
        if isinstance(value, datetime):
            return value.strftime('%Y-%m-%d %H:%M:%S')
        else:
            dt = datetime.fromtimestamp(int(value))
            return dt.strftime('%Y-%m-%d %H:%M:%S')
    except:
        return str(value)

@app.template_filter('durationformat')
def durationformat(value):
    """Format duration in seconds for display"""
    if value is None or value == 0:
        return ""
    try:
        seconds = int(value)
        h = seconds // 3600
        m = (seconds % 3600) // 60
        s = seconds % 60
        if h > 0:
            return f"{h}:{m:02}:{s:02}"
        else:
            return f"{m}:{s:02}"
    except:
        return str(value)

@app.template_filter('filesizeformat')
def filesizeformat(num_bytes):
    """Format file size for display"""
    if num_bytes is None:
        return ""
    try:
        for unit in ['B', 'KB', 'MB', 'GB']:
            if num_bytes < 1024.0:
                return f"{num_bytes:.1f} {unit}"
            num_bytes /= 1024.0
        return f"{num_bytes:.1f} TB"
    except:
        return str(num_bytes)

@app.route('/')
def index():
    """Main page - Track and Video Viewer"""
    tracks = get_track_files()
    videos = get_video_files()
    
    return render_template('index.html', 
                         tracks=tracks,
                         videos=videos)

@app.route('/view/<track_id>')
def view_track(track_id):
    """View specific track with synchronized video"""
    tracks = get_track_files()
    videos = get_video_files()
    
    # Find the requested track
    track = None
    for t in tracks:
        if t['track_id'] == track_id:
            track = t
            break
    
    if not track:
        return "Track not found", 404
    
    # Load track coordinates
    coordinates = load_track_data(track['filepath'])
    
    if not coordinates:
        return "No coordinate data found in track", 404
    
    # Find matching video
    video = find_closest_video(track['start_time'], track['end_time'], videos)
    
    return render_template('viewer.html',
                         track=track,
                         coordinates=coordinates,
                         video=video)

@app.route('/api/track/<track_id>')
def api_track_data(track_id):
    """API endpoint to get track data as JSON"""
    tracks = get_track_files()
    
    # Find the requested track
    track = None
    for t in tracks:
        if t['track_id'] == track_id:
            track = t
            break
    
    if not track:
        return jsonify({'error': 'Track not found'}), 404
    
    # Load track coordinates
    coordinates = load_track_data(track['filepath'])
    
    return jsonify({
        'track': track,
        'coordinates': coordinates
    })

@app.route('/video/<filename>')
def serve_video(filename):
    """Serve video files"""
    video_path = os.path.join(RECORDINGS_DIR, filename)
    if os.path.exists(video_path):
        return send_file(video_path)
    else:
        return "Video not found", 404

# Web viewer functions
def is_port_available(port):
    """Check if a port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('localhost', port))
            return True
    except OSError:
        return False

def find_available_port(start_port=5001, max_port=5100):
    """Find an available port"""
    for port in range(start_port, max_port):
        if is_port_available(port):
            return port
    return None

def start_flask_server(port):
    """Start Flask server in a separate thread"""
    app.run(host='127.0.0.1', port=port, debug=False, use_reloader=False)

def main():
    """Main function to start the application"""
    print("Starting Streamer Viewer...")
    
    # Update splash screen if available
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text("🚀 Starting Streamer Viewer...")
            time.sleep(0.5)
        except Exception as e:
            print(f"Splash screen update error: {e}")
    
    print(f"Using streamer data directory: {STREAMER_DATA_DIR}")
    
    # Update splash screen if available
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text("📁 Checking data directories...")
            time.sleep(0.3)
        except Exception as e:
            print(f"Splash screen update error: {e}")
        
    # Check if data directories exist        
    if not os.path.exists(STREAMER_DATA_DIR):
        print(f"Warning: Streamer data directory not found: {STREAMER_DATA_DIR}")
    if not os.path.exists(TRACKS_DIR):
        print(f"Warning: Tracks directory not found: {TRACKS_DIR}")
    if not os.path.exists(RECORDINGS_DIR):
        print(f"Warning: Recordings directory not found: {RECORDINGS_DIR}")
    
    # Find available port
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text("🌐 Finding available port...")
            time.sleep(0.3)
        except Exception as e:
            print(f"Splash screen update error: {e}")
        
    port = find_available_port()
    if not port:
        print("No available ports found!")
        if SPLASH_AVAILABLE:
            try:
                pyi_splash.close()
            except:
                pass
        return
    
    print(f"Starting server on port {port}...")
    
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text(f"⚡ Starting web server on port {port}...")
            time.sleep(0.4)
        except Exception as e:
            print(f"Splash screen update error: {e}")
    
    # Start Flask server in background thread
    server_thread = threading.Thread(target=start_flask_server, args=(port,))
    server_thread.daemon = True
    server_thread.start()
    
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text("🎯 Initializing web interface...")
            time.sleep(0.4)
            pyi_splash.update_text("🗺️ Loading GPS components...")
            time.sleep(0.3)
            pyi_splash.update_text("🎥 Preparing video player...")
            time.sleep(0.3)
            pyi_splash.update_text("✨ Almost ready...")
            time.sleep(0.4)
        except Exception as e:
            print(f"Splash screen update error: {e}")
    
    # Wait a moment for server to start
    time.sleep(0.5)
    
    if SPLASH_AVAILABLE:
        try:
            pyi_splash.update_text("✅ Ready! Opening window...")
            time.sleep(0.3)
            pyi_splash.close()
        except Exception as e:
            print(f"Splash screen close error: {e}")
    
    # Create webview window
    window_title = "Streamer Viewer"
    window_url = f"http://127.0.0.1:{port}"
    
    print(f"Opening web viewer: {window_url}")
    
    # Create and start webview
    webview.create_window(
        window_title, 
        window_url,
        width=1200,
        height=800,
        resizable=True
    )
    
    webview.start(debug=False)

if __name__ == '__main__':
    main()
