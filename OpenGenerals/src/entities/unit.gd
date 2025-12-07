extends Node3D
## Unit - Runtime game unit instance
##
## Represents an active unit in the game world.
## Created from ThingTemplate definitions.

class_name Unit

# Template this unit is based on
var template: ThingTemplate

# Runtime state
var health: float = 100.0
var max_health: float = 100.0
var is_selected: bool = false
var veterancy_level: int = 0  # 0=Normal, 1=Veteran, 2=Elite, 3=Hero
var experience: float = 0.0

# Movement
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var move_speed: float = 10.0

# Combat
var current_target: Unit = null
var attack_cooldown: float = 0.0
var weapon_template: WeaponTemplate = null

# Visual components
var mesh_instance: MeshInstance3D
var selection_circle: MeshInstance3D
var health_bar: Node3D
var label: Label3D

# Signals
signal selected(unit: Unit)
signal deselected(unit: Unit)
signal died(unit: Unit)
signal damaged(unit: Unit, amount: float, source: Unit)
signal attack_started(unit: Unit, target: Unit)
signal moved(unit: Unit, new_position: Vector3)


## Initialize unit from template
func initialize(thing_template: ThingTemplate) -> void:
	template = thing_template
	name = template.id + "_" + str(get_instance_id())

	# Set initial stats
	max_health = 100.0  # TODO: Get from template/armor
	health = max_health

	# Create visual representation
	_create_visuals()

	# Get weapon if available
	if not template.weapon_set.is_empty():
		weapon_template = GameData.get_weapon_template(template.weapon_set)


func _create_visuals() -> void:
	# Create mesh based on geometry type
	var mesh: Mesh
	match template.geometry_type.to_upper():
		"BOX":
			var box = BoxMesh.new()
			box.size = Vector3(
				template.geometry_major_radius * 2,
				template.geometry_height,
				template.geometry_minor_radius * 2
			)
			mesh = box
		"SPHERE":
			var sphere = SphereMesh.new()
			sphere.radius = template.geometry_major_radius
			sphere.height = template.geometry_major_radius * 2
			mesh = sphere
		_:  # CYLINDER or default
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = template.geometry_major_radius
			cylinder.bottom_radius = template.geometry_major_radius
			cylinder.height = template.geometry_height
			mesh = cylinder

	# Create material with template color
	var material = StandardMaterial3D.new()
	material.albedo_color = template.display_color

	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position.y = template.geometry_height / 2
	add_child(mesh_instance)

	# Create selection circle (hidden by default)
	selection_circle = _create_selection_circle()
	selection_circle.visible = false
	add_child(selection_circle)

	# Create health bar
	health_bar = _create_health_bar()
	add_child(health_bar)

	# Create label
	label = Label3D.new()
	label.text = template.display_name if not template.display_name.is_empty() else template.id
	label.position.y = template.geometry_height + 3
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visible = false  # Show on selection
	add_child(label)


func _create_selection_circle() -> MeshInstance3D:
	var radius = template.get_collision_radius()
	var torus = TorusMesh.new()
	torus.inner_radius = radius - 0.3
	torus.outer_radius = radius + 0.3
	torus.rings = 32
	torus.ring_segments = 4

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 1.0, 0.2, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = torus
	mesh_inst.material_override = material
	mesh_inst.position.y = 0.1
	mesh_inst.rotation_degrees.x = 90

	return mesh_inst


func _create_health_bar() -> Node3D:
	var bar_container = Node3D.new()
	bar_container.position.y = template.geometry_height + 1

	# Background
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(template.get_collision_radius() * 2, 0.5, 0.1)

	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2)

	var bg_instance = MeshInstance3D.new()
	bg_instance.name = "Background"
	bg_instance.mesh = bg_mesh
	bg_instance.material_override = bg_material
	bar_container.add_child(bg_instance)

	# Health fill
	var fill_mesh = BoxMesh.new()
	fill_mesh.size = Vector3(template.get_collision_radius() * 2 - 0.1, 0.4, 0.15)

	var fill_material = StandardMaterial3D.new()
	fill_material.albedo_color = Color(0.2, 0.8, 0.2)

	var fill_instance = MeshInstance3D.new()
	fill_instance.name = "Fill"
	fill_instance.mesh = fill_mesh
	fill_instance.material_override = fill_material
	bar_container.add_child(fill_instance)

	# Billboard the health bar
	bar_container.set_meta("billboard", true)

	return bar_container


