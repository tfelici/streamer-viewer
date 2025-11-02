# -*- mode: python ; coding: utf-8 -*-

import os
from pathlib import Path

# Get the project directory
project_dir = Path(__file__).parent

# Data files to include
datas = [
    (str(project_dir / 'templates'), 'templates'),
    (str(project_dir / 'static'), 'static'),
]

# Hidden imports that PyInstaller might miss
hiddenimports = [
    'pymediainfo',
    'requests',
    'requests_toolbelt',
    'werkzeug',
    'jinja2',
    'markupsafe',
    'itsdangerous',
    'click',
    'flask'
]

a = Analysis(
    ['main.py'],
    pathex=[str(project_dir)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'test',
        'unittest',
        'pydoc',
        'xml.dom.minidom',
        'xml.dom.pulldom',
        'xml.etree.cElementTree',
        'xml.etree.ElementTree',
        'xml.parsers.expat',
        'xml.sax',
        'xmlrpc',
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='StreamerViewer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)