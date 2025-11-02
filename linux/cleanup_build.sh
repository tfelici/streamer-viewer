#!/bin/bash
# Cleanup script for temporary build directories
# Usage: bash cleanup_build.sh

echo "🧹 Cleaning up temporary build directories..."

# Change to project directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Find and remove temporary venv directories
for dir in venv_build_*; do
    if [ -d "$dir" ]; then
        echo "🗑️ Removing temporary directory: $dir"
        
        # Try different removal methods
        if rm -rf "$dir" 2>/dev/null; then
            echo "✅ Removed $dir successfully"
        elif sudo chmod -R 755 "$dir" 2>/dev/null && rm -rf "$dir" 2>/dev/null; then
            echo "✅ Removed $dir after chmod"
        elif sudo rm -rf "$dir" 2>/dev/null; then
            echo "✅ Removed $dir with sudo"
        else
            echo "⚠️  Could not remove $dir - you may need to remove it manually from Windows"
            echo "💡 Try: Remove-Item -Recurse -Force '$PWD/$dir' from PowerShell as Administrator"
        fi
    fi
done

# Clean up other build artifacts
echo "🧹 Cleaning up other build artifacts..."
rm -rf build/ __pycache__/ *.spec 2>/dev/null

echo "✅ Cleanup complete!"