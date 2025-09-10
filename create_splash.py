#!/usr/bin/env python3
"""
Create an animated splash screen image for Streamer Viewer
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import math
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

def create_animated_splash_frame(frame_num, total_frames):
    """Create a single frame of the animated splash screen"""
    if not PIL_AVAILABLE:
        return None
    
    # Create a 500x300 image with a gradient background
    width, height = 500, 300
    img = Image.new('RGB', (width, height), '#2c3e50')
    draw = ImageDraw.Draw(img)
    
    # Create animated gradient effect
    for y in range(height):
        # Add subtle animation to the gradient
        animation_offset = math.sin(frame_num * 0.1) * 0.1
        r = int(44 + (52 - 44) * (y / height + animation_offset))
        g = int(62 + (73 - 62) * (y / height + animation_offset))
        b = int(80 + (83 - 80) * (y / height + animation_offset))
        r = max(0, min(255, r))
        g = max(0, min(255, g))
        b = max(0, min(255, b))
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # Add subtle animated particles/dots in background
    for i in range(20):
        x = (i * 31 + frame_num * 2) % width
        y = (i * 47 + frame_num) % height
        alpha = int(128 + 127 * math.sin(frame_num * 0.05 + i))
        size = 1 + int(2 * math.sin(frame_num * 0.03 + i * 0.5))
        color = (alpha // 3, alpha // 2, alpha)
        draw.ellipse([x-size, y-size, x+size, y+size], fill=color)
    
    # Try to use a nice font
    try:
        font_large = ImageFont.truetype("arial.ttf", 36)
        font_medium = ImageFont.truetype("arial.ttf", 18)
        font_small = ImageFont.truetype("arial.ttf", 14)
    except:
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Animated title with subtle pulsing
    title = "Streamer Viewer"
    pulse = 1 + 0.05 * math.sin(frame_num * 0.08)
    title_alpha = int(255 * (0.9 + 0.1 * math.sin(frame_num * 0.1)))
    title_color = (title_alpha, title_alpha, title_alpha)
    
    title_bbox = draw.textbbox((0, 0), title, font=font_large)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    draw.text((title_x, 80), title, fill=title_color, font=font_large)
    
    # Subtitle
    subtitle = "GPS Track & Video Viewer"
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=font_medium)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_width) // 2
    draw.text((subtitle_x, 130), subtitle, fill='#bdc3c7', font=font_medium)
    
    # Animated loading text with dots
    loading_dots = "." * ((frame_num // 10) % 4)
    loading = f"Loading{loading_dots}"
    loading_bbox = draw.textbbox((0, 0), loading, font=font_small)
    loading_width = loading_bbox[2] - loading_bbox[0]
    loading_x = (width - loading_width) // 2
    draw.text((loading_x, 200), loading, fill='#95a5a6', font=font_small)
    
    # Animated progress bar
    bar_width = 200
    bar_height = 6
    bar_x = (width - bar_width) // 2
    bar_y = 230
    
    # Progress bar background
    draw.rectangle([bar_x, bar_y, bar_x + bar_width, bar_y + bar_height], fill='#34495e', outline='#95a5a6', width=1)
    
    # Animated progress fill
    progress = (frame_num % 100) / 100  # Cycle progress 0-100%
    fill_width = int(bar_width * progress)
    if fill_width > 0:
        # Create gradient fill
        for i in range(fill_width):
            color_intensity = int(52 + 155 * (i / bar_width))
            fill_color = (color_intensity, color_intensity + 50, 255)
            draw.line([(bar_x + i, bar_y + 1), (bar_x + i, bar_y + bar_height - 1)], fill=fill_color)
    
    # Animated spinning indicator
    center_x, center_y = width - 50, height - 50
    radius = 15
    
    # Draw spinning circle segments
    for i in range(8):
        angle = (frame_num * 0.2 + i * 45) % 360
        start_angle = angle - 20
        end_angle = angle + 20
        
        # Calculate alpha based on position
        alpha = int(255 * (0.3 + 0.7 * (i / 8)))
        color = (alpha, alpha, 255)
        
        # Draw arc segment
        x1 = center_x + radius * math.cos(math.radians(start_angle))
        y1 = center_y + radius * math.sin(math.radians(start_angle))
        x2 = center_x + radius * math.cos(math.radians(end_angle))
        y2 = center_y + radius * math.sin(math.radians(end_angle))
        
        draw.line([(center_x, center_y), (x1, y1)], fill=color, width=2)
    
    return img

def create_splash_screen():
    """Create the splash screen - for PyInstaller we need a static image, but we can make it look dynamic"""
    if not PIL_AVAILABLE:
        print("PIL/Pillow not available. Please install with: pip install Pillow")
        return False
    
    # Create a nice-looking static splash that suggests animation
    frame = create_animated_splash_frame(30, 100)  # Use frame 30 for a good static look
    
    if frame:
        frame.save('splash.png', 'PNG')
        print("Animated-style splash screen created: splash.png")
        return True
    
    return False

def create_gif_preview():
    """Create an animated GIF preview of what the splash would look like"""
    if not PIL_AVAILABLE:
        print("PIL/Pillow not available for GIF creation")
        return False
    
    frames = []
    total_frames = 60
    
    print("Creating animated GIF preview...")
    for i in range(total_frames):
        frame = create_animated_splash_frame(i, total_frames)
        if frame:
            frames.append(frame)
        if i % 10 == 0:
            print(f"Generated frame {i}/{total_frames}")
    
    if frames:
        frames[0].save('splash_preview.gif', 
                      save_all=True, 
                      append_images=frames[1:], 
                      duration=100,  # 100ms per frame = 10 FPS
                      loop=0)
        print("Animated preview created: splash_preview.gif")
        return True
    
    return False

if __name__ == '__main__':
    print("Creating splash screen...")
    create_splash_screen()
    
    print("\nCreating animated preview...")
    create_gif_preview()
    print("\nDone! Check splash.png (for PyInstaller) and splash_preview.gif (to see animation)")
