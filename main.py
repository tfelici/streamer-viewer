#!/usr/bin/env python3
"""
Streamer Viewer - Standalone GPS Track and Video Viewer
Displays GPS tracks as lines on a map with synchronized video playback

Command line usage:
    python main.py [--data-dir PATH]

Arguments:
    --data-dir PATH    Specify custom path to streamer data directory
                      (default: ./streamerData)

Examples:
    python main.py
    python main.py --data-dir "C:\\MyStreamerData"
    python main.py --data-dir "/home/user/streamer_data"
"""

import threading
import time
import sys
import os
import socket
import glob
import re
import argparse
from datetime import datetime
from flask import Flask, render_template, request, jsonify, send_file, Response
import json
import uuid
from werkzeug.utils import secure_filename
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

# Try to import webview early (available on all platforms)
try:
    import webview
except ImportError:
    webview = None
# If webview import fails, it will be imported dynamically when needed

# Pure Python MP4 parsing
import struct

# Splash screen support (PyInstaller - available on all platforms)
SPLASH_AVAILABLE = False

try:
    import pyi_splash
    SPLASH_AVAILABLE = True
except ImportError:
    # No splash screen when running as script or PyInstaller not used
    pass

def update_splash_text(text):
    """Update splash screen text (PyInstaller - available on all platforms)"""
    if not SPLASH_AVAILABLE:
        print(f"[Streamer Viewer] {text}")  # Print to console when no splash screen
        return
        
    try:
        pyi_splash.update_text(text)
    except Exception as e:
        print(f"Splash screen update error: {e}")

def close_splash():
    """Close splash screen (PyInstaller - available on all platforms)"""
    if not SPLASH_AVAILABLE:
        return
        
    try:
        pyi_splash.close()
    except Exception as e:
        print(f"Splash screen close error: {e}")

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Streamer Viewer - GPS Track and Video Viewer')
    parser.add_argument(
        '--data-dir', 
        type=str, 
        help='Path to the streamer data directory (default: ./streamerData)'
    )
    return parser.parse_args()

def open_browser(url):
    """Open URL in default browser (Linux/macOS fallback)"""
    import webbrowser
    try:
        # Use Python's webbrowser module - it should handle default browser correctly
        webbrowser.open(url, new=2)  # new=2 opens in new tab if possible
        return True
    except Exception as e:
        print(f"Failed to open browser: {e}")
        return False

# Add the current directory to Python path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__)

# Parse command line arguments
args = parse_arguments()

# Configuration
if getattr(sys, 'frozen', False):
    # Running as compiled executable
    BASE_DIR = os.path.dirname(sys.executable)
else:
    # Running as script
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Set STREAMER_DATA_DIR from command line argument or default
if args.data_dir:
    # Use absolute path from command line argument
    STREAMER_DATA_DIR = os.path.abspath(args.data_dir)
else:
    # Use default path relative to the application directory
    STREAMER_DATA_DIR = os.path.join(BASE_DIR, 'streamerData')

TRACKS_DIR = os.path.join(STREAMER_DATA_DIR, 'tracks')
RECORDINGS_DIR = os.path.join(STREAMER_DATA_DIR, 'recordings', 'webcam')

