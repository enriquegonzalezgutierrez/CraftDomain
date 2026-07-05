# ==============================================================================
# Project: CraftDomain
# Description: Guard NPC physics controller. Extends PassiveEntity to implement 
#              defensive, combative behaviors instead of standard panic responses.
# SOLID COMPLIANCE: 
# - Liskov Substitution Principle (LSP): Subclasses PassiveEntity, 
#   safely overriding the movement, task routing, and visualization loops.
# - Single Responsibility Principle (SRP): Delegates rendering setups 
#   and AI state execution to specialized sibling components.
# - Dependency Inversion Principle (DIP): Resolves time-of-day queries 
#   statically through the decoupled CelestialService provider.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GuardEntity.gd
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

# Combat settings
const ATTACK_RANGE: float = 1.6
const ATTACK_RANGE_SQ: float = 2.56 # 1.6 * 1.6
const AGGRO_SIGHT_RANGE: float = 10.0
const AGGRO_SIGHT_RANGE_SQ: float = 100.0 # 10.0 * 10.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.2 # Time between slashes

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 # 4 times per second

# Handheld/Sheathed weapon node references
var _sword_joint: Node3D
var _shield_joint: Node3D


func _init(spawn_pos: Vector3) -> void:
	# Initialize with 5 Hearts of health for elite durability (10 HP)
	super(spawn_pos, 10)
	name = "Entity_GUARD"
	
	# Stagger initial scan timers to prevent multiple guards from scanning on the exact same frame
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var steel_armor := Color(0.40, 0.40, 0.45)      # Heavy textured steel plates
	var iron_color := Color(0.55, 0.55, 0.60)       # Raw iron highlights
	var gold_trim := Color(0.85, 0.6, 0.15)         # Gold ornaments and trims
	var plume_red := Color(0.85, 0.12, 0.15)        # Flowing crimson red plume
	var skin_color: Color = visual_component.variant_skin_color             # Procedural skin tone
	var brow_brown := Color(0.18, 0.12, 0.08)       # Unibrow dark brown
	var nose_brown := Color(0.55, 0.42, 0.32)       # Big long nose brown
	var wood_color := Color(0.45, 0.3, 0.15)         # Shield wooden board backing
	
	# 1. Base Legs & Heavy Steel Greaves (Attached to the bouncing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), steel_armor)
	
	# 2. Torso Steel Breastplate
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_armor)
	
	# 3D Shoulder Pauldrons (Gives broad, bulky knightly silhouette)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(-0.25, 0.75, 0), iron_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(0.25, 0.75, 0), iron_color)
	
	# Localized Gold Waist Belt
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), gold_trim)
	
	# 3. Head Joint Setup (Heavy Knight Helmet)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.05, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	# Face blocks (Taller forehead)
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color) # Face core
	visual_component.create_box(visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), nose_brown) # Nose
	
	# Voxel Unibrow (recessed under the helmet visor)
	visual_component.create_box(visual_component.head_node, Vector3(0.28, 0.04, 0.06), Vector3(0, 0.20, -0.19), brow_brown)
	
	# Steel Helmet Dome & Nose Visor Guard
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.22, 0.38), Vector3(0, 0.32, 0), steel_armor)
	visual_component.create_box(visual_component.head_node, Vector3(0.05, 0.18, 0.04), Vector3(0, 0.19, -0.20), iron_color) # Visor Guard
	
	# Flowing Crimson Plume (Hanging off the back of the helmet dome)
	visual_component.create_box(visual_component.head_node, Vector3(0.04, 0.28, 0.16), Vector3(0, 0.48, 0.05), plume_red)
	
	# Deep-set Blinking Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.15, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.15, -0.18), Color.WHITE)
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# 4. Arms Folded (Steel-colored sleeves matching the breastplate)
	visual_component.arms_node = Node3D.new()
	visual_component.arms_node.name = "ArmsJoint"
	visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	visual_component.body_bob_node.add_child(visual_component.arms_node)
	visual_component.create_box(visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), steel_armor * 0.95)
	
	# 5. Weaponry Equipment Joints (Parented directly to the bouncing body bob node)
	_sword_joint = Node3D.new()
	_sword_joint.name = "IronSwordJoint"
	visual_component.body_bob_node.add_child(_sword_joint)
	_setup_sheathed_sword_transforms(iron_color, gold_trim, wood_color)
	
	_shield_joint = Node3D.new()
	_shield_joint.name = "ShieldJoint"
	_shield_joint.position = Vector3(0.1, 0.5, 0.25)
	_shield_joint.rotation = Vector3(0, deg_to_rad(15), deg_to_rad(10))
	visual_component.body_bob_node.add_child(_shield_joint)
	
	# Knightly Heater Shield Board
	visual_component.create_box(_shield_joint, Vector3(0.35, 0.5, 0.05), Vector3(0, 0, 0), wood_color)
	# Steel Border trims
	visual_component.create_box(_shield_joint, Vector3(0.39, 0.04, 0.07), Vector3(0, 0.24, 0.01), iron_color)
	visual_component.create_box(_shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(-0.18, -0.01, 0.01), iron_color)
	visual_component.create_box(_shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(0.18, -0.01, 0.01), iron_color)
	# Gold-plated central crest pattern
	visual_component.create_box(_shield_joint, Vector3(0.12, 0.32, 0.08), Vector3(0, 0, 0.01), gold_trim)


