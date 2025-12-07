# OpenGenerals

An open-source reimplementation of Command & Conquer Generals using Godot 4.

## Project Status

This is a proof-of-concept demonstrating:
- INI file parsing (matching original C&C Generals format)
- Data-driven game object definitions
- Basic 3D terrain and unit rendering

## Project Structure

```
OpenGenerals/
├── project.godot          # Godot project file
├── assets/
│   └── data/
│       └── ini/           # Game data INI files
│           ├── weapons.ini
│           ├── usa_infantry.ini
│           ├── usa_vehicles.ini
│           └── usa_structures.ini
└── src/
    ├── main.gd            # Main scene script
    ├── main.tscn          # Main scene
    ├── core/
    │   ├── game_data.gd   # Central data repository (autoload)
    │   ├── thing_template.gd  # Object definition template
    │   └── weapon_template.gd # Weapon definition template
    ├── parsers/
    │   └── ini_parser.gd  # INI file parser
    └── entities/
        └── unit.gd        # Runtime unit class
```

## Running the Project

1. Install Godot 4.2 or later
2. Open the project in Godot
3. Press F5 to run

### Controls

- **WASD** - Move camera
- **Mouse Wheel** - Zoom in/out
- **SPACE** - Spawn random unit

## INI Format

The game uses a data-driven approach with INI files matching the original C&C Generals format:

```ini
Object USARanger
    DisplayName = USA_RANGER
    Side = USA
    BuildCost = 225
    BuildTime = 5.0
    VisionRange = 200.0
    KindOf = INFANTRY SELECTABLE CAN_ATTACK
    ArmorSet = InfantryArmor
    WeaponSet = InfantryRifle
    ; ... more properties
END

Weapon InfantryRifle
    Damage = 8
    AttackRange = 150.0
    FireRate = 10.0
    ClipSize = 30
    ; ... more properties
END
```

## Next Steps

To continue development:

1. **Asset Pipeline** - Import W3D models from original game
2. **Terrain System** - Heightmap-based terrain with textures
3. **Unit AI** - Pathfinding and behavior trees
4. **Combat System** - Projectiles, damage types, armor
5. **Building System** - Construction, production queues
6. **UI** - Control bar, minimap, selection
7. **Networking** - Multiplayer support

## License

This project is for educational purposes. Original game assets are not included.
The original C&C Generals source code is licensed under GPL v3.
