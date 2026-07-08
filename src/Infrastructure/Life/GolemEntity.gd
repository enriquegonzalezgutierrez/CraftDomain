# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the village defender Iron Golem, designed
#              to be attached to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively active
#                patrolling, threat scanning, and heavy combat strikes, delegating
#                visual and collision parameters to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity
#                and satisfies the base contracts without code-based instantiation.
#              CIRCULAR DEPENDENCY SHIELD:
#              - Changed '_get_habitat()' return signature to 'int' to safely break
#                the GDScript compilation lock with MobRegistry class name.
#              STABILIZATION:
#              - Removed redundant signal connections already handled in parent class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/GolemEntity.gd
# ==============================================================================
class_name GolemEntity
extends PassiveEntity

# Active combat targets
var _combat_target: CharacterBody3D = null
var _attack_cooldown_timer: float = 0.0

# Asynchronous Scan Throttling Timer
var _tactical_scan_timer: float = 0.0
const SCAN_INTERVAL: float = 0.25 # 4 times per second

# Combat configurations
const ATTACK_RANGE: float = 2.2
const ATTACK_RANGE_SQ: float = 4.84 # 2.2 * 2.2
const AGGRO_SIGHT_RANGE: float = 12.0
const AGGRO_SIGHT_RANGE_SQ: float = 144.0 # 12.0 * 12.0
const ATTACK_COOLDOWN_INTERVAL: float = 1.8 # Heavy, slow swinging cooldown


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Heavy colossus initialized with 15 Hearts of health (30 HP)
	super(spawn_pos, 30)
	name = "Entity_GOLEM"
	_tactical_scan_timer = randf_range(0.0, SCAN_INTERVAL)


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Register in the shared alert network
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.register_defender(self)
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Fetch nameplate configurations if available
	_setup_nameplate_height()


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	# Aligns nameplate correctly above the visual model
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# CIRCULAR SHIELD: Return int directly (0 = TERRESTRIAL, 1 = AMPHIBIOUS, 2 = AQUATIC)
# This perfectly complies with LSP overrides and stops circular import compilation deadlocks.
# ==============================================================================
func _get_habitat() -> int:
	return 0 # Equivalent to MobRegistry.Habitat.TERRESTRIAL


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	return _combat_target == null


func _is_avian() -> bool:
	return false


# ==============================================================================
# OVERWATCH & DEFENSIVE COMBAT AI
# ==============================================================================
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
					var dist_sq_p := global_position.distance_squared_to(player_node.global_position)
					if dist_sq_p < min_dist_sq:
						min_dist_sq = dist_sq_p
						closest_target = player_node
	
	# 2. Check traditional hostile monsters (Zombies)
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child) and child is CharacterBody3D:
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq_z := global_position.distance_squared_to(child.global_position)
				if dist_sq_z < min_dist_sq:
					min_dist_sq = dist_sq_z
					closest_target = child as CharacterBody3D
					
	return closest_target


## Executes Golem's heavy double-arm launch attack (Throws targets 9.5m up!)
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
		_combat_target.call("take_damage", 2, throw_force, self)


## Public Gaze Interaction: Heavy rumbling sound responses.
func interact(player_node: CharacterBody3D) -> void:
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		var intro_node := DialogueNode.new()
		intro_node.node_id = "golem_intro_temp"
		intro_node.text = "DIALOGUE_GOLEM_RUMBLE"
			
		hud.open_dialogue(intro_node, "NPC_NAME_GOLEM", self)