## Constructs the sword boxes and positions the joint in sheathed (passive) transforms.
func _setup_sheathed_sword_transforms(iron: Color, gold: Color, wood: Color) -> void:
	_sword_joint.position = Vector3(-0.2, 0.5, 0.24)
	_sword_joint.rotation = Vector3(0, 0, deg_to_rad(-135))
	
	visual_component.create_box(_sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), iron)  # Blade
	visual_component.create_box(_sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), gold)   # Guard
	visual_component.create_box(_sword_joint, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.1, 0), wood)   # Grip


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_TALK"))


## Public Gaze Interaction: Deploys tactical dialogue trees.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "guard_intro_temp"
		intro_node.text = _select_procedural_greeting_key()
			
		hud.open_dialogue(intro_node, "NPC_NAME_GUARD", self)


## Selects a unique localized dialogue key based on time, biome, and variety index.
func _select_procedural_greeting_key() -> String:
	# DIP Compliance: Safely retrieve time statically
	var is_night: bool = CelestialService.is_night_time_static()
		
	if is_night:
		return "DIALOGUE_GUARD_NIGHT"
		
	var biome_id := _detect_current_biome()
	match biome_id:
		4: return "DIALOGUE_GUARD_GLACIERS"   
		7: return "DIALOGUE_GUARD_NEON"       
		_:
			var variety_index := npc_seed % 2
			match variety_index:
				0: return "DIALOGUE_GUARD_PLAINS_A"
				_: return "DIALOGUE_GUARD_PLAINS_B"


## Overrides standard physics ticker to weave defensive aggro scanning loops.
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
		
	_process_defensive_aggro_intelligence(delta)
	super(delta)


## Scans, locks, and chases hostile zombies within the aggro visual ranges.
func _process_defensive_aggro_intelligence(delta: float) -> void:
	# ==========================================================================
	# TACTICAL PROXIMITY SCAN (Throttled for Performance)
	# ==========================================================================
	_tactical_scan_timer -= delta
	if _tactical_scan_timer <= 0.0:
		_tactical_scan_timer = SCAN_INTERVAL
		
		# Scan for nearest threat if currently un-engaged
		if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
			_combat_target = _scan_for_active_zombie_target()
			
	# ==========================================================================
	# ACTIVE COMBAT PURSUIT
	# ==========================================================================
	if is_instance_valid(_combat_target) and not _combat_target.get("domain_entity").is_dead:
		# Lock standard wandering AI decisions
		if is_instance_valid(ai_component):
			ai_component.current_task = NPCAIComponent.TaskState.WORKING
			
		# Animate: Draw weapon forward (Move sword joint to hands position)
		_draw_combat_sword(delta)
		
		var target_pos := _combat_target.global_position
		var diff := target_pos - global_position
		diff.y = 0.0
		
		# MATH OPTIMIZATION: Compare squared length to avoid sqrt() operations
		var dist_sq := diff.length_squared()
		
		if dist_sq > ATTACK_RANGE_SQ:
			# Chase at high-pursuit run speed (Read vector, override ai_component velocity)
			var wander_dir := diff.normalized()
			velocity.x = wander_dir.x * BASE_SPEED * 1.8
			velocity.z = wander_dir.z * BASE_SPEED * 1.8
			
			if is_instance_valid(ai_component):
				ai_component.wander_direction = wander_dir
			
			# Jump over small obstacles
			if is_on_wall() and is_on_floor():
				velocity.y = JUMP_VELOCITY
		else:
			# In-range: Halt and swing!
			velocity.x = 0.0
			velocity.z = 0.0
			
			if is_instance_valid(ai_component):
				ai_component.wander_direction = diff.normalized()
			
			if _attack_cooldown_timer <= 0.0:
				_execute_combat_strike()
	else:
		# No threat: Animate sword sheathing and return to normal states
		_sheathe_combat_sword(delta)
		if is_instance_valid(ai_component) and ai_component.current_task == NPCAIComponent.TaskState.WORKING:
			ai_component.current_task = NPCAIComponent.TaskState.IDLE
			ai_component.task_timer = 1.0


