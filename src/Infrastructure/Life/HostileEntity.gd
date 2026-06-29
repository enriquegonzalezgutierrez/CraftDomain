# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a hostile zombie.
#              AI UPGRADE: Added intelligent wall bouncing logic to prevent
#              zombies from getting stuck walking endlessly into mountains.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name HostileEntity
extends CharacterBody3D

const SPEED: float = 2.2
const JUMP_VELOCITY: float = 5.0
const CHASE_RANGE: float = 16.0
const ATTACK_RANGE: float = 1.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var domain_entity: VoxelEntity
var player: CharacterBody3D
var _visual_materials: Array[ORMMaterial3D] = []

var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_chasing: bool = false
var _is_wandering: bool = false

# Obstacle Avoidance Tracker
var _stuck_timer: float = 0.0

func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_ZOMBIE"
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()
	_locate_player()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "ZombieCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 1.4, 0.5)
	col.shape = box_shape
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

func _locate_player() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		player = parent_node.get_node_or_null("Player") as CharacterBody3D

func _build_visual_representation() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.15, 0.35, 0.15)) 
	_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.25, 0.6, 0.25)) 
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(-0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) 
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) 
	_create_box(visual_root, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.225, 0), Color(0.1, 0.1, 0.25)) 
	_create_box(visual_root, Vector3(0.15, 0.45, 0.15), Vector3(0.1, 0.225, 0), Color(0.1, 0.1, 0.25))

func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_instance.material_override = mat
	_visual_materials.append(mat)
	parent.add_child(mesh_instance)

func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead: return
	velocity += knockback_force
	domain_entity.take_damage(amount)

func _on_domain_entity_took_damage(_amount: int) -> void:
	_flash_red()

func _flash_red() -> void:
	for mat in _visual_materials:
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.0, 0.0) 
	get_tree().create_timer(0.15).timeout.connect(_reset_damage_flash)

func _reset_damage_flash() -> void:
	for mat in _visual_materials:
		if is_instance_valid(mat): mat.emission_enabled = false

func _on_domain_entity_died() -> void:
	if is_instance_valid(player):
		var inv = player.get("inventory")
		if is_instance_valid(inv):
			inv.modify_slot_quantity(5, 1) 
			var active_q := QuestService.get_active_quest()
			if active_q != null and active_q.quest_id == "plains_defender":
				inv.modify_slot_quantity(active_q.reward_item_index, active_q.reward_quantity)
				QuestService.complete_active_quest()
			player.call("_sync_hud_counters") 
	
	var death_tween := create_tween().set_parallel(true)
	var visuals_node: Node3D = get_node("Visuals")
	if is_instance_valid(visuals_node):
		death_tween.tween_property(visuals_node, "rotation:z", deg_to_rad(-90), 0.2)
		death_tween.tween_property(visuals_node, "position:y", -0.4, 0.2)
	death_tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: return
	if not is_on_floor(): velocity.y -= gravity * delta
	if not is_instance_valid(player): _locate_player()

	_process_ai_intelligence(delta)
	move_and_slide()

func _process_ai_intelligence(delta: float) -> void:
	var _wander_direction_tmp: Vector3 = Vector3.ZERO
	_wander_timer -= delta
	
	if _wander_timer <= 0:
		_is_wandering = randf() > 0.4
		if _is_wandering:
			var angle := randf() * TAU
			_wander_direction_tmp = Vector3(cos(angle), 0, sin(angle))
			_wander_timer = randf_range(2.0, 5.0)
		else:
			_wander_direction_tmp = Vector3.ZERO
			_wander_timer = randf_range(1.0, 3.0)
			
	var is_player_trackable: bool = false
	if is_instance_valid(player) and player.get("is_active"):
		if global_position.distance_to(player.global_position) < CHASE_RANGE:
			_is_wandering = true
			_wander_direction = (player.global_position - global_position).normalized()
			_wander_direction.y = 0
			is_player_trackable = true
			
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
				_bite_player()
				
	if not is_player_trackable and _wander_direction_tmp != Vector3.ZERO:
		_wander_direction = _wander_direction_tmp

	if _is_wandering:
		var speed_mult: float = SPEED if is_player_trackable else (SPEED * 0.5)
		velocity.x = _wander_direction.x * speed_mult
		velocity.z = _wander_direction.z * speed_mult
		
		var visuals_node: Node3D = get_node("Visuals")
		if is_instance_valid(visuals_node) and _wander_direction != Vector3.ZERO:
			var target_look_at: Vector3 = global_position + _wander_direction
			visuals_node.look_at(target_look_at, Vector3.UP)
			visuals_node.rotation.x = 0
			visuals_node.rotation.z = 0
		
		# INTELLIGENT WALL AVOIDANCE (Zombie variant)
		if is_on_wall():
			if is_on_floor():
				velocity.y = JUMP_VELOCITY # Try to climb 1-block steps
				
			_stuck_timer += delta
			var patience := 1.0 if is_player_trackable else 0.4 # Persistent if chasing
			
			if _stuck_timer > patience:
				_stuck_timer = 0.0
				if not is_player_trackable:
					var wall_normal := get_wall_normal()
					var flat_normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
					if flat_normal != Vector3.ZERO:
						_wander_direction = _wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					else:
						var angle := randf() * TAU
						_wander_direction = Vector3(cos(angle), 0, sin(angle))
		else:
			_stuck_timer = 0.0
			
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func _bite_player() -> void:
	if is_instance_valid(player):
		var bite_knockback: Vector3 = (player.global_position - global_position).normalized() * 4.5
		bite_knockback.y = 2.0 
		if player.has_method("take_damage"):
			player.call("take_damage", 1, bite_knockback)
