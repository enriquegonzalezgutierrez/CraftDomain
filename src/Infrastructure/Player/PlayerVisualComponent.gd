# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Presentation Component managing the 3D player model.
#              Provides third-person character representation, organic walk cycles,
#              eye blinking, and dynamic high-fidelity voxel tool attachment.
#              MULTIPLAYER PREPARATION:
#              - Supports an 'is_local_player' toggle. Local player meshes are set 
#                to SHADOWS_ONLY to prevent camera clipping while retaining 
#                beautiful ground shadows. Other players (clients) render normally.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates third-person 
#                character geometry and animation loops from movement physics.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/PlayerVisualComponent.gd
# ==============================================================================
class_name PlayerVisualComponent
extends Node3D

## Configuration: Set to true for the local client, false for multiplayer replicas.
@export var is_local_player: bool = true

# Joints for skeleton-like articulation
var visual_root: Node3D
var body_bob_node: Node3D
var head_node: Node3D
var left_arm_joint: Node3D
var right_arm_joint: Node3D
var left_leg_joint: Node3D
var right_leg_joint: Node3D

# Eye meshes for blinking cycle
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D

# Held tool joint attached to the Right Hand
var held_tool_joint: Node3D

# Internal animation state
var _animation_time: float = 0.0
var _blink_timer: float = randf_range(2.0, 5.0)
var _blink_duration: float = 0.0
var _is_blinking: bool = false

# Cached shared micro-grain noise texture
static var _shared_grain_texture: NoiseTexture2D


func _ready() -> void:
	name = "PlayerVisualComponent"
	_preload_shared_grain_texture()
	_setup_skeleton_joints()
	_build_player_model()
	_update_cull_modes()


func _preload_shared_grain_texture() -> void:
	if _shared_grain_texture != null:
		return
		
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.52
	
	_shared_grain_texture = NoiseTexture2D.new()
	_shared_grain_texture.width = 32
	_shared_grain_texture.height = 32
	_shared_grain_texture.generate_mipmaps = false
	_shared_grain_texture.noise = noise


func _setup_skeleton_joints() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	
	body_bob_node = Node3D.new()
	body_bob_node.name = "BodyBobJoint"
	visual_root.add_child(body_bob_node)
	
	# Head Joint
	head_node = Node3D.new()
	head_node.name = "HeadJoint"
	head_node.position = Vector3(0.0, 1.45, 0.0)
	body_bob_node.add_child(head_node)
	
	# Left Arm Joint (Pivot at shoulder height)
	left_arm_joint = Node3D.new()
	left_arm_joint.name = "LeftArmJoint"
	left_arm_joint.position = Vector3(-0.32, 1.30, 0.0)
	body_bob_node.add_child(left_arm_joint)
	
	# Right Arm Joint (Pivot at shoulder height)
	right_arm_joint = Node3D.new()
	right_arm_joint.name = "RightArmJoint"
	right_arm_joint.position = Vector3(0.32, 1.30, 0.0)
	body_bob_node.add_child(right_arm_joint)
	
	# Held Tool Joint (Attached to the bottom tip of the Right Arm)
	held_tool_joint = Node3D.new()
	held_tool_joint.name = "HeldToolJoint"
	held_tool_joint.position = Vector3(0.0, -0.45, -0.1)
	held_tool_joint.rotation = Vector3(deg_to_rad(-15), deg_to_rad(15), deg_to_rad(-45))
	right_arm_joint.add_child(held_tool_joint)
	
	# Left Leg Joint (Pivot at hip height)
	left_leg_joint = Node3D.new()
	left_leg_joint.name = "LeftLegJoint"
	left_leg_joint.position = Vector3(-0.14, 0.70, 0.0)
	body_bob_node.add_child(left_leg_joint)
	
	# Right Leg Joint (Pivot at hip height)
	right_leg_joint = Node3D.new()
	right_leg_joint.name = "RightLegJoint"
	right_leg_joint.position = Vector3(0.14, 0.70, 0.0)
	body_bob_node.add_child(right_leg_joint)