## Trigonometric Scan: Locates the closest active zombie within combat range.
## HIGH PERFORMANCE: Uses Godot's native O(1) group lookup instead of full SceneTree loop.
func _scan_for_active_zombie_target() -> CharacterBody3D:
	if not is_inside_tree():
		return null
		
	var closest_zombie: CharacterBody3D = null
	var min_dist_sq := AGGRO_SIGHT_RANGE_SQ
	
	# HIGHT PERFORMANCE GROUP QUERY
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_zombie = child as CharacterBody3D
					
	return closest_zombie


## Animate: Repositions the sword joint forward, mimicking a ready combat stance.
func _draw_combat_sword(delta: float) -> void:
	if is_instance_valid(_sword_joint):
		# Interpolate sword joint position forward to mimic holding it in right hand
		_sword_joint.position = _sword_joint.position.lerp(Vector3(0.24, 0.45, -0.32), delta * 8.0)
		_sword_joint.rotation.x = lerp(_sword_joint.rotation.x, deg_to_rad(65), delta * 8.0)
		_sword_joint.rotation.y = lerp(_sword_joint.rotation.y, deg_to_rad(-45), delta * 8.0)
		_sword_joint.rotation.z = lerp(_sword_joint.rotation.z, deg_to_rad(0), delta * 8.0)


## Animate: Return the sword joint back to the sheathed shoulder harness on back.
func _sheathe_combat_sword(delta: float) -> void:
	if is_instance_valid(_sword_joint):
		_sword_joint.position = _sword_joint.position.lerp(Vector3(-0.2, 0.5, 0.24), delta * 5.0)
		_sword_joint.rotation.x = lerp(_sword_joint.rotation.x, 0.0, delta * 5.0)
		_sword_joint.rotation.y = lerp(_sword_joint.rotation.y, 0.0, delta * 5.0)
		_sword_joint.rotation.z = lerp(_sword_joint.rotation.z, deg_to_rad(-135), delta * 5.0)


## Executes sword slash calculations against the target zombie.
func _execute_combat_strike() -> void:
	if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
		return
		
	_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
	
	# Apply diagonal physical knockback force
	var wander_dir := _combat_target.global_position - global_position
	wander_dir.y = 0.0
	wander_dir = wander_dir.normalized()
	
	var knockback_dir := wander_dir * 4.5
	knockback_dir.y = 2.0
	
	# Deal 1 Heart damage (Zombies have 3 Hearts and die in 3 hits)
	if _combat_target.has_method("take_damage"):
		_combat_target.call("take_damage", 1, knockback_dir)
		
	# Perform a quick physical visual swing tilt (Animate strike recoil)
	var swing_tween := create_tween()
	swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(-45), 0.08).set_trans(Tween.TRANS_SINE)
	swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(65), 0.12).set_trans(Tween.TRANS_SINE)


## Queries coordinate biomes.
func _detect_current_biome() -> int:
	var world_controller_ref: Node = get_parent() as Node
	var default_biome_id: int = 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id


func _can_socialize() -> bool:
	return _combat_target == null
