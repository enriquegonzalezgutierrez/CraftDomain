# ==============================================================================
# Project: CraftDomain
# Description: Abstract base class representing a physics-bound passive entity (NPC/Fauna).
#              Schedules procedural walk cycles, spatial state-machines, and variety.
# SOLID COMPLIANCE:
# - Liskov Substitution Principle (LSP): Serves as a robust base 
#   contract with safe default virtual values for subclasses.
# - Single Responsibility Principle (SRP): Decoupled into specialized 
#   components, leaving this class strictly in charge of sliding physics.
# - Dependency Inversion Principle (DIP): Visual structures are completely 
#   delegated to the injected `IEntityVisualRepresentation` strategy resource.
# JUMP ANIMATION INTEGRATION:
# - Updated `_setup_dynamic_visual_strategy` to dynamically feed the new 
#   `_jump.fbx` asset path into the skeletal strategy compiler.
# 3D FLOATING NAMEPLATES FEATURE (COLLISION-SAFE FIX):
# - Instantiates a native `Label3D` billboard nameplate displaying the creature's 
#   localized name in uppercase above its model.
# - RESOLVED SCENE-TREE NAME COLLISIONS: Resolves the translation keys dynamically 
#   by pattern-matching the class type (`self is ClassType`) rather than reading the 
#   node's scene-tree name, ensuring translations never break or show raw pointers.
# - Adjusts the height layout of Speech Bubbles and Quest Arrows to stack 
#   symmetrically and prevent text overlapping.
# FIXED COMPILATION STUTTER:
# - Corrected GPUParticles3D Material properties inside `_spawn_death_particles()` 
#   to use `scale_min` and `scale_max` instead of `scale_amount_min`.
# COMBAT ALERTS INTEGRATION (Phase 3):
# - Added dynamic threat-scanning and alarm broadcasting. Struck civilians find 
#   the closest hostile zombie and sound the alarm via `AlertNetworkService`.
# - Clears defenders from the alarm network during the death cleanup sequence.
# VILLAGE REPUTATION & KARMA INTEGRATION (Phase 4):
# - Modified `take_damage()` signature to accept an optional `attacker: Node` parameter.
# - Attacking peaceful civilians deducts -15 rep points from the player's karma.
# - Killing peaceful civilians deducts an additional -35 rep points (total of -50).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

# Base physics movement constants
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0

# Base animation asset root folder
const ANIM_DIR := "res://assets/models/mobs/"

# Sibling Component references (Composite Pattern)
var ai_component: NPCAIComponent
var visual_component: NPCVisualComponent

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# original Spawn Point used to anchor human NPCs so they never get lost (Tethering)
var _spawn_point: Vector3

# Dynamic floating Speech Bubble & Nameplate references
var _bubble: Node3D
var _nameplate: Label3D
var _quest_check_timer: float = 0.5

# 3D Floating Quest Indicator Arrow (Golden Prism pointing down)
var _quest_arrow: MeshInstance3D

# Deterministic unique Seed computed on coordinate hashes
var npc_seed: int = 0

# Injected Visual Representation Strategy (DIP Compliant)
var visual_representation: IEntityVisualRepresentation

# Cached height tracker for dynamic UI positioning
var _collision_height: float = 1.5

# ==============================================================================
# CONVERSATION STATE MACHINE: Dynamic player gaze-lock variables
# ==============================================================================
var is_talking: bool = false
var _talking_partner: CharacterBody3D = null

# Reputation and combat trackers
var _last_attacker: Node = null


