extends Resource
## ThingTemplate - Base template for all game objects (units, buildings, etc.)
##
## Mirrors the original C&C Generals ThingTemplate structure.
## Loaded from INI Object definitions.

class_name ThingTemplate

# Identification
@export var id: String = ""
@export var display_name: String = ""
@export var side: String = ""  # USA, China, GLA, etc.
@export var editor_sorting: String = ""

# Economics
@export var build_cost: int = 0
@export var build_time: float = 0.0
@export var refund_value: int = 0
@export var energy_production: int = 0
@export var energy_bonus: int = 0

# Combat Stats
@export var armor_set: String = ""
@export var weapon_set: String = ""
@export var threat_value: int = 0
@export var crusher_level: int = 0
@export var crushable_level: int = 0

# Vision
@export var vision_range: float = 0.0
@export var shroud_clearing_range: float = 0.0

# Geometry
@export var geometry_type: String = "CYLINDER"  # BOX, CYLINDER, SPHERE
@export var geometry_major_radius: float = 10.0
@export var geometry_minor_radius: float = 10.0
@export var geometry_height: float = 10.0

# Display
@export var display_color: Color = Color.WHITE
@export var select_portrait: String = ""
@export var button_image: String = ""
@export var shadow_texture: String = ""
@export var shadow_size: Vector2 = Vector2.ZERO

# Flags (KindOf)
@export var kind_of: Array[String] = []

# Prerequisites
@export var prerequisites: Array[String] = []
@export var buildable: bool = true

# Experience/Veterancy
@export var is_trainable: bool = false
@export var experience_value: Array[int] = []
@export var experience_required: Array[int] = []

# Modules
@export var behavior_modules: Array[String] = []
@export var draw_modules: Array[String] = []
@export var body_modules: Array[String] = []

# Audio
@export var audio_voice_select: String = ""
@export var audio_voice_move: String = ""
@export var audio_voice_attack: String = ""
@export var audio_voice_enter: String = ""
@export var audio_sound_move_start: String = ""
@export var audio_sound_move_loop: String = ""
@export var audio_sound_ambient: String = ""
@export var audio_sound_die: String = ""

# Command
@export var command_set: String = ""

# Model/Visual
@export var model_name: String = ""

# Parent template (for inheritance)
@export var parent_template: String = ""

# Raw properties (for anything not explicitly defined)
var raw_properties: Dictionary = {}


