# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/PassiveEntity.gd
# Description: Abstract physical character controller representing mobile entities.
#              Coordinates locomotion, buoyancy, damage reactions, and quest targets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

const BASE_SPEED: float = 2.6
const JUMP_VELOCITY: float = 5.0
const GROUND_SNAP_VELOCITY: float = 0.0 # STABILITY FIX: Avoid perpetual downward forces
const SLEEP_DISTANCE_SQ: float = 1600.0
const THREAT_SEARCH_RADIUS_SQ: float = 64.0
const REPUTATION_DAMAGE_PENALTY: int = -15
const REPUTATION_MURDER_PENALTY: int = -35

@export var is_conversational_npc: bool = false
@export var humanoid_role: int = -1
@export var entity_habitat: int = 0

var entity_name_key: String = ""
var ai_component: NPCAIComponent
var visual_component: NPCVisualComponent
var domain_entity: VoxelEntity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _spawn_point: Vector3
var quest_check_timer: float = 0.5
var npc_seed: int = 0

var visual_representation: IEntityVisualRepresentation
var _collision_height: float = 1.5

var is_talking: bool = false
var _talking_partner: CharacterBody3D = null
var _last_attacker: Node = null
var _is_physically_sleeping: bool = false

var quest_target_id: String = ""
var _is_lifecycle_initialized: bool = false
var _ui_component: EntityUIComponent

var _slope_pitch: float = 0.0
var _slope_roll: float = 0.0

@warning_ignore("unused_private_class_variable")
var _nameplate: Label3D
@warning_ignore("unused_private_class_variable")
var _bubble: Node3D
@warning_ignore("unused_private_class_variable")
var _quest_arrow: MeshInstance3D


func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	_spawn_point = spawn_pos
	npc_seed = abs(int(spawn_pos.x * 73856093) ^ int(spawn_pos.z * 19349663))
	
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	add_to_group("passives")
	_execute_lifecycle_initialization()


func _execute_lifecycle_initialization() -> void:
	if _is_lifecycle_initialized: return
	_is_lifecycle_initialized = true
	
	entity_name_key = _get_entity_name_key()
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	_setup_ui_component()


func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col):
		var shape_height := 1.5
		if col.shape is CylinderShape3D or col.shape is CapsuleShape3D:
			shape_height = col.shape.height
		elif col.shape is BoxShape3D:
			shape_height = col.shape.size.y
			
		_collision_height = col.position.y + ((shape_height * col.scale.y) / 2.0)
	else:
		_collision_height = 1.5


func _setup_ui_component() -> void:
	_ui_component = EntityUIComponent.new()
	add_child(_ui_component)
	_ui_component.initialize(self, _collision_height)


func _get_entity_name_key() -> String:
	assert(false, "[PassiveEntity] _get_entity_name_key() must be implemented.")
	return ""


func _get_nameplate_color() -> Color:
	assert(false, "[PassiveEntity] _get_nameplate_color() must be implemented.")
	return Color.WHITE


func _physics_tick(_delta: float) -> void:
	pass


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
	if _get_habitat() == 2: 
		var parent_node := get_parent()
		if is_instance_valid(parent_node) and "world_state" in parent_node:
			var ws: WorldState = parent_node.world_state
			if is_instance_valid(ws): return ws.get_block(target_coord) == BlockType.Type.WATER 
		return false
	return true 


func _is_block_type_habitable(block_type: BlockType.Type) -> bool:
	return block_type != BlockType.Type.WATER and block_type != BlockType.Type.LAVA


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


func take_damage(amount: int, knockback_force: Vector3, attacker: Node = null) -> void:
	if domain_entity.is_dead: return
	if is_talking: stop_talking()
		
	if is_instance_valid(attacker): _last_attacker = attacker
	_is_physically_sleeping = false
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	_trigger_damage_panic_state()
	_broadcast_threat_alarm()


func _trigger_damage_panic_state() -> void:
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)
		var angle := randf() * TAU
		ai_component.wander_direction = Vector3(cos(angle), 0, sin(angle))
		_apply_civilian_reputation_penalty(REPUTATION_DAMAGE_PENALTY)


