extends Node
## INI Parser for Command & Conquer Generals format
##
## Parses INI files in the SAGE engine format:
## - Blocks: Type Name ... END
## - Key-Value pairs: Key = Value
## - Comments: ; comment
## - Supports inheritance via ObjectReskin

class_name INIParser

signal parse_completed(blocks: Dictionary)
signal parse_error(message: String, line_number: int)

# Block types we recognize
enum BlockType {
	OBJECT,
	OBJECT_RESKIN,
	WEAPON,
	ARMOR,
	LOCOMOTOR,
	UPGRADE,
	SPECIAL_POWER,
	COMMAND_BUTTON,
	COMMAND_SET,
	PARTICLE_SYSTEM,
	FX_LIST,
	GAME_DATA,
	PLAYER_TEMPLATE,
	SCIENCE,
	RANK,
	UNKNOWN
}

const BLOCK_TYPE_MAP := {
	"object": BlockType.OBJECT,
	"objectreskin": BlockType.OBJECT_RESKIN,
	"weapon": BlockType.WEAPON,
	"armor": BlockType.ARMOR,
	"locomotor": BlockType.LOCOMOTOR,
	"upgrade": BlockType.UPGRADE,
	"specialpower": BlockType.SPECIAL_POWER,
	"commandbutton": BlockType.COMMAND_BUTTON,
	"commandset": BlockType.COMMAND_SET,
	"particlesystem": BlockType.PARTICLE_SYSTEM,
	"fxlist": BlockType.FX_LIST,
	"gamedata": BlockType.GAME_DATA,
	"playertemplate": BlockType.PLAYER_TEMPLATE,
	"science": BlockType.SCIENCE,
	"rank": BlockType.RANK,
}

# Parsed data storage
var _blocks: Dictionary = {}  # type -> { name -> INIBlock }
var _current_line: int = 0


## Represents a parsed INI block
class INIBlock:
	var block_type: BlockType = BlockType.UNKNOWN
	var block_type_name: String = ""
	var name: String = ""
	var parent_name: String = ""  # For ObjectReskin inheritance
	var properties: Dictionary = {}  # key -> value (can be various types)
	var modules: Array[Dictionary] = []  # For Behavior, Draw, etc.
	var source_file: String = ""
	var source_line: int = 0

	func _to_string() -> String:
		return "[INIBlock %s '%s' with %d properties]" % [block_type_name, name, properties.size()]

	func get_string(key: String, default: String = "") -> String:
		return properties.get(key, default)

	func get_int(key: String, default: int = 0) -> int:
		var val = properties.get(key, default)
		if val is String:
			return int(val)
		return val

	func get_float(key: String, default: float = 0.0) -> float:
		var val = properties.get(key, default)
		if val is String:
			return float(val)
		return val

	func get_bool(key: String, default: bool = false) -> bool:
		var val = properties.get(key, default)
		if val is String:
			return val.to_lower() in ["yes", "true", "1"]
		return val

	func get_array(key: String, default: Array = []) -> Array:
		var val = properties.get(key, default)
		if val is Array:
			return val
		if val is String:
			return val.split(" ", false)
		return default

	func get_color(key: String, default: Color = Color.WHITE) -> Color:
		var val = properties.get(key, {})
		if val is Dictionary and val.has("r"):
			return Color(
				val.get("r", 255) / 255.0,
				val.get("g", 255) / 255.0,
				val.get("b", 255) / 255.0,
				val.get("a", 255) / 255.0
			)
		return default


## Parse an INI file from path
func parse_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("INIParser: Cannot open file: %s" % path)
		parse_error.emit("Cannot open file: %s" % path, 0)
		return {}

	var content = file.get_as_text()
	file.close()

	return parse_string(content, path)


## Parse INI content from string
func parse_string(content: String, source_file: String = "<string>") -> Dictionary:
	_blocks.clear()
	_current_line = 0

	var lines = content.split("\n")
	var i = 0

	while i < lines.size():
		_current_line = i + 1
		var line = _strip_comment(lines[i]).strip_edges()

		if line.is_empty():
			i += 1
			continue

		# Check for block start
		var block_info = _parse_block_header(line)
		if block_info:
			var block = INIBlock.new()
			block.block_type = block_info.type
			block.block_type_name = block_info.type_name
			block.name = block_info.name
			block.parent_name = block_info.parent
			block.source_file = source_file
			block.source_line = _current_line

			# Parse block contents
			i = _parse_block_body(lines, i + 1, block)

			# Store the block
			_store_block(block)
		else:
			# Unknown line outside of block - skip or log warning
			if not line.begins_with(";"):
				push_warning("INIParser: Unexpected line %d: %s" % [_current_line, line])
			i += 1

	parse_completed.emit(_blocks)
	return _blocks


## Strip comments from a line
func _strip_comment(line: String) -> String:
	var comment_pos = line.find(";")
	if comment_pos >= 0:
		# Check if ; is inside quotes
		var quote_count = 0
		for j in range(comment_pos):
			if line[j] == '"':
				quote_count += 1
		if quote_count % 2 == 0:  # Not inside quotes
			return line.substr(0, comment_pos)
	return line


## Parse a block header line, returns null if not a block header
func _parse_block_header(line: String) -> Variant:
	var tokens = _tokenize(line)
	if tokens.is_empty():
		return null

	var type_name = tokens[0].to_lower()

	if type_name not in BLOCK_TYPE_MAP:
		return null

	var result = {
		"type": BLOCK_TYPE_MAP[type_name],
		"type_name": tokens[0],
		"name": "",
		"parent": ""
	}

	# ObjectReskin has: ObjectReskin NewName ParentName
	if type_name == "objectreskin" and tokens.size() >= 3:
		result.name = tokens[1]
		result.parent = tokens[2]
	elif tokens.size() >= 2:
		result.name = tokens[1]

	return result


