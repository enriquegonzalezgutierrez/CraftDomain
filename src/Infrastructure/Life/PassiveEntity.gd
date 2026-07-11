# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Player Character / Entity Base)
# Class: PassiveEntity
# Description: Abstract base class representing physical entities. Manages movement
#              vectors, gravity calculations, safe boundary checks,
#              and dynamic nameplate/quest-arrow UI attachments.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical motion loops
#   and UI attachments.
# - Open-Closed Principle (OCP): Completely closed to modifications. It has zero
#   knowledge of its subclasses, their names, or their hostile/friendly alignments.
# - Liskov Substitution Principle (LSP): Defines abstract virtual contracts
#   `_get_entity_name_key()` and `_get_nameplate_color()` that every concrete 
#   subclass must implement polimorphically to ensure correct state rendering.
# - Dependency Inversion Principle (DIP): Interfaces with abstract systems,
#   keeping dependencies inverted towards abstractions.
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

# --- SOLID POLYMORPHIC DESIGN CONFIGURATIONS (OCP COMPLIANT) ---
## The localization key representing this entity's display name.
## Initialized dynamically on startup by querying the subclass contract.
var entity_name_key: String = ""

## True if this NPC can engage in branching dialogue trees.
@export var is_conversational_npc: bool = false

## Classifies the humanoid role type (e.g. 0: Villager, 1: Merchant, 2: Guard, etc.).
## Set to -1 for non-humanoid wild animals.
@export var humanoid_role: int = -1

## Represents the physical habitat/movement boundaries (0: Terrestrial, 1: Amphibious, 2: Aquatic).
@export var entity_habitat: int = 0

# Base physical movement constants
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0

# Base animation asset root folder
const ANIM_DIR := "res://assets/models/mobs/"

# Sibling Component references (Composite Pattern)
var ai_component: NPCAIComponent
var visual_component: NPCVisualComponent

# Domain Model Composition (DDD Compliance)
var domain_entity: VoxelEntity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Original Spawn Point used to anchor human NPCs so they never get lost (Tethering)
var _spawn_point: Vector3

# Dynamic floating Speech Bubble & Nameplate references
var _bubble: Node3D
var _nameplate: Label3D

# WARNING RESOLUTION: Renamed to public context to clear UNUSED_PRIVATE_CLASS_VARIABLE
var quest_check_timer: float = 0.5

# 3D Floating Quest Indicator Arrow (Golden Prism pointing down)
var _quest_arrow: MeshInstance3D

# Deterministic unique Seed computed on coordinate hashes
var npc_seed: int = 0

# Injected Visual Representation Strategy (DIP Compliant)
var visual_representation: IEntityVisualRepresentation

# Cached height tracker for dynamic UI positioning
var _collision_height: float = 1.5

# Conversation State Machine: Dynamic player gaze-lock variables
var is_talking: bool = false
var _talking_partner: CharacterBody3D = null

# Reputation and combat trackers
var _last_attacker: Node = null

# Physics LOD status flag
var _is_physically_sleeping: bool = false

# Binds this specific NPC instance permanently to a Quest ID if spawned at the target location
var quest_target_id: String = ""

# Lazy Initialization Engine
var _is_lifecycle_initialized: bool = false


func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	_spawn_point = spawn_pos
	
	# Compute a deterministic seed based on coordinate hashes
	npc_seed = abs(int(spawn_pos.x * 73856093) ^ int(spawn_pos.z * 19349663))
	
	# Pure Domain Model initialization and signals binding
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	add_to_group("passives")
	_execute_lifecycle_initialization()


## Centralized system setup. Safe to run from _ready() or as a physics fallback.
func _execute_lifecycle_initialization() -> void:
	if _is_lifecycle_initialized:
		return
	_is_lifecycle_initialized = true
	
	# ==========================================================================
	# PURE SOLID RESOLUTION (OCP/LSP)
	# Queries the abstract virtual method implemented by each subclass.
	# Completely decouples the base class from subclass file names.
	# ==========================================================================
	entity_name_key = _get_entity_name_key()
	
	# Cache components dynamically
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	_setup_quest_arrow()
	_setup_floating_bubble()
	
	# Scans coordinates to bind to designated campaign quests
	_auto_claim_registered_quest_target()


