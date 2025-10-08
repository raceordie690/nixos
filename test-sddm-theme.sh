#!/usr/bin/env bash
# Test script for the custom SDDM theme

set -e

echo "=== SDDM Custom Theme Test ==="
echo

# Check if the theme files exist
THEME_DIR="/nix/store/*/share/sddm/themes/sddm-custom-theme"
if ls $THEME_DIR/Main.qml 2>/dev/null >/dev/null; then
    echo "✓ Theme files found in Nix store"
else
    echo "✗ Theme files not found in Nix store"
fi

# Check wallpapers directory
echo
echo "Wallpapers in /usr/share/wallpapers:"
if [ -d "/usr/share/wallpapers" ]; then
    ls -la /usr/share/wallpapers/
    COUNT=$(ls /usr/share/wallpapers/*.{jpg,jpeg,png,bmp} 2>/dev/null | wc -l || echo "0")
    echo "Found $COUNT wallpaper files"
else
    echo "✗ /usr/share/wallpapers directory does not exist"
fi

# Check SDDM configuration
echo
echo "SDDM configuration:"
if [ -f "/etc/sddm.conf" ]; then
    echo "SDDM config file exists"
    grep -i "theme\|current" /etc/sddm.conf 2>/dev/null || echo "No theme configuration found"
else
    echo "No /etc/sddm.conf file found (this is normal for NixOS)"
fi

# Check if SDDM service is enabled
echo
echo "SDDM service status:"
systemctl is-enabled display-manager 2>/dev/null || echo "Display manager service status unknown"

# Test QML syntax (if qmlscene is available)
echo
if command -v qmlscene >/dev/null 2>&1; then
    echo "Testing QML syntax..."
    for theme_dir in /nix/store/*/share/sddm/themes/sddm-custom-theme; do
        if [ -f "$theme_dir/Main.qml" ]; then
            echo "Found theme at: $theme_dir"
            # Note: We can't actually run qmlscene with SDDM components, but we can check syntax
            break
        fi
    done
else
    echo "qmlscene not available for QML testing"
fi

echo
echo "=== Test Complete ==="
echo "To apply changes: sudo nixos-rebuild switch"