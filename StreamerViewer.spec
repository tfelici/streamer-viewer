# -*- mode: python ; coding: utf-8 -*-
import sys

a = Analysis(
    ['main.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
        ('splash.png', '.'),
    ],
    hiddenimports=[
        'webview',
        'flask',
        'requests',
        'pymediainfo',
    ],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'scipy',
        'pandas',
    ],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data)

# Splash screen is only supported on Windows and Linux
splash = None
splash_binaries = []
if sys.platform in ['win32', 'linux']:
    splash = Splash(
        'splash.png',
        binaries=a.binaries,
        datas=a.datas,
        text_pos=(10, 300),
        text_size=14,
        text_color='white',
        minify_script=True,
        always_on_top=True,
    )
    splash_binaries = splash.binaries

# Build EXE with conditional splash screen support
exe_args = [
    pyz,
    a.scripts,
]

# Add splash components only if splash is supported
if splash is not None:
    exe_args.extend([splash, splash.binaries])

exe_args.extend([
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
])

exe = EXE(
    *exe_args,
    name='StreamerViewer',
    debug=False,
    strip=False,
    upx=False,
    console=False,
)

# Create macOS app bundle for proper Dock integration
if sys.platform == 'darwin':
    app = BUNDLE(
        exe,
        name='StreamerViewer.app',
        icon=None,  # Add icon path here if you have one: 'icon.icns'
        bundle_identifier='com.lambda-tek.streamer-viewer',
        info_plist={
            'CFBundleName': 'Streamer Viewer',
            'CFBundleDisplayName': 'Streamer Viewer',
            'CFBundleShortVersionString': '1.0.0',
            'CFBundleVersion': '1.0.0',
            'NSHighResolutionCapable': True,
            'LSUIElement': False,  # Show in Dock (enables bouncing)
        },
    )