# ==============================================================================
# Project: CraftDomain
# Description: Concrete Skeletal Visual Representation Strategy.
#              Loads, scales, offsets, and animates standard Mixamo FBX/GLB meshes.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                FBX scene loading, tangent warning suppression, and skeletal 
#                animation library runtime compilation.
#              - Open-Closed Principle (OCP): Fully generic. Any new character model 
#                (Zombie, Citizen, Knight) can be configured purely by instantiating 
#                this Strategy resource with custom paths on disk.
#              JUMP ANIMATION INTEGRATION:
#              - Added dynamic binding and loading support for the `jump` track.
#              - Configured the state blending priority tree to check for `is_on_floor` 
#                and play the `jump` animation cleanly with linear crossfades.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd
# ==============================================================================
class_name SkeletalVisualRepresentation
extends IEntityVisualRepresentation

# Configurable paths and calibration metrics
@export var base_model_path: String = ""
@export var scale_multiplier: Vector3 = Vector3.ONE
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(0, 180, 0)

# Physical collision parameters matched to the model height
@export var collision_size: Vector3 = Vector3(0.6, 1.8, 0.6)
@export var collision_position: Vector3 = Vector3(0.0, 0.9, 0.0)

# Configurable separate Mixamo animation files
@export var anim_idle_path: String = ""
@export var anim_walk_path: String = ""
@export var anim_attack_path: String = ""
@export var anim_panic_path: String = ""
@export var anim_jump_path: String = "" # <-- Added for jump animation track


# Internal state tracking
var _host: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer
var _is_lunging: bool = false


## Concrete Implementation: Instantiates the FBX, prunes nodes, and configures materials
func build_representation(host: CharacterBody3D, target_parent: Node3D) -> void:
	_host = host
	
	if not FileAccess.file_exists(base_model_path):
		push_error("[SkeletalVisualRepresentation ERROR] Base model not found: " + base_model_path)
		return
		
	var scene_resource := load(base_model_path) as PackedScene
	if scene_resource == null:
		return
		
	_model_node = scene_resource.instantiate() as Node3D
	_prune_extraneous_nodes(_model_node)
	
	# Apply calibrations
	_model_node.scale = scale_multiplier
	_model_node.position = position_offset
	_model_node.rotation_degrees = rotation_offset
	
	target_parent.add_child(_model_node)
	_register_glb_materials(_model_node)
	
	# Extract and wire skeletal anims
	_anim_player = _model_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(_anim_player):
		_load_external_fbx_animations()
		_anim_player.play("idle")


## Concrete Implementation: Drives the built-in blending state-machine in runtime
func animate_movement(velocity_flat: Vector2, is_on_floor: bool, delta: float) -> void:
	if not is_instance_valid(_anim_player) or not is_instance_valid(_host):
		return
		
	# Avoid unused parameter warning in the overridden contract
	var _d := delta
	
	var is_moving := velocity_flat.length_squared() > 0.1
	
	# Detect if the host is actively attacking (reading cooldown state if exposed)
	var is_attacking := false
	if "_attack_cooldown_timer" in _host:
		is_attacking = float(_host.get("_attack_cooldown_timer")) > 0.6
		
	# Detect if the host is actively panicking
	var is_panicking := false
	var ai_comp: NPCAIComponent = _host.get_node_or_null("NPCAIComponent") as NPCAIComponent
	if is_instance_valid(ai_comp):
		is_panicking = ai_comp.current_task == NPCAIComponent.TaskState.PANIC
		
	# ==========================================================================
	# STATE BLENDING PRIORITY TREE (With Jump support)
	# ==========================================================================
	if is_attacking:
		_play_animation_safe("attack", 1.0)
	elif not is_on_floor: # <-- High priority jump check when airborne
		if _anim_player.has_animation("jump"):
			_play_animation_safe("jump", 1.0)
		else:
			_play_animation_safe("idle", 1.0)
	elif is_panicking and is_moving:
		if _anim_player.has_animation("panic"):
			_play_animation_safe("panic", 1.0)
		else:
			# Fallback: Sprinting at 1.8x playback speed
			_play_animation_safe("walk", 1.8)
	elif is_moving and is_on_floor:
		_play_animation_safe("walk", 1.0)
	else:
		_play_animation_safe("idle", 1.0)