## Scans static JSON coordinates at birth to claim quest ownership polimorphically.
func _auto_claim_registered_quest_target() -> void:
	if QuestService._quests.is_empty():
		return
		
	for q_id: String in QuestService._quests.keys():
		var q := QuestService._quests[q_id] as Quest
		if q != null and q.target_position != Vector3.ZERO:
			var dist := global_position.distance_to(q.target_position)
			
			if dist <= 25.0:
				# OCP RESOLUTION: Delegate the eligibility verification polimorphically to subclasses.
				# Avoids hardcoding specific quest strings or matching rigid class names in the base class.
				if _is_eligible_for_quest(q_id):
					quest_target_id = q_id
					break


## Instantiates a dynamic Label3D billboard to display creature name above head.
func _setup_nameplate() -> void:
	if is_instance_valid(_nameplate):
		return 
		
	_nameplate = Label3D.new()
	_nameplate.name = "FloatingNameplate"
	
	_nameplate.text = tr(entity_name_key).to_upper()
	_nameplate.pixel_size = 0.005 
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false 
	_nameplate.render_priority = 5
	
	# LSP RESOLUTION: Query the abstract virtual method polimorphically.
	# Dynamically applies Red for hostiles and Green for passive/friendly.
	_nameplate.modulate = _get_nameplate_color()
	
	_nameplate.outline_modulate = Color(0, 0, 0)
	_nameplate.outline_size = 5
	_nameplate.position = Vector3(0.0, _collision_height + 0.35, 0.0)
	
	add_child(_nameplate)
	_apply_uniform_ui_scaling()


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col):
		var shape_height := 1.5
		if col.shape is CylinderShape3D:
			shape_height = col.shape.height
		elif col.shape is BoxShape3D:
			shape_height = col.shape.size.y
		elif col.shape is CapsuleShape3D:
			shape_height = col.shape.height
			
		# TRUE LOCAL HEIGHT SOLVER: Position.y + Half of (Raw Height * Local Scale)
		var local_y_center := col.position.y
		var scaled_half_height := (shape_height * col.scale.y) / 2.0
		
		_collision_height = local_y_center + scaled_half_height
	else:
		_collision_height = 1.5
		
	_setup_nameplate()
	
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


## Instantiates the 3D SpeechBubble and places it above the entity's head.
func _setup_floating_bubble() -> void:
	if is_conversational_npc and not is_instance_valid(_bubble):
		var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
		if sb_script != null:
			_bubble = sb_script.new() as Node3D
			add_child(_bubble)
			
			if entity_name_key == "NPC_NAME_MERCHANT":
				_bubble.call("set_text", tr("BUBBLE_TRADE"))
			elif entity_name_key == "NPC_NAME_FARMER":
				_bubble.call("set_text", tr("BUBBLE_FARMER"))
			else:
				_bubble.call("set_text", tr("BUBBLE_TALK"))
				
			# Guaranteed placement strictly above the computed collision boundary
			_bubble.position = Vector3(0.0, _collision_height + 0.65, 0.0)
			_apply_uniform_ui_scaling()


## Programmatically constructs the 3D rotating quest arrow (PrismMesh).
func _setup_quest_arrow() -> void:
	if is_instance_valid(_quest_arrow):
		return 
		
	_quest_arrow = MeshInstance3D.new()
	_quest_arrow.name = "FloatingQuestArrow"
	
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.45, 0.22)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.4
	mat.no_depth_test = true 
	mat.render_priority = 10
	
	prism.material = mat
	_quest_arrow.mesh = prism
	_quest_arrow.rotation.z = PI
	_quest_arrow.position = Vector3(0.0, _collision_height + 1.15, 0.0)
	_quest_arrow.visible = false
	
	add_child(_quest_arrow)
	_apply_uniform_ui_scaling()


func _build_visual_representation() -> void:
	pass


func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


# ==============================================================================
# UNIFORM SCALE MATRIX NORMALIZER
# ==============================================================================
func _apply_uniform_ui_scaling() -> void:
	var global_scale_vec := global_transform.basis.get_scale()
	
	if global_scale_vec.x < 0.001 or global_scale_vec.y < 0.001 or global_scale_vec.z < 0.001:
		return
		
	# Mathematically invert parent scaling matrix to lock global size at 1.0
	var inverse_scale := Vector3.ONE / global_scale_vec
	
	if is_instance_valid(_nameplate):
		_nameplate.scale = inverse_scale
		
	if is_instance_valid(_bubble):
		_bubble.scale = inverse_scale
		
	if is_instance_valid(_quest_arrow):
		_quest_arrow.scale = inverse_scale