func _build_player_model() -> void:
	var skin := Color(0.95, 0.75, 0.65)         # Peach clay skin
	var hair := Color(0.18, 0.12, 0.08)         # Dark brown hair
	var shirt := Color(0.15, 0.55, 0.82)        # Blue flannel shirt
	var trousers := Color(0.20, 0.22, 0.26)     # Dark slate trousers
	var boots := Color(0.12, 0.10, 0.08)        # Sturdy leather boots
	
	# 1. Torso Chest Armor Block
	_create_box(body_bob_node, Vector3(0.44, 0.75, 0.32), Vector3(0, 1.075, 0), shirt)
	
	# 2. Left & Right Arm Sleeves
	_create_box(left_arm_joint, Vector3(0.16, 0.55, 0.18), Vector3(0.0, -0.225, 0.0), shirt) # Left Arm
	_create_box(left_arm_joint, Vector3(0.14, 0.12, 0.16), Vector3(0.0, -0.51, 0.0), skin)   # Left Hand
	
	_create_box(right_arm_joint, Vector3(0.16, 0.55, 0.18), Vector3(0.0, -0.225, 0.0), shirt) # Right Arm
	_create_box(right_arm_joint, Vector3(0.14, 0.12, 0.16), Vector3(0.0, -0.51, 0.0), skin)   # Right Hand
	
	# 3. Left & Right Segmented Legs
	_create_box(left_leg_joint, Vector3(0.16, 0.55, 0.18), Vector3(0.0, -0.225, 0.0), trousers) # Left Leg
	_create_box(left_leg_joint, Vector3(0.18, 0.12, 0.22), Vector3(0.0, -0.54, -0.02), boots)    # Left Boot
	
	_create_box(right_leg_joint, Vector3(0.16, 0.55, 0.18), Vector3(0.0, -0.225, 0.0), trousers) # Right Leg
	_create_box(right_leg_joint, Vector3(0.18, 0.12, 0.22), Vector3(0.0, -0.54, -0.02), boots)   # Right Boot
	
	# 4. Head Dome & Face Features
	_create_box(head_node, Vector3(0.36, 0.38, 0.36), Vector3(0.0, 0.19, 0.0), skin) # Face core
	_create_box(head_node, Vector3(0.38, 0.14, 0.38), Vector3(0.0, 0.32, 0.01), hair) # Hair top cap
	_create_box(head_node, Vector3(0.38, 0.24, 0.10), Vector3(0.0, 0.16, 0.15), hair) # Hair back plates
	_create_box(head_node, Vector3(0.08, 0.15, 0.08), Vector3(0.0, 0.12, -0.21), skin * 0.9) # Nose
	
	# Blinking Eyes (Cyan pupils)
	left_eye = _create_box(head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.09, 0.18, -0.19), Color.WHITE)
	_create_box(left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))
	
	right_eye = _create_box(head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.09, 0.18, -0.19), Color.WHITE)
	_create_box(right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.18, 0.42, 0.68))