## Create ThingTemplate from parsed INI block
static func from_ini_block(block: INIParser.INIBlock) -> ThingTemplate:
	var template = ThingTemplate.new()
	template.id = block.name
	template.parent_template = block.parent_name
	template.raw_properties = block.properties.duplicate()

	# Map properties
	template.display_name = block.get_string("DisplayName")
	template.side = block.get_string("Side")
	template.editor_sorting = block.get_string("EditorSorting")

	# Economics
	template.build_cost = block.get_int("BuildCost")
	template.build_time = block.get_float("BuildTime")
	template.refund_value = block.get_int("RefundValue", template.build_cost / 2)
	template.energy_production = block.get_int("EnergyProduction")
	template.energy_bonus = block.get_int("EnergyBonus")

	# Combat
	template.armor_set = block.get_string("ArmorSet")
	template.weapon_set = block.get_string("WeaponSet")
	template.threat_value = block.get_int("ThreatValue")
	template.crusher_level = block.get_int("CrusherLevel")
	template.crushable_level = block.get_int("CrushableLevel")

	# Vision
	template.vision_range = block.get_float("VisionRange")
	template.shroud_clearing_range = block.get_float("ShroudClearingRange", template.vision_range)

	# Geometry
	template.geometry_type = block.get_string("Geometry", "CYLINDER")
	template.geometry_major_radius = block.get_float("GeometryMajorRadius", 10.0)
	template.geometry_minor_radius = block.get_float("GeometryMinorRadius", 10.0)
	template.geometry_height = block.get_float("GeometryHeight", 10.0)

	# Display
	template.display_color = block.get_color("DisplayColor")
	template.select_portrait = block.get_string("SelectPortrait")
	template.button_image = block.get_string("ButtonImage")
	template.shadow_texture = block.get_string("ShadowTexture")
	var shadow_x = block.get_float("ShadowSizeX")
	var shadow_y = block.get_float("ShadowSizeY")
	template.shadow_size = Vector2(shadow_x, shadow_y)

	# KindOf flags
	var kind_of_val = block.properties.get("KindOf", [])
	if kind_of_val is Array:
		for k in kind_of_val:
			template.kind_of.append(str(k))
	elif kind_of_val is String:
		template.kind_of = Array(kind_of_val.split(" ", false), TYPE_STRING, "", null)

	# Prerequisites
	var prereq_val = block.properties.get("Prerequisites", [])
	if prereq_val is Array:
		for p in prereq_val:
			template.prerequisites.append(str(p))
	elif prereq_val is String:
		template.prerequisites = Array(prereq_val.split(" ", false), TYPE_STRING, "", null)

	template.buildable = block.get_bool("Buildable", true)

	# Veterancy
	template.is_trainable = block.get_bool("IsTrainable")

	# Experience (can be single value or array)
	var exp_val = block.properties.get("ExperienceValue", [])
	if exp_val is Array:
		for e in exp_val:
			template.experience_value.append(int(e))
	elif exp_val is int:
		template.experience_value.append(exp_val)

	var exp_req = block.properties.get("ExperienceRequired", [])
	if exp_req is Array:
		for e in exp_req:
			template.experience_required.append(int(e))
	elif exp_req is int:
		template.experience_required.append(exp_req)

	# Audio
	template.audio_voice_select = block.get_string("VoiceSelect")
	template.audio_voice_move = block.get_string("VoiceMove")
	template.audio_voice_attack = block.get_string("VoiceAttack")
	template.audio_voice_enter = block.get_string("VoiceEnter")
	template.audio_sound_move_start = block.get_string("SoundMoveStart")
	template.audio_sound_move_loop = block.get_string("SoundMoveLoop")
	template.audio_sound_ambient = block.get_string("SoundAmbient")
	template.audio_sound_die = block.get_string("SoundDie")

	# Command
	template.command_set = block.get_string("CommandSet")

	# Modules from block
	for module in block.modules:
		match module.type.to_lower():
			"behavior":
				template.behavior_modules.append(module.value)
			"draw":
				template.draw_modules.append(module.value)
			"body":
				template.body_modules.append(module.value)

	return template


## Check if this object has a specific KindOf flag
func has_kind_of(flag: String) -> bool:
	return flag.to_upper() in kind_of


## Check if this object is infantry
func is_infantry() -> bool:
	return has_kind_of("INFANTRY")


## Check if this object is a vehicle
func is_vehicle() -> bool:
	return has_kind_of("VEHICLE")


## Check if this object is a building/structure
func is_structure() -> bool:
	return has_kind_of("STRUCTURE")


## Check if this object can be selected
func is_selectable() -> bool:
	return has_kind_of("SELECTABLE")


## Get collision shape based on geometry
func get_collision_radius() -> float:
	return max(geometry_major_radius, geometry_minor_radius)


## Apply inheritance from parent template
func apply_inheritance(parent: ThingTemplate) -> void:
	if not parent:
		return

	# Only apply values that weren't explicitly set
	if display_name.is_empty():
		display_name = parent.display_name
	if side.is_empty():
		side = parent.side
	if build_cost == 0:
		build_cost = parent.build_cost
	if build_time == 0.0:
		build_time = parent.build_time
	if armor_set.is_empty():
		armor_set = parent.armor_set
	if weapon_set.is_empty():
		weapon_set = parent.weapon_set
	if vision_range == 0.0:
		vision_range = parent.vision_range
	if kind_of.is_empty():
		kind_of = parent.kind_of.duplicate()
	if behavior_modules.is_empty():
		behavior_modules = parent.behavior_modules.duplicate()
	if draw_modules.is_empty():
		draw_modules = parent.draw_modules.duplicate()
	# ... add more as needed


func _to_string() -> String:
	return "[ThingTemplate '%s' (%s) cost=%d]" % [id, side, build_cost]