## Concrete Implementation: Trigger skeletal slash or procedural lunge fallback
func trigger_attack_visuals() -> void:
	if is_instance_valid(_anim_player) and _anim_player.has_animation("attack"):
		_play_animation_safe("attack", 1.0)
	else:
		# Trigger high-impact procedural lunge Tween!
		_execute_procedural_attack_lunge()


func get_collision_box_size() -> Vector3:
	return collision_size


func get_collision_box_position() -> Vector3:
	return collision_position


# ==============================================================================
# INTERNAL UTILITIES & SKELETAL RENDERING COMPILES
# ==============================================================================

## Prevents animation snapping by executing a 0.25s linear crossfade blend
func _play_animation_safe(anim_name: String, speed: float = 1.0) -> void:
	if not is_instance_valid(_anim_player):
		return
		
	var target_anim := anim_name
	
	# Fallback: If bite/attack is missing, play idle and lean forward procedurally!
	if target_anim == "attack" and not _anim_player.has_animation("attack"):
		target_anim = "idle"
		_execute_procedural_attack_lunge()
	elif target_anim == "jump" and not _anim_player.has_animation("jump"):
		target_anim = "idle"
		
	if _anim_player.has_animation(target_anim):
		_anim_player.speed_scale = speed
		if _anim_player.current_animation != target_anim:
			# Execute a 0.25s smooth crossfade blend to prevent bone snapping!
			_anim_player.play(target_anim, 0.25)


## Procedural Attack Lunge: Tilts and steps the model forward to represent a slash
func _execute_procedural_attack_lunge() -> void:
	if _is_lunging or not is_instance_valid(_model_node) or not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	_is_lunging = true
	
	var tween := _model_node.create_tween()
	# Step 1: Lean forward (Tilt X-rotation 20 degrees down)
	tween.tween_property(_model_node, "rotation_degrees:x", 20.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Step 2: Recover back to upright pose
	tween.chain().tween_property(_model_node, "rotation_degrees:x", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.chain().tween_callback(func() -> void: _is_lunging = false)


## Programmatically extracts and compiles separate FBX/GLTF animation tracks
func _load_external_fbx_animations() -> void:
	var anim_library := _anim_player.get_animation_library("")
	if anim_library == null:
		anim_library = AnimationLibrary.new()
		_anim_player.add_animation_library("", anim_library)
		
	var anim_sources := {
		"idle": anim_idle_path,
		"walk": anim_walk_path,
		"attack": anim_attack_path,
		"panic": anim_panic_path,
		"jump": anim_jump_path # <-- Sourced dynamically from disc!
	}
	
	for anim_name: String in anim_sources.keys():
		var path: String = anim_sources[anim_name] as String
		if path != "" and FileAccess.file_exists(path):
			var anim_scene := load(path) as PackedScene
			if anim_scene != null:
				var temp_instance := anim_scene.instantiate()
				var temp_player := temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
				
				if is_instance_valid(temp_player) and temp_player.get_animation_list().size() > 0:
					var raw_name := temp_player.get_animation_list()[0]
					var animation_resource := temp_player.get_animation(raw_name)
					
					# Force loop mode on idle, walk, and panic tracks
					if anim_name == "idle" or anim_name == "walk" or anim_name == "panic":
						animation_resource.loop_mode = Animation.LOOP_LINEAR
					elif anim_name == "jump":
						animation_resource.loop_mode = Animation.LOOP_NONE # Jump doesn't loop
						
					anim_library.add_animation(anim_name, animation_resource)
					print("  [SkeletalVisual] Bound dynamic FBX animation: '", anim_name, "' from ", path)
					
				temp_instance.queue_free()


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0) as Material
			
		if mat is BaseMaterial3D:
			var new_mat := mat.duplicate() as BaseMaterial3D
			
			# TANGENT WARNING SHIELD
			new_mat.normal_enabled = false
			new_mat.anisotropy_enabled = false
			new_mat.clearcoat_enabled = false
			new_mat.heightmap_enabled = false
			
			node.material_override = new_mat
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Recursively locates and frees extraneous camera and light nodes
func _prune_extraneous_nodes(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if "Camera" in child.name or "Light" in child.name:
			child.free()
		else:
			_prune_extraneous_nodes(child)