# Global dictionary to track upload progress and allow cancellation
upload_progress = {}
upload_threads = {}
# SSE clients tracking for upload progress
upload_sse_clients = {}

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
    """Get list of video recording files from hierarchical directory structure"""
    videos = []
    
    if not os.path.exists(RECORDINGS_DIR):
        return videos
    
    # Walk through hierarchical structure: domain/rtmpkey/files
    for domain in os.listdir(RECORDINGS_DIR):
        domain_path = os.path.join(RECORDINGS_DIR, domain)
        if not os.path.isdir(domain_path):
            continue
            
        for rtmpkey in os.listdir(domain_path):
            rtmpkey_path = os.path.join(domain_path, rtmpkey)
            if not os.path.isdir(rtmpkey_path):
                continue
                
            # Get all mp4 files in this rtmpkey directory
            for filename in os.listdir(rtmpkey_path):
                if filename.endswith('.mp4'):
                    video_file = os.path.join(rtmpkey_path, filename)
                    try:
                        # Extract timestamp from filename (format: timestamp.mp4)
                        match = re.match(r'^(\d+)\.mp4$', filename)
                        if match:
                            timestamp = int(match.group(1))
                            
                            # Get file stats
                            stat = os.stat(video_file)
                            size = stat.st_size
                            
                            # Get video duration
                            duration = get_video_duration_mediainfo(video_file)
                            end_time = None
                            if duration is not None:
                                end_time = timestamp + duration
                            
                            # Create display name with domain/rtmpkey context
                            display_name = f"{domain}/{rtmpkey}/{filename}"
                            
                            video_data = {
                                'filename': display_name,
                                'filepath': video_file,
                                'timestamp': timestamp,
                                'datetime': datetime.fromtimestamp(timestamp),
                                'size': size,
                                'domain': domain,
                                'rtmpkey': rtmpkey
                            }
                            
                            # Only add duration and end_time if we successfully got them
                            if duration is not None:
                                video_data['duration'] = duration
                                video_data['end_time'] = end_time
                            
                            videos.append(video_data)
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

def get_video_duration_mediainfo(path):
    """Get video duration using pymediainfo library"""
    try:
        from pymediainfo import MediaInfo
        media_info = MediaInfo.parse(path)
        
        # Try Video track first (most accurate for video files)
        for track in media_info.tracks:
            if track.track_type == 'Video' and track.duration:
                return track.duration / 1000.0  # ms to seconds
        
        # Fallback to General track
        for track in media_info.tracks:
            if track.track_type == 'General' and track.duration:
                return track.duration / 1000.0
                
    except ImportError:
        print(f"Error: pymediainfo not available. Please install with: pip install pymediainfo")
        return None
    except Exception as e:
        print(f"Error reading video duration for {path}: {e}")
        return None
    
    return None

def safe_remove_file(file_path):
    """
    Safely remove a file and ensure it's actually deleted from storage device.
    
    Args:
        file_path (str): Path to the file to be removed
        
    Returns:
        bool: True if file was successfully removed, False otherwise
    """
    try:
        os.remove(file_path)
        
        # Force filesystem sync to ensure deletion is written to disk
        try:
            if os.name == 'nt':  # Windows
                import ctypes
                # Get the drive letter of the file path
                drive = os.path.splitdrive(file_path)[0]
                if drive:
                    # Force flush of all cached writes for this drive
                    handle = ctypes.windll.kernel32.CreateFileW(
                        drive + "\\", 0x40000000, 3, None, 3, 0x02000000, None
                    )
                    if handle != -1:
                        ctypes.windll.kernel32.FlushFileBuffers(handle)
                        ctypes.windll.kernel32.CloseHandle(handle)
            else:  # Unix-like systems
                os.sync()
        except Exception:
            pass  # Ignore sync errors
            
        return True
    except Exception as e:
        print(f"Error removing file {file_path}: {e}")
        return False



def find_all_related_videos(track_start_time, track_end_time, videos):
    """
    Find all video files that temporally overlap with the track timing.
    
    Args:
        track_start_time: Start timestamp of the track
        track_end_time: End timestamp of the track
        videos: List of video files with duration and end_time
    
    Returns:
        List of video files that have temporal overlap with the track timespan
    """
    if not videos:
        return []
    
    related_videos = []
    
    for video in videos:
        video_start = video['timestamp']
        video_end = video.get('end_time')
        
        # Skip videos without duration/end_time information
        if video_end is None:
            continue
        
        # Check for temporal overlap between video and track
        # Two time ranges overlap if: max(start1, start2) < min(end1, end2)
        overlap_start = max(track_start_time, video_start)
        overlap_end = min(track_end_time, video_end)
        
        if overlap_start < overlap_end:
            # There is an overlap
            related_videos.append(video)
    
    # Sort by timestamp to return in chronological order
    related_videos.sort(key=lambda x: x['timestamp'])
    
    return related_videos