func _apply_civilian_reputation_penalty(penalty: int) -> void:
	var role := _get_humanoid_role()
	var is_civilian: bool = (role == 0 or role == 1 or role == 3 or role == 4 or role == 5)
	if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
		var rep := VillageReputationService.instance
		if is_instance_valid(rep): rep.modify_reputation(penalty)


func _broadcast_threat_alarm() -> void:
	var closest_attacker := _find_closest_hostile_threat()
	if is_instance_valid(closest_attacker):
		AlertNetworkService.broadcast_alarm(closest_attacker, global_position)


func _find_closest_hostile_threat() -> CharacterBody3D:
	if not is_inside_tree(): return null
	var closest: CharacterBody3D = null
	var min_dist_sq := THREAT_SEARCH_RADIUS_SQ
	
	for child: Node in get_tree().get_nodes_in_group("hostiles"):
		if child == self or not is_instance_valid(child): continue
		var domain: VoxelEntity = child.get("domain_entity") as VoxelEntity
		if domain != null and not domain.is_dead:
			var dist_sq := global_position.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest = child as CharacterBody3D
				
	return closest


func _on_domain_entity_died() -> void:
	_try_drop_player_loot()
	remove_from_group("passives")
	set_physics_process(false)
	_cleanup_physics_shapes()
	_spawn_death_particles()
	_apply_death_animations_and_free()


func _cleanup_physics_shapes() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col): col.queue_free()
		
	if is_instance_valid(_ui_component):
		_ui_component.cleanup()
		_ui_component.queue_free()
		
	var alert_net := AlertNetworkService.instance
	if is_instance_valid(alert_net): alert_net.unregister_defender(self)
	
	var job_service := JobReservationService.instance
	if is_instance_valid(job_service):
		job_service.release_all_jobs_for_worker(get_instance_id())
		
	_apply_civilian_reputation_penalty(REPUTATION_MURDER_PENALTY)


func _apply_death_animations_and_free() -> void:
	var death_tween := create_tween().set_parallel(true)
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		death_tween.tween_property(visual_component.visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_component.visual_root, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particles := CPUParticles3D.new()
	_configure_death_particle_properties(particles)
	_attach_death_particle_mesh(particles)
	
	particles.finished.connect(particles.queue_free)
	var world_node := get_parent()
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
		particles.emitting = true


func _configure_death_particle_properties(particles: CPUParticles3D) -> void:
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, 2.0, 0)


