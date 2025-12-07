extends Resource
## WeaponTemplate - Template for weapon definitions
##
## Mirrors the original C&C Generals Weapon structure.
## Loaded from INI Weapon definitions.

class_name WeaponTemplate

# Identification
@export var id: String = ""

# Damage
@export var damage: float = 0.0
@export var damage_type: String = ""  # SMALL_ARMS, EXPLOSIVE, FIRE, etc.
@export var damage_radius: float = 0.0  # For AOE weapons

# Range
@export var attack_range: float = 0.0
@export var minimum_attack_range: float = 0.0

# Fire Rate
@export var fire_rate: float = 1.0  # Shots per second
@export var pre_attack_delay: float = 0.0
@export var pre_attack_type: String = ""

# Clip/Ammo
@export var clip_size: int = 0  # 0 = unlimited
@export var clip_reload_time: float = 0.0
@export var auto_reload_when_idle: bool = true

# Projectile
@export var projectile_name: String = ""
@export var projectile_speed: float = 0.0

# Targeting
@export var can_target_infantry: bool = true
@export var can_target_vehicles: bool = true
@export var can_target_structures: bool = true
@export var can_target_air: bool = false
@export var can_fire_while_moving: bool = false

# Visual/Audio
@export var fire_fx: String = ""
@export var fire_sound: String = ""
@export var reload_sound: String = ""

# Bonuses
@export var damage_bonus_veteran: float = 1.0
@export var damage_bonus_elite: float = 1.0
@export var damage_bonus_hero: float = 1.0
@export var range_bonus_veteran: float = 1.0
@export var range_bonus_elite: float = 1.0

# Raw properties
var raw_properties: Dictionary = {}


## Create WeaponTemplate from parsed INI block
static func from_ini_block(block: INIParser.INIBlock) -> WeaponTemplate:
	var weapon = WeaponTemplate.new()
	weapon.id = block.name
	weapon.raw_properties = block.properties.duplicate()

	# Damage
	weapon.damage = block.get_float("Damage")
	weapon.damage_type = block.get_string("DamageType")
	weapon.damage_radius = block.get_float("DamageRadius")

	# Range
	weapon.attack_range = block.get_float("AttackRange", block.get_float("Range"))
	weapon.minimum_attack_range = block.get_float("MinimumAttackRange")

	# Fire Rate
	weapon.fire_rate = block.get_float("FireRate", block.get_float("DelayBetweenShots", 1.0))
	weapon.pre_attack_delay = block.get_float("PreAttackDelay")
	weapon.pre_attack_type = block.get_string("PreAttackType")

	# Clip
	weapon.clip_size = block.get_int("ClipSize", block.get_int("Clip"))
	weapon.clip_reload_time = block.get_float("ClipReloadTime")
	weapon.auto_reload_when_idle = block.get_bool("AutoReloadWhenIdle", true)

	# Projectile
	weapon.projectile_name = block.get_string("ProjectileObject", block.get_string("ProjectileName"))
	weapon.projectile_speed = block.get_float("ProjectileSpeed")

	# Targeting - handle various naming conventions
	weapon.can_target_infantry = block.get_bool("AntiInfantry", block.get_bool("CanTargetInfantry", true))
	weapon.can_target_vehicles = block.get_bool("AntiVehicle", block.get_bool("CanTargetVehicles", true))
	weapon.can_target_structures = block.get_bool("AntiStructure", block.get_bool("CanTargetStructures", true))
	weapon.can_target_air = block.get_bool("AntiAircraft", block.get_bool("CanTargetAir", false))
	weapon.can_fire_while_moving = block.get_bool("CanFireWhileMoving")

	# Effects
	weapon.fire_fx = block.get_string("FireFX")
	weapon.fire_sound = block.get_string("FireSound")
	weapon.reload_sound = block.get_string("ReloadSound")

	# Bonuses
	weapon.damage_bonus_veteran = block.get_float("DamageBonusVeteran", 1.0)
	weapon.damage_bonus_elite = block.get_float("DamageBonusElite", 1.0)
	weapon.damage_bonus_hero = block.get_float("DamageBonusHero", 1.0)
	weapon.range_bonus_veteran = block.get_float("RangeBonusVeteran", 1.0)
	weapon.range_bonus_elite = block.get_float("RangeBonusElite", 1.0)

	return weapon


## Get damage per second
func get_dps() -> float:
	if fire_rate <= 0:
		return 0.0
	return damage * fire_rate


## Get effective DPS accounting for reload
func get_effective_dps() -> float:
	if clip_size <= 0:
		return get_dps()

	var shots_time = clip_size / fire_rate
	var cycle_time = shots_time + clip_reload_time
	var total_damage = damage * clip_size

	return total_damage / cycle_time


## Check if weapon can target a specific kind
func can_target(kind_of: Array) -> bool:
	if "INFANTRY" in kind_of and not can_target_infantry:
		return false
	if "VEHICLE" in kind_of and not can_target_vehicles:
		return false
	if "STRUCTURE" in kind_of and not can_target_structures:
		return false
	if "AIRCRAFT" in kind_of and not can_target_air:
		return false
	return true


func _to_string() -> String:
	return "[WeaponTemplate '%s' damage=%d range=%d]" % [id, int(damage), int(attack_range)]
