# Custom SDDM Login Theme with Random Wallpapers

This custom SDDM theme provides:

## Features
- 🎨 Random wallpaper selection from `/usr/share/wallpapers`
- 🌊 Blur effect on background wallpapers
- 🕐 Live clock and date display
- 👤 User avatar support
- ⌨️ Keyboard layout switching
- 🔄 Session selection
- ⚡ Power management options (suspend, reboot, shutdown)
- 🎯 Modern dark theme with Catppuccin-inspired colors

## Files Created
- `modules/sddm-theme.nix` - Main module configuration
- `modules/sddm-custom-theme/` - Theme directory containing:
  - `Main.qml` - Main theme interface
  - `metadata.desktop` - Theme metadata
  - `theme.conf` - Theme configuration
  - `components/` - Custom components directory

## Usage
The theme automatically:
1. Copies your wallpapers from `modules/assets/wallpapers/` to `/usr/share/wallpapers`
2. Randomly selects a wallpaper on each login screen load
3. Applies a multi-layered blur effect for better text readability
4. Sets up proper SDDM configuration

## Installation
The theme is automatically installed when you run:
```bash
sudo nixos-rebuild switch
```

## Testing
Run the test script to verify installation:
```bash
./test-sddm-theme.sh
```

## Customization
You can customize the theme by:
- Adding more wallpapers to `modules/assets/wallpapers/`
- Modifying colors in `Main.qml`
- Adjusting blur effects or layout
- Changing the theme configuration in `theme.conf`

## Colors Used (Catppuccin-inspired)
- Background: `#1e1e2e` (Base)
- Surfaces: `#313244` (Surface0)
- Elevated: `#45475a` (Surface1)
- Text: `#cdd6f4` (Text)
- Accent: `#89b4fa` (Blue)
- Subtext: `#6c7086` (Subtext0)
- Error: `#f38ba8` (Red)