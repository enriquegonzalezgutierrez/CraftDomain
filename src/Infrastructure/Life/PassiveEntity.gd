# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/PassiveEntity.gd
# Description: Abstract physical base class representing NPCs and Wildlife.
#              Coordinates physical movements, gravity slides, and hit boxes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
@warning_ignore("unused_private_class_variable")
class_name PassiveEntity
extends CharacterBody3D

var entity_name_key: String = ""

@export var is_conversational_npc: bool = false
@export var humanoid_role: int = -1
@export var entity_habitat: int = 0

const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0
const ANIM_DIR := "res://assets/models/mobs/"

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
	_auto_claim_registered_quest_target()


func _setup_nameplate_height() -> void:
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col):
		var shape_height := 1.5
		if col.shape is CylinderShape3D or col.shape is CapsuleShape3D:
			shape_height = col.shape.height
		elif col.shape is BoxShape3D:
			shape_height = col.shape.size.y
			
		var local_y_center := col.position.y
		var scaled_half_height := (shape_height * col.scale.y) / 2.0
		_collision_height = local_y_center + scaled_half_height
	else:
		_collision_height = 1.5


func _setup_ui_component() -> void:
	_ui_component = EntityUIComponent.new()
	add_child(_ui_component)
	_ui_component.initialize(self, _collision_height)


func _auto_claim_registered_quest_target() -> void:
	if QuestService._quests.is_empty(): return
		
	for q_id: String in QuestService._quests.keys():
		var q := QuestService._quests[q_id] as Quest
		if q != null and q.target_position != Vector3.ZERO:
			var dist := global_position.distance_to(q.target_position)
			if dist <= 25.0 and _is_eligible_for_quest(q_id):
				quest_target_id = q_id
				break


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
	var habitat := _get_habitat()
	if habitat == 2: 
		var world_controller_ref := get_parent()
		if is_instance_valid(world_controller_ref) and "world_state" in world_controller_ref:
			var ws: WorldState = world_controller_ref.world_state
			if is_instance_valid(ws):
				return ws.get_block(target_coord) == BlockType.Type.WATER 
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
		
	if is_instance_valid(attacker):
		_last_attacker = attacker
		
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
			if is_instance_valid(rep): rep.modify_reputation(-15)
			
	var closest_attacker := _find_closest_hostile_threat()
	if is_instance_valid(closest_attacker):
		AlertNetworkService.broadcast_alarm(closest_attacker, global_position)


func _find_closest_hostile_threat() -> CharacterBody3D:
	if not is_inside_tree(): return null
		
	var hostiles := get_tree().get_nodes_in_group("hostiles")
	var closest: CharacterBody3D = null
	var min_dist_sq := 64.0
	
	for child: Node in hostiles:
		if child == self or not is_instance_valid(child): continue
		var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
		if zombie_entity != null and not zombie_entity.is_dead:
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
		
	_deduct_reputation_on_murder()


func _deduct_reputation_on_murder() -> void:
	var role := _get_humanoid_role()
	var is_civilian: bool = (role == 0 or role == 1 or role == 3 or role == 4 or role == 5)
	
	if is_civilian and is_instance_valid(_last_attacker) and _last_attacker.name == "Player":
		var rep := VillageReputationService.instance
		if is_instance_valid(rep): rep.modify_reputation(-35)