func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	_spawn_point = spawn_pos
	
	# Compute a deterministic seed based on coordinate hashes (stable on reloading)
	npc_seed = abs(int(spawn_pos.x * 73856093) ^ int(spawn_pos.z * 19349663))
	
	# Pure Domain Model initialization and signals binding
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for O(1) targeting lookups
	add_to_group("passives")
	
	# Programmatic component compositions (Decoupling God files)
	ai_component = NPCAIComponent.new()
	add_child(ai_component)
	
	visual_component = NPCVisualComponent.new()
	add_child(visual_component)
	
	# ==========================================================================
	# DYNAMIC STRATEGY INJECTION (DIP/OCP Compliant)
	# ==========================================================================
	var role := _get_humanoid_role()
	if role >= 0:
		_setup_dynamic_visual_strategy(role)
		_setup_floating_bubble()
		_setup_quest_arrow()
	else:
		# Fallback for animals (Fauna) which manage their own visual representations
		_build_visual_representation()
		_setup_floating_bubble()
		_setup_quest_arrow()
		
	# Setup physics collision shape (Reads size from active strategy)
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	
	var size_scale := Vector3(1.0, visual_component.variant_height_scale, 1.0)
	
	# Query dynamic bounds from the injected strategy
	var col_size := Vector3(0.6, 0.8, 0.6) # Fallback
	var col_pos := Vector3(0.0, 0.4, 0.0) # Fallback
	
	if is_instance_valid(visual_representation):
		col_size = visual_representation.get_collision_box_size()
		col_pos = visual_representation.get_collision_box_position()
	else:
		col_size = _get_collision_box_size()
		col_pos = _get_collision_box_position()
		
	box_shape.size = col_size * size_scale
	col.shape = box_shape
	
	# ---> COLLISION CUSHION HOOK <---
	var target_pos := col_pos * visual_component.variant_height_scale
	target_pos.y -= 0.06 * visual_component.variant_height_scale
	col.position = target_pos
	
	add_child(col)
	
	# ==========================================================================
	# DYNAMIC COLLISION-AWARE ELEVATION & NAMEPLATE PIPELINE
	# ==========================================================================
	_collision_height = box_shape.size.y
	_setup_nameplate() # Instantiate the nameplate above head
	
	# Symmetrical Stacking Offset Heights to prevent overlaps
	if is_instance_valid(_bubble):
		_bubble.position = Vector3(0.0, _collision_height + 0.45, 0.0) # Lifted to clear nameplate
		
	if is_instance_valid(_quest_arrow):
		_quest_arrow.position = Vector3(0.0, _collision_height + 0.85, 0.0) # Lifted to clear bubble
	# ==========================================================================


## Sets up and injects the correct visual strategy based on disk file existence
func _setup_dynamic_visual_strategy(role: int) -> void:
	var role_name := _get_role_name_string(role)
	var fbx_path := "res://assets/models/mobs/" + role_name + "/" + role_name + "_base.fbx"
	
	if FileAccess.file_exists(fbx_path):
		# Instantiate and configure Skeletal Mixamo Strategy
		var strategy := SkeletalVisualRepresentation.new()
		strategy.base_model_path = fbx_path
		strategy.scale_multiplier = _get_role_scale(role)
		strategy.position_offset = Vector3(0.0, 0.0, 0.0)
		strategy.rotation_offset = Vector3(0, 180, 0)
		
		# Asset paths mapped dynamically including the newly added jump track
		strategy.anim_idle_path = ANIM_DIR + role_name + "/" + role_name + "_idle.fbx"
		strategy.anim_walk_path = ANIM_DIR + role_name + "/" + role_name + "_walk.fbx"
		strategy.anim_attack_path = ANIM_DIR + role_name + "/" + role_name + "_attack.fbx"
		strategy.anim_panic_path = ANIM_DIR + role_name + "/" + role_name + "_panic.fbx"
		strategy.anim_jump_path = ANIM_DIR + role_name + "/" + role_name + "_jump.fbx"
		
		visual_representation = strategy
	else:
		# Instantiate and configure Procedural Voxel Strategy
		var strategy := ProceduralVoxelRepresentation.new()
		strategy.role_type = role as ProceduralVoxelRepresentation.RoleType
		visual_representation = strategy
		
	# Build the representation
	if is_instance_valid(visual_representation):
		visual_representation.build_representation(self, visual_component.body_bob_node)


