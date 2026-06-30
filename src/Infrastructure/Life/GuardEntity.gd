# ==============================================================================
# Project: CraftDomain
# Description: Guard NPC physics controller. Extends PassiveEntity to implement 
#              defensive, combative behaviors instead of standard panic responses.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity, 
#                safely overriding the movement, task routing, and visualization loops.
#              - Single Responsibility Principle (SRP): Handles exclusively military 
#                detection, chasing, combat cooldowns, and soldier-specific meshes.
#              - Open-Closed Principle (OCP) & i18n: Exclusively uses translation 
#                keys to prevent hardcoded string leakage in codebase.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GuardEntity.gd
# ==============================================================================
class_name GuardEntity
extends PassiveEntity

# Combat settings
const ATTACK_RANGE: float = 1.6
const AGGRO_SIGHT_RANGE: float = 10.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.2 # Time between slashes

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Handheld/Sheathed weapon node references
var _sword_joint: Node3D
var _shield_joint: Node3D


func _init(spawn_pos: Vector3) -> void:
	# Initialize with 5 Hearts of health for elite durability (10 HP)
	super(spawn_pos, 10)
	name = "Entity_GUARD"


## Concrete Implementation: Assembles a detailed steel-plated soldier, 
## integrating the deterministic variant palette for unique visual identities.
func _build_visual_representation() -> void:
	var armor_base_color := Color(0.40, 0.40, 0.45) # Heavy steel
	var sash_color := variant_clothing_color         # Procedural tunic trim
	var plume_color := variant_hair_color            # Procedural helmet plume
	var skin_color := variant_skin_color             # Procedural skin tone
	var gold_trim := Color(0.85, 0.6, 0.15)          # Gold accents
	var wood_color := Color(0.45, 0.3, 0.15)         # Shield backing
	var iron_color := Color(0.55, 0.55, 0.6)         # Raw iron
	
	# 1. Base Legs & Iron Greaves (Attached to the bouncing joint)
	_create_box(_body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), armor_base_color)
	
	# 2. Torso Steel Breastplate
	_create_box(_body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), armor_base_color)
	
	# 3D Shoulder Pauldrons (Gives broad, bulky silhouette)
	_create_box(_body_bob_node, Vector3(0.12, 0.22, 0.35), Vector3(-0.25, 0.75, 0), iron_color)
	_create_box(_body_bob_node, Vector3(0.12, 0.22, 0.35), Vector3(0.25, 0.75, 0), iron_color)
	
	# Localized Crimson Belt
	_create_box(_body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), sash_color)
	
	# 3. Head Joint & Advanced Nose-Guard Helmet
	_head_node = Node3D.new()
	_head_node.name = "HumanHead"
	_head_node.position = Vector3(0, 1.05, 0)
	_body_bob_node.add_child(_head_node)
	
	# Peachy skin core
	_create_box(_head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_create_box(_head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9) # Nose
	
	# Steel Helmet Dome
	_create_box(_head_node, Vector3(0.38, 0.22, 0.38), Vector3(0, 0.28, 0), iron_color)
	_create_box(_head_node, Vector3(0.05, 0.18, 0.04), Vector3(0, 0.19, -0.20), iron_color) # Visor Guard
	
	# Colored Plume (Procedural hair variant color)
	_create_box(_head_node, Vector3(0.04, 0.24, 0.14), Vector3(0, 0.45, 0.05), plume_color)
	
	# Deep-set Blinking Soldier Eyes
	_left_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	_right_eye = _create_box(_head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE)
	_create_box(_right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.15, 0.15, 0.15))
	
	# 4. Arms (Clothed in sash color sleeves)
	_arms_node = Node3D.new()
	_arms_node.name = "ArmsJoint"
	_arms_node.position = Vector3(0, 0.65, -0.23)
	_body_bob_node.add_child(_arms_node)
	_create_box(_arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), sash_color)
	
	# 5. Weaponry Equipment Joints (Stored on back by default)
	_sword_joint = Node3D.new()
	_sword_joint.name = "IronSwordJoint"
	_body_bob_node.add_child(_sword_joint)
	_setup_sheathed_sword_transforms(iron_color, gold_trim, wood_color)
	
	_shield_joint = Node3D.new()
	_shield_joint.name = "ShieldJoint"
	_shield_joint.position = Vector3(0.1, 0.5, 0.25)
	_shield_joint.rotation = Vector3(0, deg_to_rad(15), deg_to_rad(10))
	_body_bob_node.add_child(_shield_joint)
	
	# Shield Board
	_create_box(_shield_joint, Vector3(0.35, 0.5, 0.05), Vector3(0, 0, 0), wood_color)
	# Steel Border trims
	_create_box(_shield_joint, Vector3(0.39, 0.04, 0.07), Vector3(0, 0.24, 0.01), iron_color)
	_create_box(_shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(-0.18, -0.01, 0.01), iron_color)
	_create_box(_shield_joint, Vector3(0.04, 0.52, 0.07), Vector3(0.18, -0.01, 0.01), iron_color)
	# Tunic color matching crest pattern
	_create_box(_shield_joint, Vector3(0.12, 0.32, 0.08), Vector3(0, 0, 0.01), sash_color)