func _apply_death_animations_and_free() -> void:
	var death_tween := create_tween().set_parallel(true)
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		death_tween.tween_property(visual_component.visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_component.visual_root, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particles := CPUParticles3D.new()
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
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mesh.material = mat
	particles.mesh = mesh
	
	particles.finished.connect(particles.queue_free)
	var world_node := get_parent()
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
		particles.emitting = true


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
		
	if not _is_lifecycle_initialized:
		_execute_lifecycle_initialization()
		
	_update_sleeping_state()
	if _is_physically_sleeping:
		velocity = Vector3.ZERO
		return
		
	_apply_environmental_physics(delta)
	_process_ai_and_boundaries(delta)
	_apply_visual_movement_and_slide(delta)


func _update_sleeping_state() -> void:
	if Engine.get_physics_frames() % 15 == 0:
		var player_node: CharacterBody3D = null
		var parent_node := get_parent()
		if is_instance_valid(parent_node) and "player" in parent_node:
			player_node = parent_node.get("player") as CharacterBody3D
			
		if is_instance_valid(player_node):
			_is_physically_sleeping = global_position.distance_squared_to(player_node.global_position) > 1600.0
		else:
			_is_physically_sleeping = false


func _apply_environmental_physics(delta: float) -> void:
	var is_in_liquid := _check_in_liquid_state()
	
	if _can_fly() and not is_in_liquid:
		var flight_state := 0
		if has_meta("avian_flight_state"):
			flight_state = get_meta("avian_flight_state") as int
		if flight_state != 2:
			return
			
	if (not is_on_floor() or is_in_liquid) and _get_habitat() != 2 and not is_in_liquid:
		velocity.y -= gravity * delta
	elif is_in_liquid:
		_apply_liquid_buoyancy(delta)
	else:
		_apply_grounded_snap(delta)


func _apply_liquid_buoyancy(delta: float) -> void:
	var habitat := _get_habitat()
	if habitat == 2: 
		velocity.y = move_toward(velocity.y, 0.0, gravity * 0.5 * delta)
	elif habitat == 1: 
		velocity.y = move_toward(velocity.y, -0.2, gravity * 0.5 * delta)
	else: 
		velocity.y = move_toward(velocity.y, -1.8, gravity * 0.5 * delta)


func _apply_grounded_snap(delta: float) -> void:
	if _get_habitat() == 2:
		velocity.y -= gravity * delta
	else:
		# Solución física: Incrementamos el snap descendente para forzar al
		# motor de físicas de Godot a revaluar colisiones en cada fotograma,
		# superando el safe_margin (0.015) y evitando que queden suspendidos.
		velocity.y = -1.2


func _check_in_liquid_state() -> bool:
	var parent_node_ref := get_parent()
	if is_instance_valid(parent_node_ref) and "world_state" in parent_node_ref:
		var ws: WorldState = parent_node_ref.world_state
		if ws != null:
			var my_coord := Vector3i(floori(global_position.x), floori(global_position.y + 0.2), floori(global_position.z))
			return (ws.get_block(my_coord) == 6 or ws.get_block(my_coord) == 15 or \
					ws.get_block(my_coord + Vector3i(0, -1, 0)) == 6 or ws.get_block(my_coord + Vector3i(0, -1, 0)) == 15)
	return false


func _process_ai_and_boundaries(delta: float) -> void:
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
		
	_apply_absolute_boundary_forcefield(delta)
	
	quest_check_timer -= delta
	if quest_check_timer <= 0.0:
		quest_check_timer = 0.5
		_update_quest_bubble_state()


func _update_quest_bubble_state() -> void:
	if is_instance_valid(_ui_component):
		var active_quest := QuestService.get_active_quest()
		if active_quest != null and quest_target_id == active_quest.quest_id:
			active_quest.target_position = global_position
		_ui_component.update_ui_state(active_quest, quest_target_id)


func _apply_absolute_boundary_forcefield(delta: float) -> void:
	var world_controller_ref := get_parent()
	if not is_instance_valid(world_controller_ref) or not "world_state" in world_controller_ref:
		return
		
	var ws: WorldState = world_controller_ref.world_state
	if ws == null: return
		
	var next_pos := global_position + velocity * delta
	var feet_coord := Vector3i(floori(next_pos.x), floori(next_pos.y + 0.1), floori(next_pos.z))
	
	_enforce_habitat_boundary(ws, feet_coord)


func _enforce_habitat_boundary(ws: WorldState, feet_coord: Vector3i) -> void:
	var block_at_feet := ws.get_block(feet_coord)
	var block_below_feet := ws.get_block(feet_coord + Vector3i(0, -1, 0))
	
	var is_feet_safe := _is_block_type_habitable(block_at_feet)
	var is_below_safe := _is_block_type_habitable(block_below_feet)
	
	if not is_feet_safe and not is_below_safe:
		velocity.x = 0.0
		velocity.z = 0.0
		
	if _get_habitat() == 2 and block_at_feet == BlockType.Type.AIR:
		velocity.y = -2.5


func _apply_visual_movement_and_slide(delta: float) -> void:
	var flat_velocity := Vector2(velocity.x, velocity.z)
	if is_instance_valid(visual_representation):
		visual_representation.animate_movement(flat_velocity, is_on_floor(), delta)
		
	_physics_tick(delta)
	move_and_slide()
