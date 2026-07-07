# ==============================================================================
# Project: CraftDomain
# Description: Golem NPC physics controller. A giant stone defender of villagers 
#              that patrols outposts, scans for zombies, and executes high-impact 
#              vertical tossing attacks to protect the plains.
# SOLID COMPLIANCE: 
# - Liskov Substitution Principle (LSP): Subclasses PassiveEntity, 
#   safely overriding movement, task routing, and visual meshes.
# - Single Responsibility Principle (SRP): Delegates visual rendering 
#   to the sub-component, and physics movements to the base class.
# - Dependency Inversion Principle (DIP): Automatically prunes 
#   extraneous Blender-exported nodes (Cameras, Lights) on initialization.
# COMBAT ALERTS INTEGRATION (Phase 3):
#              - Overrode `_ready()` to execute base configurations and proactively 
#                register itself into the active static `AlertNetworkService.instance` pool.
# VILLAGE REPUTATION & OUTLAW AGGRO (Phase 4):
#              - Enhanced `_scan_for_active_zombie_target()` to query player karma.
#              - Declares the player as an active target if their reputation falls to 
#                WANTED outlaw status (reputation <= -50), prioritizing public defense.
#              - Passes `self` as the attacker within `take_damage` to ensure correct 
#                damage source mapping.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GolemEntity.gd
# ==============================================================================
class_name GolemEntity
extends PassiveEntity

const MODEL_PATH := "res://assets/models/mobs/golem.glb"

# Combat configurations
const ATTACK_RANGE: float = 2.2
const ATTACK_RANGE_SQ: float = 4.84 # 2.2 * 2.2
const AGGRO_SIGHT_RANGE: float = 12.0
const AGGRO_SIGHT_RANGE_SQ: float = 144.0 # 12.0 * 12.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.8 # Heavy, slow swinging cooldown

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 # 4 times per second


func _init(spawn_pos: Vector3) -> void:
	# Heavy colossus initialized with 15 Hearts of health (30 HP)
	super(spawn_pos, 30)
	name = "Entity_GOLEM"
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)


## Overrode ready to run base configurations and register into the alert pool
func _ready() -> void:
	super() # <-- CRITICAL: Executes base PassiveEntity colliders, nameplate and bubble setups
	
	# Register in the shared alert network
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.register_defender(self)


## Loads the external GLB model and applies calculated mathematical transforms
func _build_visual_representation() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		var model_node := model_scene.instantiate() as Node3D
		
		# Prune Blender's default light and camera nodes to prevent rendering conflicts
		_prune_extraneous_nodes(model_node)
		
		# ======================================================================
		# MATHEMATICAL CALIBRATION (Based on GLB Analyzer)
		# ======================================================================
		# 1. Scale model by 1.7516x to achieve a colossal giant height of ~3.5m
		model_node.scale = Vector3(1.7516, 1.7516, 1.7516)
		
		# 2. Waist-Pivot Fix: Raise it up by +1.7509m on Y
		#    to anchor the feet perfectly flat on the ground plane
		model_node.position = Vector3(0.0, 1.7509, 0.0)
		
		# 3. Apply 180-degree visual offset to correct the backwards orientation
		model_node.rotation_degrees = Vector3(0, 180, 0)
		# ======================================================================
		
		# Append the model to the bob joint to automatically inherit walk animations
		visual_component.body_bob_node.add_child(model_node)
		_register_glb_materials(model_node)
	else:
		push_error("[GolemEntity] GLB model not found at path: " + MODEL_PATH)


## Recursively duplicates materials and patches tangent warnings
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.get_active_material(0) as Material
		if mat == null and node.mesh != null:
			var surface_material := node.mesh.surface_get_material(0) as Material
			mat = surface_material
			
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


## Calibrated to the scaled bounding box size (3.5m height, 2.8m width, 1.3m depth)
func _get_collision_box_size() -> Vector3:
	return Vector3(2.8, 3.5, 1.3)


## Centered relative to the body height
func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 1.75, 0.0)


func _setup_floating_bubble() -> void:
	var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
	if sb_script != null:
		_bubble = sb_script.new() as Node3D
		add_child(_bubble)
		_bubble.call("set_text", tr("BUBBLE_DEFENDER"))


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
	_tactical_scan_timer -= delta
	if _tactical_scan_timer <= 0.0:
		_tactical_scan_timer = SCAN_INTERVAL
		
		# Scan for nearest threat if currently un-engaged
		if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
			_combat_target = _scan_for_active_zombie_target()
			
	if is_instance_valid(_combat_target) and not _combat_target.get("domain_entity").is_dead:
		if is_instance_valid(ai_component):
			ai_component.current_task = NPCAIComponent.TaskState.WORKING
			
		var target_pos := _combat_target.global_position
		var diff := target_pos - global_position
		diff.y = 0.0
		
		var dist_sq := diff.length_squared()
		
		if dist_sq > ATTACK_RANGE_SQ:
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
		if is_instance_valid(ai_component) and ai_component.current_task == NPCAIComponent.TaskState.WORKING:
			ai_component.current_task = NPCAIComponent.TaskState.IDLE
			ai_component.task_timer = 1.0


## Trigonometric Scan: Locates the closest active zombie or outlaw player within combat range.
func _scan_for_active_zombie_target() -> CharacterBody3D:
	if not is_inside_tree():
		return null
		
	var closest_target: CharacterBody3D = null
	var min_dist_sq := AGGRO_SIGHT_RANGE_SQ
	
	# 1. Check if the player is currently WANTED for crimes against the village
	var rep := VillageReputationService.instance
	if is_instance_valid(rep) and rep.is_player_wanted():
		var parent_node := get_parent()
		if is_instance_valid(parent_node):
			var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
			if is_instance_valid(player_node):
				var p_domain := player_node.get("domain_entity") as VoxelEntity
				if p_domain != null and not p_domain.is_dead:
					var dist_sq := global_position.distance_squared_to(player_node.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_target = player_node # Priority target: WANTED player!
	
	# 2. Check traditional hostile monsters (Zombies)
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_target = child as CharacterBody3D
					
	return closest_target


## Executes Golem's iconic heavy double-arm launch attack (Throws Zombies/Outlaws up!)
func _execute_heavy_combat_strike() -> void:
	if not is_instance_valid(_combat_target) or _combat_target.get("domain_entity").is_dead:
		return
		
	_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL
	
	var target_dir := _combat_target.global_position - global_position
	target_dir.y = 0.0
	target_dir = target_dir.normalized()
	
	# Launch force scaled to throw the target 9.5 meters up!
	var throw_force := target_dir * 3.5 + Vector3(0.0, 9.5, 0.0)
	
	# Deals heavy 2 Hearts damage
	if _combat_target.has_method("take_damage"):
		_combat_target.call("take_damage", 2, throw_force, self) # Pass self as attacker


func _can_socialize() -> bool:
	return _combat_target == null


func _is_avian() -> bool:
	return false
