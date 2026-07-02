# ==============================================================================
# Project: CraftDomain
# Description: Golem NPC physics controller. A giant stone defender of villagers 
#              that patrols outposts, scans for zombies, and executes high-impact 
#              vertical tossing attacks to protect the plains.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity, 
#                safely overriding movement, task routing, and visualization loops.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GolemEntity.gd
# ==============================================================================
class_name GolemEntity
extends PassiveEntity

# Combat configurations
const ATTACK_RANGE: float = 2.2
const AGGRO_SIGHT_RANGE: float = 12.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.8 # Heavy, slow swinging cooldown

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Handheld/Visual dangling limbs node references for custom combat animations
var _left_arm_joint: Node3D
var _right_arm_joint: Node3D


func _init(spawn_pos: Vector3) -> void:
	# Heavy colossus initialized with 15 Hearts of health (30 HP)
	super(spawn_pos, 30)
	name = "Entity_GOLEM"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var stone_color := Color(0.38, 0.40, 0.42)      # Heavy iron-slate stone
	var ivy_green := Color(0.18, 0.45, 0.15)        # Mossy creeping ivy green
	var flower_gold := Color(1.0, 0.85, 0.2)        # Golden flower buds
	var glow_red := Color(0.95, 0.15, 0.15)         # Glowing red visor eyes
	
	# 1. Base Legs (Segmented thick stone blocks, attached to the bouncing body bob joint)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.22, 0.45, 0.22), Vector3(-0.18, 0.225, 0.0), stone_color * 0.8) # Left leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.22, 0.45, 0.22), Vector3(0.18, 0.225, 0.0), stone_color * 0.8)  # Right leg
	
	# 2. Torso Massive Stone Chest (Thick and wide slate structure)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.85, 0.85, 0.52), Vector3(0, 0.875, 0), stone_color)
	
	# Creeping Ivy Vines on shoulders (Voxel green leaves overlaying chest corners)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.22, 0.24, 0.56), Vector3(-0.35, 1.10, 0.01), ivy_green) # Left shoulder ivy
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.22, 0.24, 0.56), Vector3(0.35, 1.10, 0.01), ivy_green)  # Right shoulder ivy
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.12, 0.38, 0.08), Vector3(-0.25, 0.75, -0.27), ivy_green) # Vines creeping down chest
	
	# Small flower buds dotting the ivy
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.06), Vector3(-0.35, 1.23, 0.08), flower_gold) # Gold flower left
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.06, 0.06), Vector3(0.28, 0.65, -0.28), flower_gold)  # Gold flower on chest vine
	
	# 3. Head Joint Setup (Slightly recessed visored look)
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "GolemHead"
	visual_component.head_node.position = Vector3(0.0, 1.30, -0.06)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.38, 0.42, 0.38), Vector3(0, 0.21, 0), stone_color) # Face
	visual_component.create_box(visual_component.head_node, Vector3(0.10, 0.22, 0.12), Vector3(0, 0.11, -0.22), stone_color * 0.85) # Protruding unibrow/nose
	
	# Glowing Red Visor Eyes (Constructed with custom emissive properties)
	var eye_l := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.05, 0.02), Vector3(-0.10, 0.18, -0.19), glow_red)
	var eye_r := visual_component.create_box(visual_component.head_node, Vector3(0.06, 0.05, 0.02), Vector3(0.10, 0.18, -0.19), glow_red)
	
	var em_mat := ORMMaterial3D.new()
	em_mat.albedo_color = glow_red
	em_mat.emission_enabled = true
	em_mat.emission = Color(1.0, 0.1, 0.1)
	em_mat.emission_energy_multiplier = 2.5
	eye_l.material_override = em_mat
	eye_r.material_override = em_mat
	
	# 4. GIGANTIC DANGLING COMBAT ARMS
	# Left dangling arm joint
	_left_arm_joint = Node3D.new()
	_left_arm_joint.name = "LeftArmHarness"
	_left_arm_joint.position = Vector3(-0.48, 1.20, 0.0)
	visual_component.body_bob_node.add_child(_left_arm_joint)
	visual_component.create_box(_left_arm_joint, Vector3(0.18, 1.15, 0.18), Vector3(0.0, -0.50, 0.0), stone_color) # Left stone forearm
	visual_component.create_box(_left_arm_joint, Vector3(0.20, 0.15, 0.20), Vector3(0.0, -0.20, 0.0), ivy_green)   # Shoulder ivy pad
	
	# Right dangling arm joint
	_right_arm_joint = Node3D.new()
	_right_arm_joint.name = "RightArmHarness"
	_right_arm_joint.position = Vector3(0.48, 1.20, 0.0)
	visual_component.body_bob_node.add_child(_right_arm_joint)
	visual_component.create_box(_right_arm_joint, Vector3(0.18, 1.15, 0.18), Vector3(0.0, -0.50, 0.0), stone_color)
	visual_component.create_box(_right_arm_joint, Vector3(0.20, 0.15, 0.20), Vector3(0.0, -0.20, 0.0), ivy_green)


