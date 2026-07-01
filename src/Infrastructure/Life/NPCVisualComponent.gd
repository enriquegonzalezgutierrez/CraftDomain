# ==============================================================================
# Project: CraftDomain
# Description: Presentation Component responsible for rendering voxel shapes, 
#              eye-blinking cycles, and high-fidelity walk bobbing animations.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates graphics and 
#                procedural cosmetic calculations from physical and behavioral AI.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/NPCVisualComponent.gd
# ==============================================================================
class_name NPCVisualComponent
extends Node

# Joint Nodes for sub-mesh groupings
var visual_root: Node3D
var body_bob_node: Node3D 
var head_node: Node3D
var arms_node: Node3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D

# Procedural variant colors calculated from coordinate seeds
var variant_skin_color: Color
var variant_clothing_color: Color
var variant_hair_color: Color
var variant_height_scale: float = 1.0

# Blinking cycle trackers
var _blink_timer: float = randf_range(2.5, 5.0)
var _blink_duration: float = 0.0
var _is_blinking: bool = false
var _animation_time: float = 0.0

# Sibling Component references
var _host: CharacterBody3D
var _ai_component: NPCAIComponent

# STATIC VISUAL CACHE: Shared high-frequency pixel grain textures (Prevents lag)
static var _shared_grain_texture: NoiseTexture2D = null


func _ready() -> void:
	name = "NPCVisualComponent"
	_host = get_parent() as CharacterBody3D
	_ai_component = get_node_or_null("../NPCAIComponent") as NPCAIComponent
	
	_generate_procedural_variant_palette()
	_preload_shared_grain_texture()
	_setup_joints()


func _setup_joints() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visuals"
	_host.add_child(visual_root)
	
	# Root-scaling based on the height variant
	visual_root.scale = Vector3(1.0, variant_height_scale, 1.0)
	
	body_bob_node = Node3D.new()
	body_bob_node.name = "BodyBobJoint"
	visual_root.add_child(body_bob_node)


func _process(delta: float) -> void:
	if not is_instance_valid(_host) or _host.get("domain_entity") == null or _host.domain_entity.is_dead:
		return
		
	_process_blinking_cycle(delta)
	_process_procedural_animations(delta)


## Generates a unique, stable color palette using the deterministic coordinate seed.
func _generate_procedural_variant_palette() -> void:
	var npc_seed: int = _host.get("npc_seed") if "npc_seed" in _host else 0
	var generator := RandomNumberGenerator.new()
	generator.seed = npc_seed
	
	# 1. Procedural Skin Tones
	var skins := [
		Color(0.95, 0.75, 0.65), # Peach
		Color(0.85, 0.65, 0.55), # Tanned
		Color(0.92, 0.70, 0.58), # Light olive
		Color(0.65, 0.45, 0.35)  # Brown
	]
	variant_skin_color = skins[generator.randi() % skins.size()]
	
	# 2. Procedural Clothing Tones
	var clothes := [
		Color(0.35, 0.22, 0.15), # Classic Brown
		Color(0.20, 0.32, 0.45), # Slate Blue
		Color(0.25, 0.45, 0.28), # Forest Green
		Color(0.50, 0.22, 0.20), # Crimson
		Color(0.42, 0.32, 0.48)  # Purple
	]
	variant_clothing_color = clothes[generator.randi() % clothes.size()]
	
	# 3. Procedural Hair Tones
	var hairs := [
		Color(0.18, 0.12, 0.08), # Dark Brown
		Color(0.08, 0.08, 0.08), # Charcoal Black
		Color(0.82, 0.68, 0.32), # Golden Blonde
		Color(0.72, 0.35, 0.12)  # Ginger Red
	]
	variant_hair_color = hairs[generator.randi() % hairs.size()]
	
	# 4. Height scaling variance
	variant_height_scale = generator.randf_range(0.92, 1.08)


## Compiles and caches a tiny, high-frequency simplex noise grain texture 
## once to establish unified voxel texturing without overhead.
func _preload_shared_grain_texture() -> void:
	if _shared_grain_texture != null:
		return
		
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.52
	noise.fractal_octaves = 1
	
	_shared_grain_texture = NoiseTexture2D.new()
	_shared_grain_texture.width = 32
	_shared_grain_texture.height = 32
	_shared_grain_texture.generate_mipmaps = false
	_shared_grain_texture.noise = noise


## Instantiates, styles, and textures a 3D box programmatically.
func create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic_specular = 0.0 
	
	if _shared_grain_texture != null:
		mat.albedo_texture = _shared_grain_texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Pixelated retro look
		mat.albedo_texture_force_srgb = true
		
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _process_blinking_cycle(delta: float) -> void:
	if not _is_blinking:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_is_blinking = true
			_blink_duration = 0.12 
			_set_eyes_vertical_scale(0.1) 
	else:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			_is_blinking = false
			_blink_timer = randf_range(2.5, 6.0)
			_set_eyes_vertical_scale(1.0) 