def get_recording_files():
    """Get list of recording files from the hierarchical recordings directory structure"""
    files = []
    
    if not os.path.exists(RECORDINGS_DIR):
        return files
    
    # Collect all files with their modification times for sorting
    all_files = []
    
    # Walk through hierarchical structure: domain/rtmpkey/files
    for domain in os.listdir(RECORDINGS_DIR):
        domain_path = os.path.join(RECORDINGS_DIR, domain)
        if not os.path.isdir(domain_path):
            continue
            
        for rtmpkey in os.listdir(domain_path):
            rtmpkey_path = os.path.join(domain_path, rtmpkey)
            if not os.path.isdir(rtmpkey_path):
                continue
                
            # Get all mp4 files in this rtmpkey directory
            for filename in os.listdir(rtmpkey_path):
                if filename.endswith('.mp4'):
                    file_path = os.path.join(rtmpkey_path, filename)
                    try:
                        mtime = os.path.getmtime(file_path)
                        display_name = f"{domain}/{rtmpkey}/{filename}"
                        all_files.append((mtime, file_path, display_name, domain, rtmpkey))
                    except OSError:
                        continue
    
    # Sort all files by modification time, newest first
    all_files.sort(key=lambda x: x[0], reverse=True)
    
    # Process sorted files
    for mtime, file_path, display_name, domain, rtmpkey in all_files:
        try:
            size = os.path.getsize(file_path)
            duration = get_video_duration_mediainfo(file_path)
            
            # Extract timestamp from filename if possible (format: timestamp.mp4)
            filename = os.path.basename(file_path)
            m = re.match(r'^(\d+)\.mp4$', filename)
            timestamp = int(m.group(1)) if m else None
            
            files.append({
                'path': file_path,
                'name': display_name,
                'size': size,
                'location': 'Local',
                'active': False,  # No active recordings in upload interface
                'duration': duration,
                'timestamp': timestamp,
                'domain': domain,
                'rtmpkey': rtmpkey
            })
            
        except OSError:
            continue
    
    return files

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
    """View specific track with synchronized multi-video playback"""
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
    
    # Find all matching videos for this track
    videos_for_track = find_all_related_videos(track['start_time'], track['end_time'], videos)
    
    return render_template('viewer.html',
                         track=track,
                         coordinates=coordinates,
                         videos=videos_for_track)

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

@app.route('/video/<path:filename>')
def serve_video(filename):
    """Serve video files from hierarchical directory structure"""
    # Handle paths like "domain/rtmpkey/timestamp.mp4"
    video_path = os.path.join(RECORDINGS_DIR, filename)
    if os.path.exists(video_path) and video_path.startswith(RECORDINGS_DIR):
        return send_file(video_path)
    else:
        return "Video not found", 404

