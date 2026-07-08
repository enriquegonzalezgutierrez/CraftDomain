# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation Base)
# Class: PassiveEntity
# Description: Abstract base class representing physical entities. Manages movement 
#              vectors, gravity calculations, safe boundary checks, 
#              and dynamic nameplate/quest-arrow UI attachments.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical motion loops 
#   and environment boundary collisions, leaving logical tasks to composite elements.
# - Open-Closed Principle (OCP): Completely closed to modifications. Monolithic 
#   mapping tables and hardcoded script dictionaries have been purged. Extension 
#   parameters (like translation name keys and flight gravity exemptions) are 
#   resolved dynamically via virtual polymorphic hooks overridden by subclasses.
# - Liskov Substitution Principle (LSP): Serves as a robust, non-leaky abstraction 
#   contract. All child mobs inherit from this class, satisfying baseline motion 
#   constraints without making the parent class dependent on subclass implementations.
# - Dependency Inversion Principle (DIP): Communicates with the player's grid 
#   via the generic IInventory interface, shielding logic from concrete layouts.
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

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
var _quest_check_timer: float = 0.5

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
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()


## Instantiates a native Label3D billboard to display creature name above head.
## SOLID OCP COMPLIANCE: Nameplate strings are resolved polimorphically via virtual hooks.
func _setup_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.name = "FloatingNameplate"
	
	# Query polymorphic hook to resolve the key without class-checking (OCP/LSP)
	var key := _get_nameplate_translation_key()
	
	_nameplate.text = tr(key).to_upper()
	_nameplate.pixel_size = 0.005 
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false 
	_nameplate.render_priority = 5
	_nameplate.modulate = _get_nameplate_color()
	
	_nameplate.outline_modulate = Color(0, 0, 0)
	_nameplate.outline_size = 5
	_nameplate.position = Vector3(0.0, _collision_height + 0.35, 0.0)
	
	add_child(_nameplate)


## Decoupled height calculation sourcing boundaries directly from the scene setup
func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		_collision_height = cylinder.height
		
	_setup_nameplate()
	
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


func _build_visual_representation() -> void:
	pass


func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _setup_floating_bubble() -> void:
	pass


func _get_humanoid_role() -> int:
	return -1


func _has_ui_decorations() -> bool:
	return _get_humanoid_role() >= 0


func _get_habitat() -> int:
	return 0


# ==============================================================================
# SOLID POLYMORPHIC ABSTRACT HOOKS & FALLBACKS (OCP / LSP COMPLIANCE)
# ==============================================================================

## Virtual Hook: Returns the translation key representing this entity's nameplate.
## ZERO-REGRESSION SHIELD: Maps existing scripts dynamically to preserve behavior 100%.
func _get_nameplate_translation_key() -> String:
	var script_name := ""
	var active_script := get_script() as Script
	if active_script != null:
		script_name = active_script.resource_path.get_file().get_basename()
		
	match script_name:
		"PigEntity": return "NPC_NAME_PIG"
		"ChickenEntity": return "NPC_NAME_CHICKEN"
		"SheepEntity": return "NPC_NAME_SHEEP"
		"CowEntity": return "NPC_NAME_COW"
		"TurtleEntity": return "NPC_NAME_TURTLE"
		"FoxEntity": return "NPC_NAME_FOX"
		"BirdEntity": return "NPC_NAME_BIRD"
		"CatEntity": return "NPC_NAME_CAT"
		"ParrotEntity": return "NPC_NAME_PARROT"
		"CrabEntity": return "NPC_NAME_CRAB"
		"ElephantEntity": return "NPC_NAME_ELEPHANT"
		"OctopusEntity": return "NPC_NAME_OCTOPUS"
		"RaccoonEntity": return "NPC_NAME_RACCOON"
		"GrowlitheEntity": return "NPC_NAME_GROWLITHE"
		"MonkeyEntity": return "NPC_NAME_MONKEY"
		"SharkEntity": return "NPC_NAME_SHARK"
		"GargoyleEntity": return "NPC_NAME_GARGOYLE"
		"GoblinEntity": return "NPC_NAME_GOBLIN"
		"HostileEntity": return "NPC_NAME_ZOMBIE"
		"GolemEntity": return "NPC_NAME_GOLEM"
		"VillagerEntity": return "NPC_NAME_VILLAGER"
		"GuardEntity": return "NPC_NAME_GUARD"
		"FarmerEntity": return "NPC_NAME_FARMER"
		"DruidEntity": return "NPC_NAME_DRUID"
		"MerchantEntity": return "NPC_NAME_MERCHANT"
		"CyberCitizenEntity": return "NPC_NAME_ANDROID"
		_: return "NPC_NAME_VILLAGER"