## Constructs the sword boxes and positions the joint in sheathed (passive) transforms.
func _setup_sheathed_sword_transforms(iron: Color, gold: Color, wood: Color) -> void:
	_sword_joint.position = Vector3(-0.2, 0.5, 0.24)
	_sword_joint.rotation = Vector3(0, 0, deg_to_rad(-135))
	
	_create_box(_sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), iron)  # Blade
	_create_box(_sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), gold)   # Guard
	_create_box(_sword_joint, Vector3(0.04, 0.12, 0.04), Vector3(0, -0.1, 0), wood)   # Grip


func _get_collision_box_size() -> Vector3:
	return Vector3(0.575, 1.5, 0.575)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.75, 0)


func _setup_floating_bubble() -> void:
	var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", "RIGHT-CLICK TO TALK!")


## Public Gaze Interaction: Deploys tactical dialogue trees.
## REFACTORING: Replaced hardcoded dialogue text with dynamic i18n translation keys.
func interact(player_node: CharacterBody3D) -> void:
	var hud = player_node.get("hud")
	if is_instance_valid(hud):
		var intro_node: Resource = DialogueService.get_dialogue_node("guard_intro")
		if intro_node == null:
			var fallback_node := DialogueNode.new()
			fallback_node.node_id = "guard_intro"
			fallback_node.text = "DIALOGUE_GUARD_INTRO"
			DialogueService.register_node(fallback_node)
			intro_node = fallback_node
			
		hud.call("open_dialogue", intro_node, "Guard")


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
	# 1. Scan for nearest threat if currently un-engaged
	if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
		_combat_target = _scan_for_active_zombie_target()
		
	# 2. Process active combat pursuits
	if is_instance_valid(_combat_target) and not _combat_target.get("domain_entity").is_dead:
		current_task = TaskState.WORKING # Lock standard wandering routines
		
		# Animate: Draw weapon forward (Move sword joint to hands position)
		_draw_combat_sword(delta)
		
		var target_pos := _combat_target.global_position
		var diff := target_pos - global_position
		diff.y = 0.0
		
		var dist := diff.length()
		
		if dist > ATTACK_RANGE:
			# Chase at high-pursuit run speed
			_wander_direction = diff.normalized()
			velocity.x = _wander_direction.x * BASE_SPEED * 1.8
			velocity.z = _wander_direction.z * BASE_SPEED * 1.8
			
			# Jump over small obstacles
			if is_on_wall() and is_on_floor():
				velocity.y = JUMP_VELOCITY
		else:
			# In-range: Halt and swing!
			velocity.x = 0.0
			velocity.z = 0.0
			_wander_direction = diff.normalized()
			
			if _attack_cooldown_timer <= 0.0:
				_execute_combat_strike()
	else:
		# No threat: Animate sword sheathing and return to normal states
		_sheathe_combat_sword(delta)
		if current_task == TaskState.WORKING:
			current_task = TaskState.IDLE
			_task_timer = 1.0


## Trigonometric Scan: Locates the closest active zombie within combat range.
func _scan_for_active_zombie_target() -> CharacterBody3D:
	var world_node := get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_zombie: CharacterBody3D = null
	var min_dist := AGGRO_SIGHT_RANGE
	
	for child in world_node.get_children():
		if child.name.contains("ZOMBIE") and is_instance_valid(child):
			var zombie_entity = child.get("domain_entity")
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist := global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
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
	var knockback_dir := _wander_direction * 4.5
	knockback_dir.y = 2.0
	
	# Deal 1 Heart damage (Zombies have 3 Hearts and die in 3 hits)
	if _combat_target.has_method("take_damage"):
		_combat_target.call("take_damage", 1, knockback_dir)
		print("[GuardAI] Slashed zombie! Target health: ", _combat_target.get("domain_entity").health)
		
	# Perform a quick physical visual swing tilt (Animate strike recoil)
	var swing_tween := create_tween()
	swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(-45), 0.08).set_trans(Tween.TRANS_SINE)
	swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(65), 0.12).set_trans(Tween.TRANS_SINE)


func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.65:
		current_task = TaskState.WANDERING 
		var angle := randf() * TAU
		_wander_direction = Vector3(cos(angle), 0, sin(angle))
		_task_timer = randf_range(4.0, 9.0)
	else:
		current_task = TaskState.IDLE 
		_task_timer = randf_range(2.0, 5.0)


func _can_socialize() -> bool:
	# Only socialize if not actively chasing zombies!
	return _combat_target == null