# ==============================================================================
# SOLID POLYMORPHIC ABSTRACT HOOKS & FALLBACKS (OCP / LSP COMPLIANCE)
# ==============================================================================

## Abstract Virtual Method (LSP Contract): Returns the translation key representing 
## this specific entity's name. Must be implemented by every concrete subclass.
func _get_entity_name_key() -> String:
	assert(false, "[PassiveEntity] _get_entity_name_key() must be implemented by concrete subclass.")
	return ""


## Abstract Virtual Method (LSP Contract): Returns the color representing 
## this entity's nameplate (e.g., Green for friendly, Red for hostile).
## Must be implemented by every concrete subclass.
func _get_nameplate_color() -> Color:
	assert(false, "[PassiveEntity] _get_nameplate_color() must be implemented by concrete subclass.")
	return Color.WHITE


## Virtual physics tick hook. Overridden by subclasses (like Shark or Gargoyle)
## to execute customized physical translations without engine-level super chaining (Godot 4 Fix).
func _physics_tick(_delta: float) -> void:
	pass


## Virtual method to determine if this entity is eligible for a given quest ID.
## Overridden by subclasses to handle specific narrative campaign targeting.
func _is_eligible_for_quest(_quest_id: String) -> bool:
	return false


func _get_humanoid_role() -> int:
	return humanoid_role


func _has_ui_decorations() -> bool:
	return _get_humanoid_role() >= 0


func _get_habitat() -> int:
	return entity_habitat


func _is_avian() -> bool:
	return false


func _can_fly() -> bool:
	return _is_avian()


func _can_jump_to(target_coord: Vector3i) -> bool:
	var habitat := _get_habitat()
	if habitat == 2: # AQUATIC
		var world_controller_ref := get_parent()
		if is_instance_valid(world_controller_ref) and "world_state" in world_controller_ref:
			var ws: WorldState = world_controller_ref.world_state
			if ws != null:
				var block_type: int = ws.get_block(target_coord)
				return block_type == 6 # 6 = WATER
		return false
	return true 


func interact(_player_node: CharacterBody3D) -> void:
	pass


func start_talking(partner: CharacterBody3D) -> void:
	is_talking = true
	_talking_partner = partner
	velocity = Vector3.ZERO


func stop_talking() -> void:
	is_talking = false
	_talking_partner = null
	if is_instance_valid(ai_component):
		ai_component.task_timer = 1.0


## Tracks the direct attacker Node for karma deductions
func take_damage(amount: int, knockback_force: Vector3, attacker: Node = null) -> void:
	if domain_entity.is_dead: 
		return
	if is_talking:
		stop_talking()
		
	if is_instance_valid(attacker):
		_last_attacker = attacker
		
	_is_physically_sleeping = false
		
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	
	if is_instance_valid(ai_component):
		# AI component task state PANIC = 5
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)
		var angle := randf() * TAU
		ai_component.wander_direction = Vector3(cos(angle), 0, sin(angle))
		
		var role := _get_humanoid_role()
		var is_civilian: bool = (role == 0 or role == 1 or role == 3 or role == 4 or role == 5)
		
		if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
			var rep := VillageReputationService.instance
			if is_instance_valid(rep):
				rep.modify_reputation(-15)
			
	var closest_attacker := _find_closest_hostile_threat()
	if is_instance_valid(closest_attacker):
		AlertNetworkService.broadcast_alarm(closest_attacker, global_position)


## Proximity Scanner: Identifies the closest active zombie within an 8-meter combat radius
func _find_closest_hostile_threat() -> CharacterBody3D:
	if not is_inside_tree():
		return null
		
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	var closest: CharacterBody3D = null
	var min_dist_sq := 64.0
	
	for child: Node in hostiles:
		if child == self:
			continue
			
		if is_instance_valid(child):
			var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := global_position.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as CharacterBody3D
					
	return closest


