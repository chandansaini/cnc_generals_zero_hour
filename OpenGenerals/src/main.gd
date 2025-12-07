extends Node3D
## Main scene - Entry point for OpenGenerals
##
## Loads game data and sets up the initial game state.

@onready var camera: Camera3D = $Camera3D
@onready var terrain: Node3D = $Terrain
@onready var units_container: Node3D = $Units
@onready var ui: Control = $UI

# Camera control
var camera_speed: float = 20.0
var camera_zoom_speed: float = 2.0
var camera_min_height: float = 10.0
var camera_max_height: float = 100.0

# Unit spawning for demo
var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var spawned_units: Array = []


func _ready() -> void:
	print("OpenGenerals starting...")

	# Load game data
	_load_game_data()

	# Setup initial scene
	_setup_camera()
	_setup_lighting()
	_create_demo_terrain()

	print("Ready! Use WASD to move camera, scroll to zoom.")
	print("Press SPACE to spawn a random unit.")


func _load_game_data() -> void:
	print("Loading game data...")

	# Load INI files from assets directory
	var data_path = "res://assets/data/ini"

	# Check if directory exists
	var dir = DirAccess.open(data_path)
	if dir:
		GameData.load_data_directory(data_path)
		GameData.print_summary()
	else:
		# Try loading individual files for testing
		print("Data directory not found, loading sample data...")
		_load_sample_data()


func _load_sample_data() -> void:
	# Sample inline data for testing without external files
	var sample_ini = """
Object TestInfantry
    DisplayName = TEST_INFANTRY
    Side = USA
    BuildCost = 100
    BuildTime = 5.0
    VisionRange = 150.0
    Geometry = CYLINDER
    GeometryMajorRadius = 5.0
    GeometryHeight = 12.0
    KindOf = INFANTRY SELECTABLE CAN_ATTACK
    DisplayColor = R:100 G:150 B:255
END

Object TestTank
    DisplayName = TEST_TANK
    Side = USA
    BuildCost = 900
    BuildTime = 12.0
    VisionRange = 300.0
    Geometry = BOX
    GeometryMajorRadius = 15.0
    GeometryMinorRadius = 10.0
    GeometryHeight = 8.0
    KindOf = VEHICLE SELECTABLE CAN_ATTACK
    DisplayColor = R:50 G:100 B:200
END

Weapon TestWeapon
    Damage = 25
    AttackRange = 200.0
    FireRate = 2.0
END
"""
	GameData.load_ini_string(sample_ini, "sample_data")
	GameData.print_summary()


func _setup_camera() -> void:
	if not camera:
		camera = Camera3D.new()
		add_child(camera)

	camera.position = Vector3(0, 30, 30)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.current = true


func _setup_lighting() -> void:
	# Directional light (sun)
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(0, 50, 0)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# Ambient light
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.5, 0.6)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _create_demo_terrain() -> void:
	if not terrain:
		terrain = Node3D.new()
		terrain.name = "Terrain"
		add_child(terrain)

	# Create a simple plane for terrain
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(200, 200)
	plane_mesh.subdivide_width = 20
	plane_mesh.subdivide_depth = 20

	var terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.4, 0.55, 0.3)  # Grass green
	terrain_material.roughness = 0.9

	var terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = plane_mesh
	terrain_mesh.material_override = terrain_material
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.add_child(terrain_mesh)

	# Add a grid for reference
	_create_reference_grid()


func _create_reference_grid() -> void:
	var grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.3, 0.3, 0.3, 0.5)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create grid lines
	var grid = Node3D.new()
	grid.name = "Grid"

	var grid_size = 100
	var grid_step = 10

	for i in range(-grid_size, grid_size + 1, grid_step):
		# X-axis lines
		var line_x = _create_line(Vector3(i, 0.01, -grid_size), Vector3(i, 0.01, grid_size))
		grid.add_child(line_x)

		# Z-axis lines
		var line_z = _create_line(Vector3(-grid_size, 0.01, i), Vector3(grid_size, 0.01, i))
		grid.add_child(line_z)

	terrain.add_child(grid)


func _create_line(from: Vector3, to: Vector3) -> MeshInstance3D:
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = immediate_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	return mesh_instance


func _process(delta: float) -> void:
	_handle_camera_input(delta)
	_handle_spawn_input()


func _handle_camera_input(delta: float) -> void:
	var move_dir = Vector3.ZERO

	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_dir.x += 1

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		# Rotate movement relative to camera's Y rotation
		var cam_basis = Basis(Vector3.UP, camera.rotation.y)
		move_dir = cam_basis * move_dir
		camera.position += move_dir * camera_speed * delta


func _input(event: InputEvent) -> void:
	# Camera zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y = max(camera_min_height, camera.position.y - camera_zoom_speed)
			camera.position.z = max(camera_min_height, camera.position.z - camera_zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y = min(camera_max_height, camera.position.y + camera_zoom_speed)
			camera.position.z = min(camera_max_height, camera.position.z + camera_zoom_speed)


func _handle_spawn_input() -> void:
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		_spawn_random_unit()


func _spawn_random_unit() -> void:
	# Get all thing templates
	var templates = GameData.thing_templates.values()
	if templates.is_empty():
		print("No templates loaded!")
		return

	# Pick a random template
	var template = templates[randi() % templates.size()] as ThingTemplate

	# Create visual representation
	var unit = _create_unit_visual(template)

	# Random position
	var pos = Vector3(
		randf_range(-50, 50),
		0,
		randf_range(-50, 50)
	)
	unit.position = pos

	if not units_container:
		units_container = Node3D.new()
		units_container.name = "Units"
		add_child(units_container)

	units_container.add_child(unit)
	spawned_units.append(unit)

	print("Spawned: %s at %s" % [template.id, pos])


func _create_unit_visual(template: ThingTemplate) -> Node3D:
	var unit = Node3D.new()
	unit.name = template.id

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
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position.y = template.geometry_height / 2  # Offset to sit on ground

	unit.add_child(mesh_instance)

	# Add selection circle
	var selection_circle = _create_selection_circle(template.get_collision_radius())
	unit.add_child(selection_circle)

	# Add label
	var label = Label3D.new()
	label.text = template.id
	label.position.y = template.geometry_height + 2
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	unit.add_child(label)

	return unit


func _create_selection_circle(radius: float) -> MeshInstance3D:
	var torus = TorusMesh.new()
	torus.inner_radius = radius - 0.5
	torus.outer_radius = radius + 0.5
	torus.rings = 32
	torus.ring_segments = 4

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 1.0, 0.2, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = torus
	mesh_instance.material_override = material
	mesh_instance.position.y = 0.1
	mesh_instance.rotation_degrees.x = 90

	return mesh_instance