## Instantiates a native, high-performance Label3D billboard to display creature name
func _setup_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.name = "FloatingNameplate"
	
	# ==========================================================================
	# POLYMORPHIC TYPE PATTERN RESOLUTION
	# Maps class patterns directly to stable translations keys to bypass scene-tree name-collisions.
	# ==========================================================================
	var key := "NPC_NAME_VILLAGER" # Default Fallback
	
	if self is VillagerEntity: key = "NPC_NAME_VILLAGER"
	elif self is MerchantEntity: key = "NPC_NAME_MERCHANT"
	elif self is GuardEntity: key = "NPC_NAME_GUARD"
	elif self is FarmerEntity: key = "NPC_NAME_FARMER"
	elif self is MinerEntity: key = "NPC_NAME_MINER"
	elif self is DruidEntity: key = "NPC_NAME_DRUID"
	elif self is CyberCitizenEntity: key = "NPC_NAME_ANDROID"
	elif self is GolemEntity: key = "NPC_NAME_GOLEM"
	elif self is PigEntity: key = "NPC_NAME_PIG"
	elif self is ChickenEntity: key = "NPC_NAME_CHICKEN"
	elif self is SheepEntity: key = "NPC_NAME_SHEEP"
	elif self is CowEntity: key = "NPC_NAME_COW"
	elif self is TurtleEntity: key = "NPC_NAME_TURTLE"
	elif self is FoxEntity: key = "NPC_NAME_FOX"
	elif self is BirdEntity: key = "NPC_NAME_BIRD"
	elif self is CatEntity: key = "NPC_NAME_CAT"
	elif self is ParrotEntity: key = "NPC_NAME_PARROT"
	elif self is CrabEntity: key = "NPC_NAME_CRAB"
	elif self is ElephantEntity: key = "NPC_NAME_ELEPHANT"
	elif self is OctopusEntity: key = "NPC_NAME_OCTOPUS"
	elif self is RaccoonEntity: key = "NPC_NAME_RACCOON"
	elif self is GrowlitheEntity: key = "NPC_NAME_GROWLITHE"
	elif self is MonkeyEntity: key = "NPC_NAME_MONKEY"
	
	_nameplate.text = tr(key).to_upper()
	_nameplate.pixel_size = 0.005 # Crisp, matching speech bubble sizing scale
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false # Occluded by solid blocks
	_nameplate.render_priority = 5
	
	# Text styling and high-contrast outline
	_nameplate.modulate = Color(1.0, 1.0, 1.0)
	_nameplate.outline_modulate = Color(0, 0, 0)
	_nameplate.outline_size = 5
	
	# Set position right above the model head
	_nameplate.position = Vector3(0.0, _collision_height + 0.15, 0.0)
	add_child(_nameplate)


func _build_visual_representation() -> void:
	assert(false, "[PassiveEntity] _build_visual_representation() must be implemented by concrete subclass.")


func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _setup_floating_bubble() -> void:
	pass


## Virtual method overridden by subclasses to define their humanoid role.
## Returns -1 for animals (fauna), or a specific RoleType index for humanoids.
func _get_humanoid_role() -> int:
	return -1


## Programmatically constructs and styles the 3D rotating quest arrow (PrismMesh)
func _setup_quest_arrow() -> void:
	_quest_arrow = MeshInstance3D.new()
	_quest_arrow.name = "FloatingQuestArrow"
	
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.45, 0.22)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2) # Golden Yellow
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.4
	
	mat.no_depth_test = true
	mat.render_priority = 10
	
	prism.material = mat
	_quest_arrow.mesh = prism
	_quest_arrow.rotation.z = PI
	
	# Default fallback height (will be overwritten dynamically in _ready())
	_quest_arrow.position = Vector3(0.0, 2.5, 0.0)
	_quest_arrow.visible = false # Hidden by default
	
	add_child(_quest_arrow)


func interact(_player: CharacterBody3D) -> void:
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


## Modified take_damage signature to track and remember the direct attacker Node
func take_damage(amount: int, knockback_force: Vector3, attacker: Node = null) -> void:
	if domain_entity.is_dead: 
		return
	if is_talking:
		stop_talking()
		
	if is_instance_valid(attacker):
		_last_attacker = attacker
		
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	
	# Force Panic state override on taking damage
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)
		var angle := randf() * TAU
		ai_component.wander_direction = Vector3(cos(angle), 0, sin(angle))
		
	# Determine if the victim is a civilian to deduct reputation points
	var is_civilian: bool = (
		self is VillagerEntity or 
		self is MerchantEntity or 
		self is FarmerEntity or 
		self is MinerEntity or 
		self is DruidEntity or 
		self is CyberCitizenEntity
	)
	
	# ==========================================================================
	# PLAYER KARMA PUNISHMENT: DEDUCT ON DAMAGE (Phase 4)
	# Hitting peaceful civilians deducts -15 points of reputation instantly
	# ==========================================================================
	if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
		var rep := VillageReputationService.instance
		if is_instance_valid(rep):
			rep.modify_reputation(-15)
		
	# ==========================================================================
	# PROACTIVE COMBAT ALARM BROADCAST (Phase 3)
	# Locate closest attacking zombie and notify nearby defenders through network
	# ==========================================================================
	var closest_attacker := _find_closest_hostile_threat()
	if is_instance_valid(closest_attacker):
		AlertNetworkService.broadcast_alarm(closest_attacker, global_position)