# ==============================================================================
# DEATH SEQUENCE & LOOT ORCHESTRATION
# ==============================================================================
func _on_domain_entity_died() -> void:
	_try_drop_player_loot()
	remove_from_group("passives")
	
	set_physics_process(false)
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col):
		col.queue_free()
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	if is_instance_valid(_quest_arrow):
		_quest_arrow.queue_free()
	if is_instance_valid(_nameplate):
		_nameplate.queue_free()
		
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.unregister_defender(self)
		
	var role := _get_humanoid_role()
	var is_civilian: bool = (role == 0 or role == 1 or role == 3 or role == 4 or role == 5)
	
	if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
		var rep := VillageReputationService.instance
		if is_instance_valid(rep):
			rep.modify_reputation(-35)
		
	_spawn_death_particles()
	
	var death_tween := create_tween().set_parallel(true)
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		death_tween.tween_property(visual_component.visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_component.visual_root, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, 2.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	var world_node: Node = get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _try_drop_player_loot() -> void:
	var parent_node: Node = get_parent() as Node
	if is_instance_valid(parent_node):
		var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var inv: IInventory = player_node.get("inventory") as IInventory
			if is_instance_valid(inv):
				_drop_loot(inv)


func _drop_loot(_inv: IInventory) -> void:
	pass


## Projects the next physics step and cancels velocity if attempting to cross
## into an invalid habitat (e.g., land animals walking into deep oceans).
func _apply_absolute_boundary_forcefield(delta: float) -> void:
	var world_controller_ref := get_parent()
	if not is_instance_valid(world_controller_ref) or not "world_state" in world_controller_ref:
		return
		
	var ws: WorldState = world_controller_ref.world_state
	if ws == null:
		return
		
	var next_pos := global_position + velocity * delta
	var feet_coord := Vector3i(floori(next_pos.x), floori(next_pos.y + 0.1), floori(next_pos.z))
	
	var block_at_feet := ws.get_block(feet_coord)
	var block_below_feet := ws.get_block(feet_coord + Vector3i(0, -1, 0))
	
	var habitat := _get_habitat()
	var is_crossing := false
	
	if habitat == 2: # AQUATIC (Only Water)
		is_crossing = (block_at_feet != BlockType.Type.WATER and block_below_feet != BlockType.Type.WATER)
	elif habitat == 1: # AMPHIBIOUS (Water, Sand, Mud)
		var is_water_or_shore_at_feet := (
			block_at_feet == BlockType.Type.WATER or 
			block_at_feet == BlockType.Type.SAND or 
			block_at_feet == BlockType.Type.MUD
		)
		var is_water_or_shore_below := (
			block_below_feet == BlockType.Type.WATER or 
			block_below_feet == BlockType.Type.SAND or 
			block_below_feet == BlockType.Type.MUD
		)
		if not (is_water_or_shore_at_feet or is_water_or_shore_below):
			is_crossing = true
		elif block_at_feet == BlockType.Type.LAVA or block_below_feet == BlockType.Type.LAVA:
			is_crossing = true
	else: # TERRESTRIAL (No Water, No Lava, No Void)
		var is_liquid := (
			block_at_feet == BlockType.Type.WATER or 
			block_at_feet == BlockType.Type.LAVA or 
			block_below_feet == BlockType.Type.WATER or 
			block_below_feet == BlockType.Type.LAVA
		)
		
		if is_liquid:
			is_crossing = true
			
		elif block_below_feet == BlockType.Type.AIR and not _can_fly():
			var max_fall_scan := 3
			var solid_found := false
			for offset_y in range(2, max_fall_scan + 2):
				var check_y := feet_coord.y - offset_y
				if check_y < 0:
					break
				var block_type := ws.get_block(Vector3i(feet_coord.x, check_y, feet_coord.z))
				if block_type != BlockType.Type.AIR:
					solid_found = true
					break
			
			if not solid_found:
				is_crossing = true
		
	if is_crossing:
		velocity.x = 0.0
		velocity.z = 0.0


## Un-throttled physics and navigation compiler.
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	if not _is_lifecycle_initialized:
		_execute_lifecycle_initialization()
		
	if Engine.get_physics_frames() % 15 == 0:
		var player_node: CharacterBody3D = null
		var parent_node := get_parent()
		
		if is_instance_valid(parent_node) and "player" in parent_node:
			player_node = parent_node.get("player") as CharacterBody3D
			
		if is_instance_valid(player_node):
			var dist_sq := global_position.distance_squared_to(player_node.global_position)
			var sleep_state := dist_sq > 1600.0 # 40 meters
			
			if sleep_state != _is_physically_sleeping:
				_is_physically_sleeping = sleep_state
		else:
			_is_physically_sleeping = false
			
	if _is_physically_sleeping:
		velocity = Vector3.ZERO
		return
		
	var is_in_liquid := false
	var parent_node_ref := get_parent()
	if is_instance_valid(parent_node_ref) and "world_state" in parent_node_ref:
		var ws: WorldState = parent_node_ref.world_state
		if ws != null:
			var my_coord := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
			var block_at := ws.get_block(my_coord)
			var block_below := ws.get_block(my_coord + Vector3i(0, -1, 0))
			is_in_liquid = (block_at == 6 or block_at == 15 or block_below == 6 or block_below == 15)

	if not is_on_floor() and _get_habitat() != 2 and not is_in_liquid:
		velocity.y -= gravity * delta
	elif is_in_liquid:
		velocity.y = move_toward(velocity.y, 0.0, gravity * 0.5 * delta)
	else:
		velocity.y = -0.1

	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
	
	quest_check_timer -= delta
	if quest_check_timer <= 0.0:
		quest_check_timer = 0.5
		_update_quest_bubble_state()

	_apply_absolute_boundary_forcefield(delta)

	var flat_velocity := Vector2(velocity.x, velocity.z)

	if is_instance_valid(visual_representation):
		visual_representation.animate_movement(flat_velocity, is_on_floor(), delta)

	# SOLID RESOLUTION: Invoking the clean virtual physics tick hook
	_physics_tick(delta)

	move_and_slide()


func _get_task_state_name(task_val: int) -> String:
	var names := ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size():
		return names[task_val]
	return "IDLE"


## Symmetrical, OCP-compliant update method.
## Receives coordinates and updates nameplate labels and active indicators.
func _update_quest_bubble_state() -> void:
	var active_q := QuestService.get_active_quest()
	var is_target := false
	
	if active_q != null and quest_target_id == active_q.quest_id:
		is_target = true
		active_q.target_position = global_position 

	if is_instance_valid(_quest_arrow):
		_quest_arrow.visible = is_target

	# ----------------==================================================
	# DYNAMIC AI TASK STATE SUBTITLE (SOLID/OCP COMPLIANCE)
	# ----------------==================================================
	var task_subtitle := ""
	if is_instance_valid(ai_component):
		var active_task_name := "IDLE"
		var active_behavior: IAIBehavior = ai_component.active_behavior as IAIBehavior
		if active_behavior != null and active_behavior.has_method("get_active_state_name"):
			active_task_name = str(active_behavior.call("get_active_state_name", self))
		else:
			active_task_name = _get_task_state_name(ai_component.current_task)
			
		var lookup_key := active_task_name
		if lookup_key == "WANDERING":
			lookup_key = "WANDER"
		elif lookup_key == "CHATTING":
			lookup_key = "CHAT"
			
		var translated_name := tr("SHOWCASE_TASK_" + lookup_key).to_upper()
		task_subtitle = "\n[ " + translated_name + " ]"

	if is_instance_valid(_nameplate):
		var base_text := tr(entity_name_key).to_upper()
		if is_target:
			_nameplate.text = "⭐ " + base_text + " ⭐" + task_subtitle
			_nameplate.modulate = Color(1.0, 0.85, 0.2) # Gold Highlight for active quest target
			_nameplate.no_depth_test = true
		else:
			_nameplate.text = base_text + task_subtitle
			_nameplate.modulate = _get_nameplate_color() # Symmetrical OCP color
			_nameplate.no_depth_test = false

	_apply_uniform_ui_scaling()

	if not is_instance_valid(_bubble):
		return
			
	if is_target:
		_bubble.call("set_text", "⭐ [ " + tr("BUBBLE_ACTIVE_MISSION").to_upper() + " ] ⭐")
		return
		
	# Dynamic Text Router (OCP/SRP Compliant)
	if entity_name_key == "NPC_NAME_MERCHANT":
		_bubble.call("set_text", tr("BUBBLE_TRADE"))
	elif entity_name_key == "NPC_NAME_FARMER":
		_bubble.call("set_text", tr("BUBBLE_FARMER"))
	else:
		_bubble.call("set_text", tr("BUBBLE_TALK"))