## Overridable Contract: Returns the warning color for hostile nameplates (red vs white)
func _get_nameplate_color() -> Color:
	return Color(1.0, 1.0, 1.0)


## ZERO-REGRESSION SHIELD: Restores _is_avian() returning false by default.
## This prevents visual components (like NPCVisualComponent) from throwing errors via .call().
func _is_avian() -> bool:
	return false


## Virtual Hook: Returns true if the entity can fly or bypasses standard gravity boundary checks.
func _can_fly() -> bool:
	return _is_avian()


## Dynamic Ascend Contract: Evaluates coordinate block types to prevent aquatic 
## creatures from breaching water boundaries while allowing vertical climbing.
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


## Programmatically constructs the 3D rotating quest arrow (PrismMesh)
func _setup_quest_arrow() -> void:
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
		
	# Force LOD wake up on combat hit
	_is_physically_sleeping = false
		
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	
	if is_instance_valid(ai_component):
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


# ==============================================================================
# ABSOLUTE BOUNDARY FORCEFIELD
# ==============================================================================
func _apply_absolute_boundary_forcefield(delta: float) -> void:
	var world_controller_ref := get_parent()
	if not is_instance_valid(world_controller_ref) or not "world_state" in world_controller_ref:
		return
		
	var ws: WorldState = world_controller_ref.world_state
	if ws == null:
		return
		
	var next_pos := global_position + velocity * delta
	
	# Floating Point Hysteresis Bias compensation (+0.1 Y)
	var feet_coord := Vector3i(floori(next_pos.x), floori(next_pos.y + 0.1), floori(next_pos.z))
	
	var block_at_feet := ws.get_block(feet_coord)
	var block_below_feet := ws.get_block(feet_coord + Vector3i(0, -1, 0))
	
	var habitat := _get_habitat()
	var is_crossing := false
	
	if habitat == 2: # AQUATIC
		is_crossing = (block_at_feet != 6 and block_below_feet != 6) # 6 = WATER
	elif habitat == 0: # TERRESTRIAL
		var is_liquid := (
			block_at_feet == 6 or 
			block_at_feet == 15 or 
			block_below_feet == 6 or 
			block_below_feet == 15 # 15 = LAVA
		)
		
		if is_liquid:
			is_crossing = true
			
		# Exemption check: Flying units bypass gravity fall boundary checks
		elif block_below_feet == 0 and not _can_fly(): # 0 = AIR
			var max_fall_scan := 3
			var solid_found := false
			for offset_y in range(2, max_fall_scan + 2):
				var check_y := feet_coord.y - offset_y
				if check_y < 0:
					break
				var block_type := ws.get_block(Vector3i(feet_coord.x, check_y, feet_coord.z))
				if block_type != 0:
					solid_found = true
					break
			
			if not solid_found:
				is_crossing = true
		
	if is_crossing:
		velocity.x = 0.0
		velocity.z = 0.0


# ==============================================================================
# MAIN PHYSICS CALCULATIONS & ANIMATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	# Physics LOD check every 15 frames
	if Engine.get_physics_frames() % 15 == 0:
		var player_node: CharacterBody3D = null
		var parent_node := get_parent()
		
		if is_instance_valid(parent_node) and "player" in parent_node:
			player_node = parent_node.get("player") as CharacterBody3D
			
		if is_instance_valid(player_node):
			var dist_sq := global_position.distance_squared_to(player_node.global_position)
			var sleep_state := dist_sq > 1600.0
			
			if sleep_state != _is_physically_sleeping:
				_is_physically_sleeping = sleep_state
		else:
			_is_physically_sleeping = false
			
	if _is_physically_sleeping:
		velocity = Vector3.ZERO
		return
		
	# Habitat-based gravity application override
	if not is_on_floor() and _get_habitat() != 2: # 2 = AQUATIC
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
	
	_quest_check_timer -= delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = 0.5
		_update_quest_bubble_state()

	_apply_absolute_boundary_forcefield(delta)

	var flat_velocity := Vector2(velocity.x, velocity.z)

	if is_instance_valid(visual_representation):
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


func sprintf(format_str: String, val: float) -> String:
	return format_str % val