## Proximity Scanner: Identifies the closest active zombie within an 8-meter combat radius
func _find_closest_hostile_threat() -> CharacterBody3D:
	if not is_inside_tree():
		return null
		
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	var closest: CharacterBody3D = null
	var min_dist_sq := 64.0 # 8 meters squared sight limit
	
	for child: Node in hostiles:
		if is_instance_valid(child) and child is CharacterBody3D:
			var zombie_domain := child.get("domain_entity") as VoxelEntity
			if zombie_domain != null and not zombie_domain.is_dead:
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
	
	# HIGH PERFORMANCE: Unregister instantly from group on death
	remove_from_group("passives")
	
	# 1. Disable physics and interactions instantly
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
		
	# Unregister from active alert pools on death
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net):
		alert_net.unregister_defender(self)
		
	# ==========================================================================
	# PLAYER KARMA PUNISHMENT: DEDUCT ON MURDER (Phase 4)
	# Killing peaceful civilians deducts an additional -35 points (total -50)
	# ==========================================================================
	var is_civilian: bool = (
		self is VillagerEntity or 
		self is MerchantEntity or 
		self is FarmerEntity or 
		self is MinerEntity or 
		self is DruidEntity or 
		self is CyberCitizenEntity
	)
	if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
		var rep := VillageReputationService.instance
		if is_instance_valid(rep):
			rep.modify_reputation(-35)
		
	# 2. Spawn death particles (Smoke puff)
	_spawn_death_particles()
	
	# 3. Animate visual components shrinking and spinning into oblivion
	var death_tween := create_tween().set_parallel(true)
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		death_tween.tween_property(visual_component.visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_component.visual_root, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	# 4. Erase entity safely from memory
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
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8) # Smoke grey
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


## Virtual Method (LSP): Subclasses override this to implement concrete drops.
func _drop_loot(_inv: IInventory) -> void:
	pass


# ==============================================================================
# MAIN PHYSICS CALCULATIONS & ANIMAITONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	# Apply downward gravity conditionally
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	# Process AI component decision tree calculations
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
	
	_quest_check_timer -= delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = 0.5
		_update_quest_bubble_state()

	# ANIMATE QUEST ARROW (Rotation on Y axis & float bounce up/down)
	if is_instance_valid(_quest_arrow) and _quest_arrow.visible:
		_quest_arrow.rotate_y(delta * 2.5) # Spin
		var bounce := sin(Time.get_ticks_msec() / 250.0) * 0.12
		_quest_arrow.position.y = _collision_height + 0.85 + bounce # Updated

	# Delegate dynamic skeletal movements to the injected strategy
	if is_instance_valid(visual_representation):
		var flat_velocity := Vector2(velocity.x, velocity.z)
		visual_representation.animate_movement(flat_velocity, is_on_floor(), delta)

	move_and_slide()


func _update_quest_bubble_state() -> void:
	var active_q := QuestService.get_active_quest()
	var is_target := false
	
	if active_q != null:
		if active_q.quest_id == "lost_bazaar" and name.contains("VILLAGER"):
			is_target = true
		elif active_q.quest_id == "fuel_fryer" and name.contains("MERCHANT"):
			is_target = true
		elif active_q.quest_id == "plains_defender" and name.contains("GUARD"):
			is_target = true

	# Toggle the 3D glowing arrow visibility dynamically
	if is_instance_valid(_quest_arrow):
		_quest_arrow.visible = is_target

	if not is_instance_valid(_bubble):
		return
			
	if is_target:
		_bubble.call("set_text", "⭐ [ " + tr("BUBBLE_ACTIVE_MISSION").to_upper() + " ] ⭐")
		return
			
	if name.contains("VILLAGER"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("MERCHANT"):
		_bubble.call("set_text", tr("BUBBLE_TRADE"))
	elif name.contains("GUARD"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("FARMER"):
		_bubble.call("set_text", tr("BUBBLE_FARMER"))


func _can_socialize() -> bool:
	return false


func _is_avian() -> bool:
	return false


# ==============================================================================
# STRATEGY SELECTION UTILITIES (OCP/DIP Helper mappings)
# ==============================================================================

func _get_role_name_string(role: int) -> String:
	match role:
		0: return "villager"
		1: return "merchant"
		2: return "guard"
		3: return "farmer"
		4: return "miner"
		5: return "druid"
		6: return "golem"
	return "villager"


func _get_role_scale(role: int) -> Vector3:
	match role:
		2: return Vector3(0.8507, 0.8507, 0.8507) # Guard perfect scale
		3: return Vector3(0.8665, 0.8665, 0.8665) # Farmer perfect scale
		0: return Vector3(0.8856, 0.8856, 0.8856) # Villager perfect scale
	return Vector3.ONE