func _process(delta: float) -> void:
	_update_movement(delta)
	_update_combat(delta)
	_update_visuals()


func _update_movement(delta: float) -> void:
	if not is_moving:
		return

	var direction = (target_position - global_position)
	direction.y = 0  # Keep on ground

	if direction.length() < 1.0:
		is_moving = false
		moved.emit(self, global_position)
		return

	direction = direction.normalized()
	global_position += direction * move_speed * delta

	# Face movement direction
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _update_combat(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

	if current_target and is_instance_valid(current_target):
		if _can_attack_target(current_target):
			_perform_attack(current_target)
	else:
		current_target = null


func _update_visuals() -> void:
	# Update health bar
	if health_bar:
		var fill = health_bar.get_node_or_null("Fill")
		if fill:
			var health_percent = health / max_health
			fill.scale.x = health_percent

			# Color based on health
			var material = fill.material_override as StandardMaterial3D
			if material:
				if health_percent > 0.5:
					material.albedo_color = Color(0.2, 0.8, 0.2)
				elif health_percent > 0.25:
					material.albedo_color = Color(0.8, 0.8, 0.2)
				else:
					material.albedo_color = Color(0.8, 0.2, 0.2)


## Select this unit
func select() -> void:
	if is_selected:
		return

	is_selected = true
	if selection_circle:
		selection_circle.visible = true
	if label:
		label.visible = true

	selected.emit(self)


## Deselect this unit
func deselect() -> void:
	if not is_selected:
		return

	is_selected = false
	if selection_circle:
		selection_circle.visible = false
	if label:
		label.visible = false

	deselected.emit(self)


## Order unit to move to position
func move_to(pos: Vector3) -> void:
	target_position = pos
	target_position.y = 0  # Keep on ground
	is_moving = true


## Order unit to attack target
func attack(target: Unit) -> void:
	current_target = target


## Take damage
func take_damage(amount: float, source: Unit = null) -> void:
	health -= amount
	damaged.emit(self, amount, source)

	if health <= 0:
		health = 0
		_die()


func _die() -> void:
	died.emit(self)
	# TODO: Play death animation, spawn effects
	queue_free()


func _can_attack_target(target: Unit) -> bool:
	if not weapon_template:
		return false

	if attack_cooldown > 0:
		return false

	var distance = global_position.distance_to(target.global_position)
	if distance > weapon_template.attack_range:
		return false

	return true


func _perform_attack(target: Unit) -> void:
	if not weapon_template:
		return

	attack_started.emit(self, target)

	# Apply damage
	var damage = weapon_template.damage

	# Apply veterancy bonus
	match veterancy_level:
		1:
			damage *= weapon_template.damage_bonus_veteran
		2:
			damage *= weapon_template.damage_bonus_elite
		3:
			damage *= weapon_template.damage_bonus_hero

	target.take_damage(damage, self)

	# Set cooldown
	if weapon_template.fire_rate > 0:
		attack_cooldown = 1.0 / weapon_template.fire_rate
	else:
		attack_cooldown = 1.0


## Add experience and check for promotion
func add_experience(amount: float) -> void:
	if not template.is_trainable:
		return

	experience += amount

	# Check for promotion
	if veterancy_level < 3 and template.experience_required.size() > veterancy_level + 1:
		if experience >= template.experience_required[veterancy_level + 1]:
			_promote()


func _promote() -> void:
	veterancy_level += 1
	print("%s promoted to level %d!" % [template.id, veterancy_level])
	# TODO: Play promotion effect, update visuals


## Check if unit has a specific KindOf flag
func has_kind_of(flag: String) -> bool:
	return template.has_kind_of(flag)


## Get info string for UI
func get_info_string() -> String:
	var info = "%s\n" % template.display_name
	info += "HP: %d/%d\n" % [int(health), int(max_health)]
	if weapon_template:
		info += "Weapon: %s (DMG: %d)\n" % [weapon_template.id, int(weapon_template.damage)]
	info += "Veterancy: %d" % veterancy_level
	return info