## Sets shadows/culling based on whether this visual belongs to the local player.
func _update_cull_modes() -> void:
	if is_local_player:
		# Hide the mesh to prevent blocking camera, but retain shadow casting!
		_set_cast_shadow_recursive(visual_root, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	else:
		# Render normally for other players in multiplayer
		_set_cast_shadow_recursive(visual_root, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func _set_cast_shadow_recursive(node: Node, setting: GeometryInstance3D.ShadowCastingSetting) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = setting
	for child in node.get_children():
		_set_cast_shadow_recursive(child, setting)


## Animates the walk cycle joints and body bobbing based on current velocity.
func animate_movement(velocity_flat: Vector2, is_on_floor: bool, delta: float) -> void:
	_animation_time += delta
	_process_blinking_cycle(delta)
	
	var speed := velocity_flat.length()
	var is_moving := speed > 0.1 and is_on_floor
	
	if is_moving:
		# 1. Bobbing Height Oscillations
		var bob_mult := 12.0
		body_bob_node.position.y = abs(sin(_animation_time * bob_mult)) * 0.04
		
		# 2. Pendulum-like arm and leg swinging (Out-of-phase matching)
		var swing_angle := sin(_animation_time * bob_mult) * 0.45
		
		left_arm_joint.rotation.x = -swing_angle
		right_arm_joint.rotation.x = swing_angle
		
		left_leg_joint.rotation.x = swing_angle
		right_leg_joint.rotation.x = -swing_angle
		
		# Lateral swaying
		visual_root.rotation.z = sin(_animation_time * bob_mult * 0.5) * 0.02
	else:
		# Smoothly interpolate back to default resting pose
		body_bob_node.position.y = lerp(body_bob_node.position.y, sin(_animation_time * 2.0) * 0.012, delta * 5.0)
		visual_root.rotation.z = lerp(visual_root.rotation.z, 0.0, delta * 5.0)
		
		left_arm_joint.rotation.x = lerp(left_arm_joint.rotation.x, 0.0, delta * 6.0)
		right_arm_joint.rotation.x = lerp(right_arm_joint.rotation.x, 0.0, delta * 6.0)
		left_leg_joint.rotation.x = lerp(left_leg_joint.rotation.x, 0.0, delta * 6.0)
		right_leg_joint.rotation.x = lerp(right_leg_joint.rotation.x, 0.0, delta * 6.0)


func _process_blinking_cycle(delta: float) -> void:
	if not _is_blinking:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_is_blinking = true
			_blink_duration = 0.12
			if is_instance_valid(left_eye): left_eye.scale.y = 0.1
			if is_instance_valid(right_eye): right_eye.scale.y = 0.1
	else:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			_is_blinking = false
			_blink_timer = randf_range(2.5, 6.0)
			if is_instance_valid(left_eye): left_eye.scale.y = 1.0
			if is_instance_valid(right_eye): right_eye.scale.y = 1.0


# ==============================================================================
# HIGH-FIDELITY DYNAMIC TOOL ATTACHMENT (BEAUTIFUL HELD ITEMS)
# ==============================================================================

## Dynamically constructs a beautiful, 3D multi-box pixel art tool in the right hand.
func update_held_tool(item_id: int) -> void:
	# Clear previous tool geometry
	for child in held_tool_joint.get_children():
		child.queue_free()
		
	if item_id == -1:
		return # Empty hands
		
	var wood := Color(0.48, 0.35, 0.22)
	var iron := Color(0.65, 0.65, 0.70)
	var gold := Color(0.85, 0.60, 0.15)
	
	# Case A: Building Block equipped (Draws a mini model of the block in hand)
	if item_id >= 1 and item_id <= 14:
		var block_def := BlockLibrary.get_definition(item_id as BlockType.Type)
		var block_color := block_def.color_top if block_def != null else Color.GRAY
		_create_box_mesh(held_tool_joint, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.09, 0), block_color)
		
	# Case B: Lava Bucket
	elif item_id == 15:
		_create_box_mesh(held_tool_joint, Vector3(0.14, 0.18, 0.14), Vector3(0, 0.09, 0), iron) # Bucket body
		_create_box_mesh(held_tool_joint, Vector3(0.10, 0.04, 0.10), Vector3(0, 0.17, 0), Color(1.0, 0.45, 0.0)) # Lava top glow
		
	# Case C: Fried Chicken
	elif item_id == 16:
		_create_box_mesh(held_tool_joint, Vector3(0.04, 0.18, 0.04), Vector3(0, -0.04, 0), Color(0.92, 0.88, 0.82)) # Bone
		_create_box_mesh(held_tool_joint, Vector3(0.12, 0.16, 0.12), Vector3(0, 0.08, 0), Color(0.85, 0.35, 0.25)) # Roasted meat
		
	# Case D: HIGH-FIDELITY VOXEL BROADSWORD (ID 17)
	elif item_id == 17:
		# Grip handle
		_create_box_mesh(held_tool_joint, Vector3(0.04, 0.15, 0.04), Vector3(0.0, -0.15, 0.0), Color(0.35, 0.22, 0.15))
		_create_box_mesh(held_tool_joint, Vector3(0.06, 0.05, 0.06), Vector3(0.0, -0.225, 0.0), gold) # Pommel
		
		# Thick gold crossguard
		_create_box_mesh(held_tool_joint, Vector3(0.24, 0.05, 0.06), Vector3(0.0, -0.05, 0.0), gold)
		
		# Steel blade built from multiple layered, tapering segments!
		_create_box_mesh(held_tool_joint, Vector3(0.08, 0.45, 0.04), Vector3(0.0, 0.20, 0.0), iron) # Core blade
		_create_box_mesh(held_tool_joint, Vector3(0.06, 0.12, 0.03), Vector3(0.0, 0.45, 0.0), iron * 1.1) # Tapering point tip
		_create_box_mesh(held_tool_joint, Vector3(0.02, 0.32, 0.05), Vector3(0.0, 0.15, 0.0), Color(0.8, 0.8, 0.85)) # Central fuller ridge
		
	# Case E: Seeds
	elif item_id == 18:
		_create_box_mesh(held_tool_joint, Vector3(0.08, 0.08, 0.08), Vector3(0, 0, 0), Color(0.42, 0.85, 0.25)) # Green seed pouch
		
	# Case F: HIGH-FIDELITY VOXEL PICKAXE (Fallback default for building block tools)
	else:
		# Long wooden shaft
		_create_box_mesh(held_tool_joint, Vector3(0.04, 0.52, 0.04), Vector3(0.0, 0.0, 0.0), wood)
		
		# Structural metallic pickaxe head built out of overlapping curved segments!
		var pick_head_joint := Node3D.new()
		pick_head_joint.position = Vector3(0.0, 0.22, 0.0)
		held_tool_joint.add_child(pick_head_joint)
		
		_create_box_mesh(pick_head_joint, Vector3(0.08, 0.08, 0.08), Vector3(0.0, 0.0, 0.0), Color(0.35, 0.35, 0.38)) # Neck binding
		_create_box_mesh(pick_head_joint, Vector3(0.36, 0.06, 0.06), Vector3(0.0, 0.02, 0.0), iron) # Horizontal iron blade
		
		# Left curved claw tip
		_create_box_mesh(pick_head_joint, Vector3(0.06, 0.08, 0.05), Vector3(-0.16, -0.03, 0.0), iron * 0.95)
		# Right curved claw tip
		_create_box_mesh(pick_head_joint, Vector3(0.06, 0.08, 0.05), Vector3(0.16, -0.03, 0.0), iron * 0.95)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_texture_force_srgb = true
		
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _create_box_mesh(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	
	# Apply shadows settings matching parent client layer automatically
	if is_local_player:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
	parent.add_child(mesh_instance)
