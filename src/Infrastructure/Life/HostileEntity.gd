# ==============================================================================
# Project: CraftDomain
# Description: Hostile zombie physics controller wrapper.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating AI behaviors.
#              FIX: Added a strict 1.5-second attack cooldown timer to prevent
#              the 120Hz physics loop from instant-killing the player and forcing
#              respawn teleports back to (8.5, 14.0, 8.5).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/HostileEntity.gd
# ==============================================================================
class_name HostileEntity
extends CharacterBody3D

# Combat configurations
const SPEED: float = 2.2
const JUMP_VELOCITY: float = 5.0
const CHASE_RANGE: float = 16.0
const ATTACK_RANGE: float = 1.2
const ATTACK_COOLDOWN_INTERVAL: float = 1.5 # 1.5 seconds cooldown between bites

# Physics and state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD Compliance)
var domain_entity: VoxelEntity

# Sibling node references (loosely typed to prevent compile loops)
var player: CharacterBody3D
var _visual_materials: Array[ORMMaterial3D] = []

# AI wandering/chasing state variables
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false

# Cooldown Tracker (SRP)
var _attack_cooldown_timer: float = 0.0

# Obstacle Avoidance Tracker
var _stuck_timer: float = 0.0

func _init(spawn_pos: Vector3) -> void:
	position = spawn_pos
	name = "Entity_ZOMBIE"
	
	# Instantiate pure domain model and subscribe to its Domain Events
	domain_entity = VoxelEntity.new(3)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()
	_locate_player()
	_setup_quest_bubble()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "ZombieCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 1.4, 0.5)
	col.shape = box_shape
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

## UX / HIERARCHY FIX: Resolves player location by fetching the world controller's injected reference!
func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D

## UX UPGRADE: Automatically instantiates a floating red target bubble above the zombie's head during plains_defender!
func _setup_quest_bubble() -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var sb_script: Script = load("res://src/Infrastructure/UI/SpeechBubble.gd")
		if sb_script != null:
			var bubble = sb_script.new() as Node3D
			add_child(bubble)
			bubble.call("set_text", "☠️ [ TARGET MONSTER ] ☠️")

func _build_visual_representation() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	
	# Create Zombie Box Composition (Rotated forward along -Z)
	_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.15, 0.35, 0.15)) # Torso
	_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.25, 0.6, 0.25)) # Head
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(-0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) # Left arm
	_create_box(visual_root, Vector3(0.12, 0.12, 0.5), Vector3(0.15, 0.75, -0.28), Color(0.25, 0.6, 0.25)) # Right arm
	# Legs
	_create_box(visual_root, Vector3(0.15, 0.45, 0.15), Vector3(-0.1, 0.225, 0), Color(0.1, 0.1, 0.25)) # Blue trousers
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

## Infrastructure Method: Receives combat interaction, applies physics, and delegates logic to Domain.
func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead:
		return
		
	# Apply infrastructure physical knockback
	velocity += knockback_force
	
	# Delegate purely logical health reduction to Domain
	domain_entity.take_damage(amount)

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_took_damage(_amount: int) -> void:
	_flash_red()

func _flash_red() -> void:
	for mat in _visual_materials:
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.0, 0.0) # Red glow
		
	# Create a quick 0.15-second timer to restore original colors
	get_tree().create_timer(0.15).timeout.connect(_reset_damage_flash)

func _reset_damage_flash() -> void:
	for mat in _visual_materials:
		if is_instance_valid(mat):
			mat.emission_enabled = false

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_died() -> void:
	print("[Zombie] Blegh... Zombie died.")
	
	# Drop standard and quest-specific rewards
	if is_instance_valid(player):
		var inv := player.get("inventory") as IInventory
		if is_instance_valid(inv):
			print("[Zombie] Loot dropped: 1x Lava Bucket added.")
			inv.add_item(15, 1) 
			
			# --- CAMPAIGN MISSION 5 TRIGGER: Complete Plains Defender ---
			var active_q := QuestService.get_active_quest()
			if active_q != null and active_q.quest_id == "plains_defender":
				inv.add_item(active_q.reward_item_index, active_q.reward_quantity)
				QuestService.complete_active_quest(player)
				
			player.call("_sync_hud_counters") # Sync HUD UI instantly
	
	# Play a quick spinning/falling animation before deleting
	var death_tween := create_tween().set_parallel(true)
	var visuals_node: Node3D = get_node("Visuals")
	if is_instance_valid(visuals_node):
		death_tween.tween_property(visuals_node, "rotation:z", deg_to_rad(-90), 0.2)
		death_tween.tween_property(visuals_node, "position:y", -0.4, 0.2)
		
	death_tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Process bite cooldown tick (SRP)
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# Dynamic target search fallback if player spawned late
	if not is_instance_valid(player):
		_locate_player()

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
			
			# Check distance and execute attack only if the cooldown has elapsed!
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
				if _attack_cooldown_timer <= 0.0:
					_bite_player()
					_attack_cooldown_timer = ATTACK_COOLDOWN_INTERVAL # Start cooldown!
				
	if not is_player_trackable and _wander_direction_tmp != Vector3.ZERO:
		_wander_direction = _wander_direction_tmp

	if _is_wandering:
		var speed_mult: float = SPEED if is_player_trackable else (SPEED * 0.5)
		velocity.x = _wander_direction.x * speed_mult
		velocity.z = _wander_direction.z * speed_mult
		
		var visuals_node: Node3D = get_node("Visuals")
		if is_instance_valid(visuals_node) and _wander_direction.length_squared() > 0.01:
			var target_look_at: Vector3 = global_position + _wander_direction
			if not global_position.is_equal_approx(target_look_at):
				visuals_node.look_at(target_look_at, Vector3.UP)
				visuals_node.rotation.x = 0
				visuals_node.rotation.z = 0
		
		if is_on_wall():
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				
			_stuck_timer += delta
			var patience := 1.0 if is_player_trackable else 0.4 
			
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

## FIXED: Reduced y-knockback to prevent throwing player into tight ceilings (prevents physics clipping glitches)
func _bite_player() -> void:
	if is_instance_valid(player):
		var bite_knockback: Vector3 = (player.global_position - global_position).normalized() * 4.5
		bite_knockback.y = 0.25 # Extremely safe low-arc lift
		if player.has_method("take_damage"):
			player.call("take_damage", 1, bite_knockback)