func _attach_death_particle_mesh(particles: CPUParticles3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mesh.material = mat
	particles.mesh = mesh


func _try_drop_player_loot() -> void:
	var parent_node: Node = get_parent() as Node
	if is_instance_valid(parent_node):
		var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var inv: IInventory = player_node.get("inventory") as IInventory
			if is_instance_valid(inv): _drop_loot(inv)


func _drop_loot(_inv: IInventory) -> void:
	pass


func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: return
	if not _is_lifecycle_initialized: _execute_lifecycle_initialization()
		
	_update_sleeping_state()
	if _is_physically_sleeping:
		velocity = Vector3.ZERO
		return
		
	_apply_environmental_physics(delta)
	_process_ai_and_boundaries(delta)
	_apply_procedural_slope_tilt(delta)
	_apply_visual_movement_and_slide(delta)


func _update_sleeping_state() -> void:
	if Engine.get_physics_frames() % 15 == 0:
		var parent_node := get_parent()
		var player_node: CharacterBody3D = parent_node.get("player") as CharacterBody3D if is_instance_valid(parent_node) and "player" in parent_node else null
		_is_physically_sleeping = is_instance_valid(player_node) and global_position.distance_squared_to(player_node.global_position) > SLEEP_DISTANCE_SQ


func _apply_environmental_physics(delta: float) -> void:
	var is_submerged := _check_in_liquid_state()
	if _can_fly() and not is_submerged:
		var flight_state := get_meta("avian_flight_state") as int if has_meta("avian_flight_state") else 0
		if flight_state != 2: return
			
	if (not is_on_floor() or is_submerged) and _get_habitat() != 2 and not is_submerged:
		velocity.y -= gravity * delta
	elif is_submerged:
		_apply_liquid_buoyancy(delta)
	else:
		velocity.y = GROUND_SNAP_VELOCITY # GROUNDING STABILIZATION FIXED (0.0 m/s)


func _apply_liquid_buoyancy(delta: float) -> void:
	var habitat := _get_habitat()
	if habitat == 2: velocity.y = move_toward(velocity.y, 0.0, gravity * 0.5 * delta)
	elif habitat == 1: velocity.y = move_toward(velocity.y, -0.2, gravity * 0.5 * delta)
	else: velocity.y = move_toward(velocity.y, -1.8, gravity * 0.5 * delta)


func is_in_liquid() -> bool:
	return _check_in_liquid_state()


func _check_in_liquid_state() -> bool:
	var parent_node_ref := get_parent()
	if is_instance_valid(parent_node_ref) and "world_state" in parent_node_ref:
		var ws: WorldState = parent_node_ref.world_state
		if ws != null:
			var my_coord := Vector3i(floori(global_position.x), floori(global_position.y + 0.2), floori(global_position.z))
			return (ws.get_block(my_coord) == 6 or ws.get_block(my_coord) == 15 or ws.get_block(my_coord + Vector3i(0, -1, 0)) == 6 or ws.get_block(my_coord + Vector3i(0, -1, 0)) == 15)
	return false


func _process_ai_and_boundaries(delta: float) -> void:
	if is_instance_valid(ai_component): ai_component.process_ai(delta)
	_apply_absolute_boundary_forcefield(delta)
	
	quest_check_timer -= delta
	if quest_check_timer <= 0.0:
		quest_check_timer = 0.5
		_update_quest_bubble_state()
		_update_floating_nameplate_unconditional()


func _update_floating_nameplate_unconditional() -> void:
	if is_instance_valid(_ui_component):
		_ui_component.update_ui_state(QuestService.get_active_quest() as Quest, quest_target_id)


func _update_quest_bubble_state() -> void:
	if not is_instance_valid(_ui_component): return
	var active_quest := QuestService.get_active_quest() as Quest
	var ws := _get_world_state_ref()
	
	if active_quest == null or ws == null:
		quest_target_id = ""
		_ui_component.update_ui_state(null, "")
		return
		
	if ws.active_quest_target_node == self:
		if active_quest.quest_id != quest_target_id:
			ws.active_quest_target_node = null
			quest_target_id = ""
			_ui_component.update_ui_state(active_quest, "")
			return
			
		active_quest.target_position = global_position
		_ui_component.update_ui_state(active_quest, active_quest.quest_id)
	else:
		_evaluate_quest_target_proximity(active_quest, ws)


func _evaluate_quest_target_proximity(active_quest: Quest, ws: WorldState) -> void:
	var target_node := ws.active_quest_target_node
	if is_instance_valid(target_node) and not target_node.domain_entity.is_dead:
		quest_target_id = ""
		_ui_component.update_ui_state(active_quest, "")
		return
		
	if global_position.distance_to(active_quest.target_position) <= 25.0 and _is_eligible_for_quest(active_quest.quest_id):
		quest_target_id = active_quest.quest_id
		ws.active_quest_target_node = self
		active_quest.target_position = global_position
		_ui_component.update_ui_state(active_quest, active_quest.quest_id)
	else:
		quest_target_id = ""
		_ui_component.update_ui_state(active_quest, "")


func _get_world_state_ref() -> WorldState:
	var parent := get_parent()
	if is_instance_valid(parent) and "world_state" in parent:
		return parent.world_state as WorldState
	return null


func _apply_absolute_boundary_forcefield(delta: float) -> void:
	var world_ctrl := get_parent()
	if not is_instance_valid(world_ctrl) or not "world_state" in world_ctrl: return
	var ws: WorldState = world_ctrl.world_state
	if ws == null: return
		
	var next_pos := global_position + velocity * delta
	var feet_coord := Vector3i(floori(next_pos.x), floori(next_pos.y + 0.1), floori(next_pos.z))
	_enforce_habitat_boundary(ws, feet_coord)


func _enforce_habitat_boundary(ws: WorldState, feet_coord: Vector3i) -> void:
	var is_feet_safe := _is_block_type_habitable(ws.get_block(feet_coord))
	var is_below_safe := _is_block_type_habitable(ws.get_block(feet_coord + Vector3i(0, -1, 0)))
	
	if not is_feet_safe and not is_below_safe:
		velocity.x = 0.0
		velocity.z = 0.0
		set_meta("diag_hab_blk", true)
	else:
		set_meta("diag_hab_blk", false)
		
	if _get_habitat() == 2 and ws.get_block(feet_coord) == BlockType.Type.AIR:
		velocity.y = -2.5


func _apply_procedural_slope_tilt(delta: float) -> void:
	if humanoid_role != -1 or not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var target_pitch := 0.0
	var target_roll := 0.0
	
	if is_on_floor() and get_floor_normal() != Vector3.ZERO:
		var normal := get_floor_normal()
		var visual_root := visual_component.visual_root
		if is_instance_valid(visual_root):
			var forward := -visual_root.global_transform.basis.z.normalized()
			var right := visual_root.global_transform.basis.x.normalized()
			target_pitch = -forward.dot(normal) * 0.95
			target_roll = right.dot(normal) * 0.95
			
	_slope_pitch = lerp(_slope_pitch, target_pitch, delta * 12.0)
	_slope_roll = lerp(_slope_roll, target_roll, delta * 12.0)
	
	var bob_node := visual_component.body_bob_node
	bob_node.rotation.x = _slope_pitch
	bob_node.rotation.z = _slope_roll


func _apply_visual_movement_and_slide(delta: float) -> void:
	var flat_velocity := Vector2(velocity.x, velocity.z)
	if is_instance_valid(visual_representation):
		visual_representation.animate_movement(flat_velocity, is_on_floor(), delta)
		
	_physics_tick(delta)
	
	var vel_b4 := velocity
	var collided := move_and_slide()
	var vel_aft := velocity
	
	if Engine.get_physics_frames() % 15 == 0:
		_dispatch_deep_telemetry(vel_b4, vel_aft, collided)


func _dispatch_deep_telemetry(vel_b4: Vector3, vel_aft: Vector3, collided: bool) -> void:
	var task_name := "IDLE"
	var dir := Vector3.ZERO
	
	if is_instance_valid(ai_component):
		dir = ai_component.wander_direction
		var active_b: Resource = ai_component.get("active_behavior") as Resource
		if active_b != null and active_b.has_method("get_active_state_name"):
			task_name = str(active_b.call("get_active_state_name", self))
		else:
			task_name = ai_component.get_task_state_name(int(ai_component.current_task))
			
	var flags: Dictionary = {
		"hab_blk": bool(get_meta("diag_hab_blk")) if has_meta("diag_hab_blk") else false,
		"turn_thr": float(get_meta("diag_turn_thr")) if has_meta("diag_turn_thr") else 1.0,
		"edge_stp": bool(get_meta("diag_edge_stp")) if has_meta("diag_edge_stp") else false,
		"yield": bool(get_meta("diag_yield")) if has_meta("diag_yield") else false,
		"whisk": bool(get_meta("diag_whisk")) if has_meta("diag_whisk") else false
	}
	AITelemetryService.log_deep_diagnostics(self, _generate_telemetry_name(), task_name, dir, vel_b4, vel_aft, collided, flags)


func _generate_telemetry_name() -> String:
	var raw_name := tr(entity_name_key).to_upper()
	if raw_name == "" or raw_name.begins_with("NPC_NAME"):
		raw_name = get_class().to_upper()
	return "%s#%d" % [raw_name, get_instance_id()]