@app.route('/delete-track', methods=['POST'])
def delete_track():
    """Delete a track and its corresponding video file"""
    try:
        data = request.get_json()
        track_id = data.get('track_id')
        
        if not track_id:
            return jsonify({'error': 'Track ID not provided'}), 400
        
        # Find the track
        tracks = get_track_files()
        track = None
        for t in tracks:
            if t['track_id'] == track_id:
                track = t
                break
        
        if not track:
            return jsonify({'error': 'Track not found'}), 404
        
        # Delete the track file
        track_deleted = False
        if os.path.exists(track['filepath']):
            if safe_remove_file(track['filepath']):
                track_deleted = True
            else:
                return jsonify({'error': 'Failed to delete track file'}), 500
        
        # Find and delete all corresponding videos
        videos = get_video_files()
        videos_deleted = 0
        videos_failed = 0
        corresponding_videos = find_all_related_videos(track['start_time'], track['end_time'], videos)
        
        for video in corresponding_videos:
            video_path = video['filepath']
            if os.path.exists(video_path):
                if safe_remove_file(video_path):
                    videos_deleted += 1
                else:
                    videos_failed += 1
        
        # Handle partial failures
        if videos_failed > 0 and videos_deleted == 0:
            # Track was deleted but all videos failed
            return jsonify({
                'success': True,
                'track_deleted': True,
                'video_deleted': False,
                'message': f'Track deleted successfully, but failed to delete {videos_failed} corresponding video file(s)'
            })
        elif videos_failed > 0:
            # Track was deleted and some videos deleted, but some failed
            return jsonify({
                'success': True,
                'track_deleted': True,
                'video_deleted': True,
                'message': f'Track deleted successfully along with {videos_deleted} video(s), but failed to delete {videos_failed} video file(s)'
            })
        
        # All videos deleted successfully or no videos found
        video_deleted = videos_deleted > 0
        if videos_deleted > 0:
            message = f'Track deleted successfully along with {videos_deleted} corresponding video(s)'
        else:
            message = 'Track deleted successfully (no corresponding videos found)'
        
        return jsonify({
            'success': True,
            'track_deleted': track_deleted,
            'video_deleted': video_deleted,
            'message': message
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to delete track: {str(e)}'}), 500

@app.route('/uploader')
def uploader():
    """Recording upload page - Upload recordings to server"""
    recording_files = get_recording_files()
    return render_template('uploader.html', 
                         recording_files=recording_files,
                         uploadrecordingsonly=True)

@app.route('/upload-recording', methods=['POST'])
def upload_recording():
    """Upload a recording file to the configured server"""
    from werkzeug.utils import secure_filename
    import re
    
    file_path = request.form.get('file_path')
    if not file_path or not os.path.isfile(file_path):
        return jsonify({'error': 'Recording file not found.'}), 400
    
    # Extract domain and rtmpkey from hierarchical file path
    # Expected format: .../recordings/webcam/<domain>/<rtmpkey>/<filename>
    try:
        # Get the relative path from the recordings/webcam directory
        path_parts = file_path.replace('\\', '/').split('/')
        
        # Find the webcam directory and extract domain/rtmpkey from the path after it
        webcam_idx = -1
        for i, part in enumerate(path_parts):
            if part == 'webcam':
                webcam_idx = i
                break
        
        if webcam_idx == -1 or webcam_idx + 2 >= len(path_parts):
            return jsonify({'error': 'Invalid file path format. Expected: .../recordings/webcam/<domain>/<rtmpkey>/<filename>'}), 400
        
        domain = path_parts[webcam_idx + 1]
        rtmpkey = path_parts[webcam_idx + 2]
        
        if not domain or not rtmpkey:
            return jsonify({'error': 'Could not extract domain and rtmpkey from file path.'}), 400
        
        # Construct upload URL dynamically
        upload_url = f"https://{domain}.org/ajaxservices.php?command=replacerecordings&rtmpkey={rtmpkey}"
        
    except Exception as e:
        return jsonify({'error': f'Failed to parse file path: {e}'}), 400
    
    # Generate unique upload ID for progress tracking
    upload_id = str(uuid.uuid4())
    
    # Store upload progress globally
    upload_progress[upload_id] = {
        'progress': 0,
        'status': 'starting',
        'error': None,
        'result': None,
        'cancelled': False
    }
    
    def upload_file_async():
        try:
            upload_progress[upload_id]['status'] = 'uploading'
            
            # Get file size for progress calculation
            file_size = os.path.getsize(file_path)
            
            def progress_callback(monitor):
                if upload_progress[upload_id]['cancelled']:
                    # Cancel the upload by raising an exception
                    raise Exception("Upload cancelled by user")
                
                progress = min(100, int((monitor.bytes_read / file_size) * 100))
                upload_progress[upload_id]['progress'] = progress
                
                # Notify all SSE clients about the progress
                for client_id, client_data in upload_sse_clients.items():
                    if client_data['upload_id'] == upload_id:
                        try:
                            # Send progress update to SSE client
                            client_data['queue'].put({'progress': progress})
                        except Exception:
                            pass  # Ignore errors in notifying clients
            
            # Use MultipartEncoder for upload with progress monitoring
            with open(file_path, 'rb') as f:
                multipart_data = MultipartEncoder(
                    fields={'video': (secure_filename(os.path.basename(file_path)), f, 'application/octet-stream')}
                )
                
                monitor = MultipartEncoderMonitor(multipart_data, progress_callback)
                
                response = requests.post(
                    upload_url, 
                    data=monitor,
                    headers={'Content-Type': monitor.content_type},
                    timeout=300
                )
                
                if response.status_code == 200:
                    try:
                        result = response.json()
                    except:
                        result = {'success': True, 'message': 'Upload completed', 'error': ''}
                else:
                    result = {'error': f'Upload failed: {response.status_code}'}
                
                upload_progress[upload_id]['status'] = 'completed'
                upload_progress[upload_id]['progress'] = 100
                upload_progress[upload_id]['result'] = result
                        
        except Exception as e:
            if upload_progress[upload_id]['cancelled']:
                upload_progress[upload_id]['status'] = 'cancelled'
                upload_progress[upload_id]['error'] = 'Upload cancelled by user'
            else:
                upload_progress[upload_id]['status'] = 'error'
                upload_progress[upload_id]['error'] = f'Upload failed: {e}'
        finally:
            # Clean up thread reference
            if upload_id in upload_threads:
                del upload_threads[upload_id]
    
    # Start upload in background thread
    thread = threading.Thread(target=upload_file_async)
    thread.daemon = True
    thread.start()
    
    # Store thread reference for potential cancellation
    upload_threads[upload_id] = thread
    
    return jsonify({'upload_id': upload_id, 'status': 'started'})

@app.route('/upload-progress/<upload_id>')
def get_upload_progress(upload_id):
    """Get the current progress of an upload"""
    if upload_id not in upload_progress:
        return jsonify({'error': 'Upload ID not found'}), 404
    
    progress_data = upload_progress[upload_id].copy()
    
    # Clean up completed/error/cancelled uploads after returning status
    if progress_data['status'] in ['completed', 'error', 'cancelled']:
        # Keep the data for a short time to allow frontend to get final status
        pass
    
    return jsonify(progress_data)

@app.route('/cancel-upload/<upload_id>', methods=['POST'])
def cancel_upload(upload_id):
    """Cancel an ongoing upload"""
    if upload_id not in upload_progress:
        return jsonify({'error': 'Upload ID not found'}), 404
    
    # Mark upload as cancelled
    upload_progress[upload_id]['cancelled'] = True
    upload_progress[upload_id]['status'] = 'cancelling'
    
    return jsonify({'status': 'cancelling'})

@app.route('/upload-progress-stream/<upload_id>')
def upload_progress_stream(upload_id):
    """SSE endpoint for real-time upload progress monitoring"""
    def generate():
        # Send initial connection event
        yield f"data: {json.dumps({'type': 'connected', 'upload_id': upload_id})}\n\n"
        
        # Monitor upload progress
        while upload_id in upload_progress:
            progress_data = upload_progress[upload_id].copy()
            
            # Send progress update
            progress_data['type'] = 'progress'
            yield f"data: {json.dumps(progress_data)}\n\n"
            
            # If upload is finished, send final status and close
            if progress_data['status'] in ['completed', 'error', 'cancelled']:
                time.sleep(0.1)  # Small delay to ensure client receives final update
                break
                
            time.sleep(0.2)  # Update every 200ms for real-time feel
        
        # Send close event
        yield f"data: {json.dumps({'type': 'closed', 'upload_id': upload_id})}\n\n"
    
    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Cache-Control'
        }
    )

