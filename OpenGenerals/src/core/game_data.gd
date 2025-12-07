extends Node
## GameData - Central repository for all game data
##
## Autoloaded singleton that manages loading and accessing game data.
## Handles INI parsing, template storage, and inheritance resolution.

# Template storage
var thing_templates: Dictionary = {}  # id -> ThingTemplate
var weapon_templates: Dictionary = {}  # id -> WeaponTemplate
var armor_templates: Dictionary = {}  # id -> ArmorTemplate (TODO)
var locomotor_templates: Dictionary = {}  # id -> LocomotorTemplate (TODO)

# Parser instance
var _parser: INIParser

# Signals
signal data_loaded
signal loading_progress(current: int, total: int, message: String)


func _ready() -> void:
	_parser = INIParser.new()
	add_child(_parser)


## Load all game data from a directory
func load_data_directory(path: String) -> void:
	print("GameData: Loading data from %s" % path)

	var dir = DirAccess.open(path)
	if not dir:
		push_error("GameData: Cannot open directory: %s" % path)
		return

	var ini_files: Array[String] = []

	# Find all INI files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".ini"):
			ini_files.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	# Also check subdirectories
	dir.list_dir_begin()
	file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var subdir_path = path.path_join(file_name)
			_find_ini_files_recursive(subdir_path, ini_files)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("GameData: Found %d INI files" % ini_files.size())

	# Parse all files
	var total = ini_files.size()
	for i in range(total):
		loading_progress.emit(i + 1, total, "Parsing: %s" % ini_files[i].get_file())
		_parse_file(ini_files[i])

	# Resolve inheritance
	_resolve_inheritance()

	print("GameData: Loaded %d thing templates, %d weapon templates" % [
		thing_templates.size(),
		weapon_templates.size()
	])

	data_loaded.emit()


func _find_ini_files_recursive(path: String, result: Array[String]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_find_ini_files_recursive(full_path, result)
		elif file_name.ends_with(".ini"):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _parse_file(path: String) -> void:
	var blocks = _parser.parse_file(path)

	# Process Object blocks
	var objects = blocks.get(INIParser.BlockType.OBJECT, {})
	for obj_name in objects:
		var block = objects[obj_name] as INIParser.INIBlock
		var template = ThingTemplate.from_ini_block(block)
		thing_templates[template.id] = template

	# Process ObjectReskin blocks
	var reskins = blocks.get(INIParser.BlockType.OBJECT_RESKIN, {})
	for obj_name in reskins:
		var block = reskins[obj_name] as INIParser.INIBlock
		var template = ThingTemplate.from_ini_block(block)
		thing_templates[template.id] = template

	# Process Weapon blocks
	var weapons = blocks.get(INIParser.BlockType.WEAPON, {})
	for weapon_name in weapons:
		var block = weapons[weapon_name] as INIParser.INIBlock
		var template = WeaponTemplate.from_ini_block(block)
		weapon_templates[template.id] = template


func _resolve_inheritance() -> void:
	# Resolve ThingTemplate inheritance
	for template_id in thing_templates:
		var template = thing_templates[template_id] as ThingTemplate
		if not template.parent_template.is_empty():
			var parent = thing_templates.get(template.parent_template)
			if parent:
				template.apply_inheritance(parent)
			else:
				push_warning("GameData: Parent template '%s' not found for '%s'" % [
					template.parent_template, template_id
				])


## Load a single INI file
func load_ini_file(path: String) -> void:
	_parse_file(path)
	_resolve_inheritance()


## Load INI content from string
func load_ini_string(content: String, source_name: String = "<string>") -> void:
	var blocks = _parser.parse_string(content, source_name)

	var objects = blocks.get(INIParser.BlockType.OBJECT, {})
	for obj_name in objects:
		var block = objects[obj_name] as INIParser.INIBlock
		var template = ThingTemplate.from_ini_block(block)
		thing_templates[template.id] = template

	var weapons = blocks.get(INIParser.BlockType.WEAPON, {})
	for weapon_name in weapons:
		var block = weapons[weapon_name] as INIParser.INIBlock
		var template = WeaponTemplate.from_ini_block(block)
		weapon_templates[template.id] = template

	_resolve_inheritance()


## Get a thing template by ID
func get_thing_template(id: String) -> ThingTemplate:
	return thing_templates.get(id)


## Get a weapon template by ID
func get_weapon_template(id: String) -> WeaponTemplate:
	return weapon_templates.get(id)


## Get all thing templates matching a filter
func get_thing_templates_by_side(side: String) -> Array[ThingTemplate]:
	var result: Array[ThingTemplate] = []
	for template in thing_templates.values():
		if template.side.to_lower() == side.to_lower():
			result.append(template)
	return result


## Get all buildable thing templates
func get_buildable_templates() -> Array[ThingTemplate]:
	var result: Array[ThingTemplate] = []
	for template in thing_templates.values():
		if template.buildable and template.build_cost > 0:
			result.append(template)
	return result


## Get all thing templates with a specific KindOf flag
func get_templates_by_kind(kind: String) -> Array[ThingTemplate]:
	var result: Array[ThingTemplate] = []
	for template in thing_templates.values():
		if template.has_kind_of(kind):
			result.append(template)
	return result


## Print debug summary
func print_summary() -> void:
	print("=== GameData Summary ===")
	print("Thing Templates: %d" % thing_templates.size())
	print("Weapon Templates: %d" % weapon_templates.size())

	# Count by side
	var by_side: Dictionary = {}
	for template in thing_templates.values():
		var side = template.side if not template.side.is_empty() else "Unknown"
		by_side[side] = by_side.get(side, 0) + 1

	print("By Side:")
	for side in by_side:
		print("  %s: %d" % [side, by_side[side]])

	# Count by kind
	var infantry_count = get_templates_by_kind("INFANTRY").size()
	var vehicle_count = get_templates_by_kind("VEHICLE").size()
	var structure_count = get_templates_by_kind("STRUCTURE").size()

	print("By Kind:")
	print("  Infantry: %d" % infantry_count)
	print("  Vehicles: %d" % vehicle_count)
	print("  Structures: %d" % structure_count)
