# Assets Directory

This directory contains all the game assets organized by type.

## Directory Structure

```
assets/
├── art/                   # Visual assets
│   ├── characters/        # Player and NPC sprites
│   ├── tilesets/          # Level tiles and tilesets
│   ├── ui/                # UI elements and icons
│   └── vfx/               # Visual effects and particles
├── audio/                 # Audio files
│   ├── music/             # Background music
│   └── sfx/               # Sound effects
├── fonts/                 # Font files
├── materials/             # Shader materials
└── scenes/                # Common scene assets
    ├── characters/        # Character scenes
    ├── items/             # Item scenes
    └── ui/                # UI scenes
```

## Asset Naming Conventions

- Use snake_case for all asset filenames (e.g., `player_idle.png`, `main_theme.ogg`)
- Prefix related assets with a common name (e.g., `player_walk_01.png`, `player_walk_02.png`)
- For spritesheets, use the format: `name_animation_XX.png` (e.g., `player_run_01.png`)
- For UI elements, prefix with the screen name (e.g., `main_menu_bg.png`, `inventory_icon.png`)

## Import Settings

- **Textures**: Use lossless compression for pixel art, lossy for photos
- **Audio**: Set appropriate compression based on quality needs
- **Scenes**: Keep scenes modular and focused on a single purpose

## Asset Sources

Track the source and license of all third-party assets here:

| Asset | Source | License | Notes |
|-------|--------|---------|-------|
| - | - | - | - |