## Parse the body of a block until END
func _parse_block_body(lines: PackedStringArray, start_index: int, block: INIBlock) -> int:
	var i = start_index

	while i < lines.size():
		_current_line = i + 1
		var line = _strip_comment(lines[i]).strip_edges()

		if line.is_empty():
			i += 1
			continue

		# Check for END
		if line.to_upper() == "END":
			return i + 1

		# Parse property
		var prop = _parse_property(line)
		if prop:
			# Handle special module properties
			if prop.key.to_lower() in ["behavior", "draw", "body", "clientupdate", "locomotor"]:
				var module = {
					"type": prop.key,
					"value": prop.value
				}
				# Check for ModuleTag
				if prop.value is String and "moduletag" in prop.value.to_lower():
					var parts = prop.value.split(" ", false)
					module.value = parts[0] if parts.size() > 0 else prop.value
					for j in range(1, parts.size()):
						if parts[j].to_lower().begins_with("moduletag"):
							var tag_parts = parts[j].split("=")
							if tag_parts.size() >= 2:
								module["tag"] = tag_parts[1]
				block.modules.append(module)
			else:
				block.properties[prop.key] = prop.value

		i += 1

	push_warning("INIParser: Block '%s' missing END at line %d" % [block.name, start_index])
	return i


## Parse a property line: Key = Value
func _parse_property(line: String) -> Variant:
	var eq_pos = line.find("=")

	if eq_pos < 0:
		# Could be a flag without value
		var tokens = _tokenize(line)
		if tokens.size() == 1:
			return {"key": tokens[0], "value": true}
		return null

	var key = line.substr(0, eq_pos).strip_edges()
	var value_str = line.substr(eq_pos + 1).strip_edges()

	if key.is_empty():
		return null

	var value = _parse_value(value_str)

	return {"key": key, "value": value}


## Parse a value string into appropriate type
func _parse_value(value_str: String) -> Variant:
	if value_str.is_empty():
		return ""

	# Check for quoted string
	if value_str.begins_with('"') and value_str.ends_with('"'):
		return value_str.substr(1, value_str.length() - 2)

	# Check for RGB/RGBA color: R:255 G:128 B:64 or R:255 G:128 B:64 A:255
	if value_str.contains("R:") and value_str.contains("G:") and value_str.contains("B:"):
		return _parse_color(value_str)

	# Check for percentage: 25%
	if value_str.ends_with("%"):
		var num_str = value_str.substr(0, value_str.length() - 1)
		if num_str.is_valid_float():
			return float(num_str) / 100.0

	# Check for coordinate: X:100 Y:200 Z:50
	if value_str.contains("X:") and value_str.contains("Y:"):
		return _parse_coord(value_str)

	# Check for boolean
	var lower = value_str.to_lower()
	if lower == "yes" or lower == "true":
		return true
	if lower == "no" or lower == "false":
		return false

	# Check for number
	if value_str.is_valid_int():
		return int(value_str)
	if value_str.is_valid_float():
		return float(value_str)

	# Check for space-separated list (KindOf = UNIT INFANTRY GOOD_GUY)
	if " " in value_str and not value_str.begins_with('"'):
		return value_str.split(" ", false)

	# Default: string
	return value_str


## Parse RGB/RGBA color string
func _parse_color(value_str: String) -> Dictionary:
	var result = {"r": 255, "g": 255, "b": 255, "a": 255}

	var regex = RegEx.new()
	regex.compile("([RGBA]):\\s*(\\d+)")

	var matches = regex.search_all(value_str)
	for m in matches:
		var channel = m.get_string(1).to_lower()
		var val = int(m.get_string(2))
		result[channel] = val

	return result


## Parse coordinate string
func _parse_coord(value_str: String) -> Dictionary:
	var result = {"x": 0.0, "y": 0.0, "z": 0.0}

	var regex = RegEx.new()
	regex.compile("([XYZ]):\\s*([\\d.-]+)")

	var matches = regex.search_all(value_str)
	for m in matches:
		var axis = m.get_string(1).to_lower()
		var val = float(m.get_string(2))
		result[axis] = val

	return result


## Tokenize a line by whitespace
func _tokenize(line: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current = ""
	var in_quotes = false

	for c in line:
		if c == '"':
			in_quotes = not in_quotes
			current += c
		elif c in " \t\n\r=" and not in_quotes:
			if not current.is_empty():
				result.append(current)
				current = ""
		else:
			current += c

	if not current.is_empty():
		result.append(current)

	return result


## Store a parsed block
func _store_block(block: INIBlock) -> void:
	var type_key = block.block_type

	if type_key not in _blocks:
		_blocks[type_key] = {}

	if block.name in _blocks[type_key]:
		# Merge/override existing block
		var existing = _blocks[type_key][block.name] as INIBlock
		for key in block.properties:
			existing.properties[key] = block.properties[key]
		existing.modules.append_array(block.modules)
	else:
		_blocks[type_key][block.name] = block


## Get all blocks of a specific type
func get_blocks(type: BlockType) -> Dictionary:
	return _blocks.get(type, {})


## Get a specific block by type and name
func get_block(type: BlockType, name: String) -> INIBlock:
	var type_blocks = _blocks.get(type, {})
	return type_blocks.get(name, null)


## Get all parsed blocks
func get_all_blocks() -> Dictionary:
	return _blocks


## Clear all parsed data
func clear() -> void:
	_blocks.clear()