func _get_collision_box_size() -> Vector3:
	return Vector3(0.95, 1.75, 0.65)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.875, 0.0)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", "DEFENDER")


## Public Gaze Interaction: Heavy rumbling sound responses.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "golem_intro_temp"
		intro_node.text = "DIALOGUE_GOLEM_RUMBLE"
			
		hud.open_dialogue(intro_node, "NPC_NAME_GOLEM", self)


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
		# Lock standard wandering AI decisions
		if is_instance_valid(ai_component):
			ai_component.current_task = NPCAIComponent.TaskState.WORKING
			
		var target_pos := _combat_target.global_position
		var diff := target_pos - global_position
		diff.y = 0.0
		
		var dist := diff.length()
		
		if dist > ATTACK_RANGE:
			# Chase at slow but unstoppable colossus walking speed
			var wander_dir := diff.normalized()
			velocity.x = wander_dir.x * BASE_SPEED * 1.3
			velocity.z = wander_dir.z * BASE_SPEED * 1.3
			
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
				_execute_heavy_combat_strike()
	else:
		# Return back to idle positions
		_idle_arm_sway_recoil(delta)
		if is_instance_valid(ai_component) and ai_component.current_task == NPCAIComponent.TaskState.WORKING:
			ai_component.current_task = NPCAIComponent.TaskState.IDLE
			ai_component.task_timer = 1.0


## Trigonometric Scan: Locates the closest active zombie within combat range.
func _scan_for_active_zombie_target() -> CharacterBody3D:
	var world_node := get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_zombie: CharacterBody3D = null
	var min_dist := AGGRO_SIGHT_RANGE
	
	# FIX: Explicit static typing on child nodes iteration
	for child: Node in world_node.get_children():
		if child.name.contains("ZOMBIE") and is_instance_valid(child):
			# FIX: Explicit static typing on retrieved VoxelEntity domain data
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist := global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_zombie = child as CharacterBody3D
					
	return closest_zombie


## Animate: Smoothly restores arms back to dangling resting transforms
func _idle_arm_sway_recoil(delta: float) -> void:
	if is_instance_valid(_left_arm_joint) and is_instance_valid(_right_arm_joint):
		var sway: float = sin(visual_component._animation_time * 2.0) * 0.05
		_left_arm_joint.rotation.x = lerp(_left_arm_joint.rotation.x, sway, delta * 4.0)
		_right_arm_joint.rotation.x = lerp(_right_arm_joint.rotation.x, -sway, delta * 4.0)


## Executes Golem's iconic heavy double-arm launch attack (Throws Zombies up!)
func _execute_heavy_combat_strike() -> void:
	if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
		return
		
	_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
	
	# Calculate target horizontal directional vectors
	var target_dir := _combat_target.global_position - global_position
	target_dir.y = 0.0
	target_dir = target_dir.normalized()
	
	# ICONIC VERTICAL LAUNCH INERTIA: Throws the Zombie 9.5 meters up!
	var throw_force := target_dir * 3.5 + Vector3(0.0, 9.5, 0.0)
	
	# Deals heavy 2 Hearts damage (Kills zombies in 2 hits instead of 3!)
	if _combat_target.has_method("take_damage"):
		_combat_target.call("take_damage", 2, throw_force)
		
	# Play dynamic physical arm swing animation (Upward launching sways!)
	var swing_tween := create_tween().set_parallel(true)
	if is_instance_valid(_left_arm_joint) and is_instance_valid(_right_arm_joint):
		# Rapidly pivot both arms forward and up (Launch step!)
		swing_tween.tween_property(_left_arm_joint, "rotation:x", deg_to_rad(-110), 0.12).set_trans(Tween.TRANS_SINE)
		swing_tween.tween_property(_right_arm_joint, "rotation:x", deg_to_rad(-110), 0.12).set_trans(Tween.TRANS_SINE)
		
		# Gradually swing arms back down (Recovery step!)
		swing_tween.chain().set_parallel(true)
		swing_tween.tween_property(_left_arm_joint, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		swing_tween.tween_property(_right_arm_joint, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _can_socialize() -> bool:
	return _combat_target == null


func _is_avian() -> bool:
	# Keep standard solid slow sways
	return false
