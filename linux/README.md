# Linux Build for Streamer Viewer

This directory contains build scripts and configuration for creating Linux executables of Streamer Viewer.

## Quick Build

### Using WSL (Windows Subsystem for Linux)
```bash
# From Windows PowerShell/Command Prompt
wsl -d Ubuntu
cd /mnt/c/Users/tfeli/Dropbox/work/Streamer\ Viewer/linux
bash build_standalone.sh
```

### On Native Linux System
```bash
cd /path/to/Streamer-Viewer/linux
bash build_standalone.sh
```

## Manual Build Process

If you prefer to build manually:

1. **Install dependencies**:
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv build-essential
```

2. **Set up virtual environment**:
```bash
cd ../  # Go to project root
python3 -m venv venv
source venv/bin/activate
```

3. **Install Python dependencies**:
```bash
pip install -r requirements.txt
pip install pyinstaller
```

4. **Build executable**:
```bash
# Option A: Using build script
cd linux
bash build_standalone.sh

# Option B: Using spec file
pyinstaller linux/StreamerViewer_onefile.spec

# Option C: Direct command
pyinstaller --onefile --windowed --name StreamerViewer \
    --add-data "templates:templates" \
    --add-data "static:static" \
    --hidden-import=pymediainfo \
    main.py
```

## Output

- **Executable**: `dist/StreamerViewer`
- **Size**: Approximately 15-25MB
- **Architecture**: Same as build system (x86_64, ARM64, etc.)

## Distribution

### System Requirements
- **OS**: Linux with glibc 2.17+ (Ubuntu 16.04+, CentOS 7+, Debian 9+)
- **Architecture**: x86_64 (Intel/AMD 64-bit)
- **Memory**: 512MB RAM minimum
- **Storage**: 50MB free space

### Compatibility
The executable should work on most modern Linux distributions including:
- Ubuntu 18.04 LTS and newer
- Debian 9 (Stretch) and newer
- CentOS 7 and newer / RHEL 7+
- Fedora 28 and newer
- openSUSE Leap 15.0 and newer
- Arch Linux (current)

### Testing
Test the executable on target systems:
```bash
# Check executable info
file StreamerViewer
ldd StreamerViewer

# Test run
./StreamerViewer --help
```

## Cross-Platform Building

### For ARM64 (Raspberry Pi 4, etc.)
Build on ARM64 Linux system or use emulation:
```bash
# Using QEMU emulation (advanced)
sudo apt install qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker run -it --platform linux/arm64 ubuntu:20.04
# Then follow normal build process inside container
```

### For ARM (Raspberry Pi 3, etc.)
Similar process but with `--platform linux/arm/v7`

## Troubleshooting

### Common Issues

1. **Missing shared libraries**:
   - Solution: Build on older/compatible Linux version
   - Or use static linking options

2. **Permission denied**:
   ```bash
   chmod +x StreamerViewer
   ```

3. **PyInstaller not found**:
   ```bash
   pip install --upgrade pyinstaller
   ```

4. **Build fails with import errors**:
   - Check requirements.txt has all dependencies
   - Add missing modules to hidden imports in spec file

### Debug Mode
To create executable with debug console:
```bash
pyinstaller --onefile --console --name StreamerViewer main.py
```

## GitHub Actions CI/CD

For automated builds, see `.github/workflows/` in the project root for Linux build automation.