@app.route('/delete-recording', methods=['POST'])
def delete_recording():
    """Delete a recording file"""
    data = request.get_json()
    file_path = data.get('file_path')
    if not file_path or not os.path.isfile(file_path):
        return jsonify({'error': 'Recording file not found.'}), 400
    try:
        if safe_remove_file(file_path):
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'Failed to delete file'}), 500
    except Exception as e:
        return jsonify({'error': f'Failed to delete: {e}'}), 500

# Web viewer functions
def is_port_available(port):
    """Check if a port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('localhost', port))
            return True
    except OSError:
        return False

def find_existing_instance(start_port=5001, max_port=5100):
    """Check if Streamer Viewer is already running on any port in range"""
    import urllib.request
    import urllib.error
    import http.client
    
    for port in range(start_port, max_port):
        if not is_port_available(port):
            # Port is in use, check if it's our app
            try:
                url = f"http://127.0.0.1:{port}/"
                response = urllib.request.urlopen(url, timeout=2)
                content = response.read().decode('utf-8')
                # Check if this looks like our Streamer Viewer app
                if 'Streamer Viewer' in content or 'GPS Track and Video Viewer' in content:
                    return port
            except (urllib.error.URLError, ConnectionRefusedError, socket.timeout, 
                    http.client.RemoteDisconnected, http.client.HTTPException, OSError):
                # Skip this port if connection fails for any reason
                continue
    return None

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
    
    # Check webview availability once at startup
    webview_available = False
    webview_module = None
    try:
        if webview is not None:
            webview_module = webview
            webview_available = True
        else:
            # Try dynamic import
            import webview as webview_module
            webview_available = True
    except (ImportError, NameError):
        webview_available = False
        print("Webview not available, will use browser fallback")
    
    # Update splash screen if available (PyInstaller builds)
    update_splash_text("🚀 Starting Streamer Viewer...")
    if SPLASH_AVAILABLE:
        time.sleep(1.0)  # Only delay if splash screen is visible
    
    # Check if another instance is already running
    update_splash_text("🔍 Checking for existing instance...")
    if SPLASH_AVAILABLE:
        time.sleep(0.3)
    
    existing_port = find_existing_instance()
    if existing_port:
        print(f"Found existing Streamer Viewer instance on port {existing_port}")
        update_splash_text("✅ Opening existing instance...")
        if SPLASH_AVAILABLE:
            time.sleep(0.3)
        
        # Open the existing instance
        existing_url = f"http://127.0.0.1:{existing_port}"
        
        # Use webview if available, otherwise fallback to browser
        if webview_available and webview_module is not None:
            try:
                webview_module.create_window(
                    "Streamer Viewer", 
                    existing_url,
                    width=1200,
                    height=800,
                    resizable=True
                )
                # Close splash screen just before webview starts
                close_splash()
                webview_module.start(debug=False)
            except Exception as e:
                print(f"Webview failed to start ({e}), using browser fallback...")
                # Fallback to browser
                if open_browser(existing_url):
                    print("✅ Opened existing instance in browser")
                else:
                    print(f"⚠️  Please open {existing_url} manually")
                
                # Close splash screen after browser attempt (successful or not)
                close_splash()
        else:
            # Use browser fallback
            if open_browser(existing_url):
                print("✅ Opened existing instance in browser")
            else:
                print(f"⚠️  Please open {existing_url} manually")
            
            # Close splash screen after browser attempt (successful or not)
            close_splash()
        
        return  # Exit without starting new server
    
    print("No existing instance found, starting new server...")
    if args.data_dir:
        print(f"Using custom streamer data directory: {STREAMER_DATA_DIR}")
    else:
        print(f"Using default streamer data directory: {STREAMER_DATA_DIR}")
    
    # Update splash screen if available
    update_splash_text("📁 Checking data directories...")
    if SPLASH_AVAILABLE:
        time.sleep(0.8)
        
    # Check if data directories exist        
    if not os.path.exists(STREAMER_DATA_DIR):
        print(f"Warning: Streamer data directory not found: {STREAMER_DATA_DIR}")
    if not os.path.exists(TRACKS_DIR):
        print(f"Warning: Tracks directory not found: {TRACKS_DIR}")
    if not os.path.exists(RECORDINGS_DIR):
        print(f"Warning: Recordings directory not found: {RECORDINGS_DIR}")
    
    # Find available port
    update_splash_text("🌐 Finding available port...")
    if SPLASH_AVAILABLE:
        time.sleep(0.3)
        
    port = find_available_port()
    if not port:
        print("No available ports found!")
        close_splash()
        return
    
    print(f"Starting server on port {port}...")
    
    update_splash_text(f"⚡ Starting web server on port {port}...")
    if SPLASH_AVAILABLE:
        time.sleep(0.4)
    
    # Start Flask server in background thread
    server_thread = threading.Thread(target=start_flask_server, args=(port,))
    server_thread.daemon = True
    server_thread.start()
    
    update_splash_text("🎯 Initializing web interface...")
    if SPLASH_AVAILABLE:
        time.sleep(0.4)
        update_splash_text("🗺️ Loading GPS components...")
        time.sleep(0.3)
        update_splash_text("🎥 Preparing video player...")
        time.sleep(0.3)
        update_splash_text("✨ Almost ready...")
        time.sleep(0.4)
    
    # Wait a moment for server to start
    time.sleep(0.5)
    
    # Platform-specific UI approach
    window_url = f"http://127.0.0.1:{port}"
    
    # Try webview first (available on all platforms), fallback to browser
    update_splash_text("✅ Ready! Opening application...")
    if SPLASH_AVAILABLE:
        time.sleep(0.3)
    
    # Use webview if available, otherwise fallback to browser
    if webview_available and webview_module is not None:
        try:
            print(f"Opening webview window: {window_url}")
            webview_module.create_window(
                "Streamer Viewer", 
                window_url,
                width=1200,
                height=800,
                resizable=True
            )
            # Close splash screen just before webview starts
            close_splash()
            webview_module.start(debug=False)
        except Exception as e:
            print(f"Webview failed to start ({e}), using browser fallback...")
            # Fallback to browser and keep server running
            print(f"Opening in browser: {window_url}")
            print("=" * 60)
            print("🚀 Streamer Viewer is now running!")
            print(f"📍 Web interface: {window_url}")
            print("🌐 Opening in your default browser...")
            print("❌ Close this terminal window to stop the server")
            print("=" * 60)
            
            if open_browser(window_url):
                print("✅ Browser opened successfully")
            else:
                print("⚠️  Could not open browser automatically")
                print(f"   Please open {window_url} manually")
            
            # Close splash screen after browser attempt (successful or not)
            close_splash()
            
            # Keep server running
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                print("\n👋 Shutting down Streamer Viewer...")
                return
    else:
        # Use browser fallback
        print(f"Opening in browser: {window_url}")
        print("=" * 60)
        print("🚀 Streamer Viewer is now running!")
        print(f"📍 Web interface: {window_url}")
        print("🌐 Opening in your default browser...")
        print("❌ Close this terminal window to stop the server")
        print("=" * 60)
        
        # Open in default browser
        if open_browser(window_url):
            print("✅ Browser opened successfully")
        else:
            print("⚠️  Could not open browser automatically")
            print(f"   Please open {window_url} manually")
        
        # Close splash screen after browser attempt (successful or not)
        close_splash()
        
        # Keep server running (only needed when using browser fallback)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n👋 Shutting down Streamer Viewer...")
            return

if __name__ == '__main__':
    main()