func _set_eyes_vertical_scale(y_scale: float) -> void:
	if is_instance_valid(left_eye):
		left_eye.scale.y = y_scale
	if is_instance_valid(right_eye):
		right_eye.scale.y = y_scale


## Procedural Animating Cycle (Decoupled from standard Physics Process)
func _process_procedural_animations(delta: float) -> void:
	_animation_time += delta
	
	var active_task: int = NPCAIComponent.TaskState.IDLE
	var wander_dir := Vector3.ZERO
	if is_instance_valid(_ai_component):
		active_task = _ai_component.current_task
		wander_dir = _ai_component.wander_direction
		
	var is_talking: bool = _host.get("is_talking") == true
	var is_moving: bool = (active_task == NPCAIComponent.TaskState.WANDERING or 
							active_task == NPCAIComponent.TaskState.PANIC or 
							active_task == NPCAIComponent.TaskState.WORKING)
	
	# A. Gaze Look Lock Rotation slerping
	if is_talking and is_instance_valid(_host.get("_talking_partner")):
		var partner: CharacterBody3D = _host.get("_talking_partner")
		var look_dir := (partner.global_position - _host.global_position).normalized()
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.01:
			var target_look := _host.global_position + look_dir
			visual_root.look_at(target_look, Vector3.UP)
			visual_root.rotation.x = 0
			visual_root.rotation.z = 0
	elif is_instance_valid(visual_root) and wander_dir.length_squared() > 0.05:
		var target_look := _host.global_position + wander_dir
		visual_root.look_at(target_look, Vector3.UP)
		visual_root.rotation.x = 0
		visual_root.rotation.z = 0
		
	# B. Body Bouncing Bobbing Calculations
	if is_instance_valid(body_bob_node):
		if is_moving and _host.is_on_floor() and not is_talking:
			var speed_mult := 18.0 if active_task == NPCAIComponent.TaskState.PANIC else (12.0 if _host.call("_is_avian") else 10.0)
			var bounce_height := 0.05 if _host.call("_is_avian") else 0.035
			body_bob_node.position.y = abs(sin(_animation_time * speed_mult)) * bounce_height
		else:
			body_bob_node.position.y = lerp(body_bob_node.position.y, sin(_animation_time * 2.0) * 0.015, delta * 5.0)
			
	# C. Specialized Joint Sways (Head & Arms)
	if active_task == NPCAIComponent.TaskState.GREETING or active_task == NPCAIComponent.TaskState.CHATTIING or is_talking:
		if is_instance_valid(head_node):
			head_node.rotation.x = sin(_animation_time * 6.0) * 0.15 # Node Nods head
			head_node.rotation.y = 0.0
		if is_instance_valid(arms_node):
			arms_node.rotation.x = 0.0
			arms_node.position.y = -0.21
			
	elif active_task == NPCAIComponent.TaskState.EXAMINING:
		if is_instance_valid(head_node):
			head_node.rotation.x = lerp(head_node.rotation.x, deg_to_rad(25), delta * 5.0)
			head_node.rotation.y = sin(_animation_time * 2.0) * 0.05
		if is_instance_valid(arms_node):
			arms_node.rotation.x = sin(_animation_time * 8.0) * 0.15
			arms_node.position.y = -0.21 + sin(_animation_time * 8.0) * 0.03
			
	elif is_moving:
		var speed_mult := 12.0 if active_task == NPCAIComponent.TaskState.PANIC else (8.0 if _host.call("_is_avian") else 5.0)
		var sway_amount := 0.2 if _host.call("_is_avian") else 0.08
		
		if is_instance_valid(head_node):
			head_node.rotation.x = sin(_animation_time * speed_mult) * sway_amount
			head_node.rotation.y = cos(_animation_time * (speed_mult * 0.5)) * 0.05
			
		if is_instance_valid(arms_node):
			arms_node.rotation.x = cos(_animation_time * speed_mult) * 0.1
			arms_node.position.y = -0.21 + sin(_animation_time * 10.0) * 0.02
			
	else: 
		if is_instance_valid(head_node):
			head_node.rotation.x = lerp(head_node.rotation.x, 0.0, delta * 5.0)
			head_node.rotation.y = lerp(head_node.rotation.y, 0.0, delta * 5.0)
		if is_instance_valid(arms_node):
			arms_node.rotation.x = lerp(arms_node.rotation.x, 0.0, delta * 5.0)
			arms_node.position.y = lerp(arms_node.position.y, -0.21, delta * 5.0)
