# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive entity.
#              Acts as an Infrastructure Wrapper that uses Composition to hold
#              a pure Domain VoxelEntity. Executes trades by delegating transaction
#              rules to the domain TradingService.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

## Entity Type definitions.
enum Type {
	PIG,
	CHICKEN,
	VILLAGER,
	MERCHANT
}

# AI Wandering states
const SPEED: float = 1.5
const JUMP_VELOCITY: float = 5.0

# Dependencies and properties
var entity_type: Type
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity

# AI logic timers
var _wander_timer: float = 0.0
var _wander_direction: Vector3 = Vector3.ZERO
var _is_wandering: bool = false

func _init(p_type: Type, spawn_pos: Vector3) -> void:
	entity_type = p_type
	position = spawn_pos
	name = "Entity_%s" % Type.keys()[entity_type]
	
	# Instantiate pure domain model and subscribe to its Domain Events
	# (Passive entities have 1 health by default, they die in 1 hit)
	domain_entity = VoxelEntity.new(1)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)

func _ready() -> void:
	_build_visual_representation()
	_setup_collision()

func _setup_collision() -> void:
	# Add standard simplified box collider matching the entity height
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	
	match entity_type:
		Type.CHICKEN:
			box_shape.size = Vector3(0.4, 0.6, 0.4)
			col.position = Vector3(0, 0.3, 0)
		Type.PIG:
			box_shape.size = Vector3(0.6, 0.6, 0.8)
			col.position = Vector3(0, 0.3, 0)
		Type.VILLAGER, Type.MERCHANT:
			box_shape.size = Vector3(0.5, 1.4, 0.5)
			col.position = Vector3(0, 0.7, 0)
			
	col.shape = box_shape
	add_child(col)

func _build_visual_representation() -> void:
	# Root visual assembly
	var visual_root := Node3D.new()
	visual_root.name = "Visuals"
	add_child(visual_root)
	
	match entity_type:
		Type.PIG:
			_create_box(visual_root, Vector3(0.6, 0.4, 0.8), Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.7)) # Torso
			_create_box(visual_root, Vector3(0.35, 0.35, 0.35), Vector3(0, 0.55, -0.45), Color(1.0, 0.55, 0.65)) # Head
			_create_box(visual_root, Vector3(0.2, 0.1, 0.1), Vector3(0, 0.45, -0.65), Color(0.9, 0.35, 0.45)) # Snout
			# Legs
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(-0.2, 0.125, -0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(0.2, 0.125, -0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(-0.2, 0.125, 0.25), Color(1.0, 0.6, 0.7))
			_create_box(visual_root, Vector3(0.15, 0.25, 0.15), Vector3(0.2, 0.125, 0.25), Color(1.0, 0.6, 0.7))
			
		Type.CHICKEN:
			_create_box(visual_root, Vector3(0.3, 0.3, 0.4), Vector3(0, 0.3, 0), Color(0.95, 0.95, 0.95)) # Body
			_create_box(visual_root, Vector3(0.18, 0.22, 0.18), Vector3(0, 0.5, -0.2), Color(0.95, 0.95, 0.95)) # Head
			_create_box(visual_root, Vector3(0.15, 0.08, 0.12), Vector3(0, 0.5, -0.32), Color(1.0, 0.6, 0.0)) # Beak
			_create_box(visual_root, Vector3(0.06, 0.1, 0.06), Vector3(0, 0.4, -0.2), Color(0.9, 0.1, 0.1)) # Wattle
			# Legs
			_create_box(visual_root, Vector3(0.05, 0.15, 0.05), Vector3(-0.08, 0.075, 0), Color(1.0, 0.6, 0.0))
			_create_box(visual_root, Vector3(0.05, 0.15, 0.05), Vector3(0.08, 0.075, 0), Color(1.0, 0.6, 0.0))
			
		Type.VILLAGER:
			_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.35, 0.22, 0.15)) # Robe
			_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.95, 0.75, 0.65)) # Head
			_create_box(visual_root, Vector3(0.08, 0.18, 0.1), Vector3(0, 1.05, -0.2), Color(0.85, 0.65, 0.55)) # Nose
			_create_box(visual_root, Vector3(0.5, 0.15, 0.2), Vector3(0, 0.65, -0.18), Color(0.25, 0.15, 0.1)) # Folded Arms

		Type.MERCHANT:
			_create_box(visual_root, Vector3(0.45, 0.9, 0.45), Vector3(0, 0.55, 0), Color(0.45, 0.15, 0.6)) # Robe
			_create_box(visual_root, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.1, 0), Color(0.95, 0.75, 0.65)) # Head
			_create_box(visual_root, Vector3(0.08, 0.18, 0.1), Vector3(0, 1.05, -0.2), Color(0.85, 0.65, 0.55)) # Nose
			_create_box(visual_root, Vector3(0.5, 0.15, 0.2), Vector3(0, 0.65, -0.18), Color(0.85, 0.6, 0.15)) # Folded Arms

func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)

## Infrastructure Method: Receives combat interaction, applies physics, and delegates logic to Domain.
func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead:
		return
		
	# 1. Apply infrastructure physical knockback
	velocity += knockback_force
	
	# 2. Delegate purely logical health reduction to Domain
	domain_entity.take_damage(amount)

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_took_damage(_amount: int) -> void:
	# Passive entities don't flash red, but they jump when hit
	velocity.y = JUMP_VELOCITY

## Infrastructure Event Handler: Reacts to the Domain Event
func _on_domain_entity_died() -> void:
	print("[PassiveEntity] Entity died.")
	queue_free() # Passive entities disappear instantly for simplicity

## Processes direct trading using the segregated IInventory interface.
func interact(player: CharacterBody3D) -> void:
	if entity_type != Type.MERCHANT:
		return # Only merchants can trade
		
	# Make the merchant look at the player during interaction
	var look_direction: Vector3 = (player.global_position - global_position).normalized()
	look_direction.y = 0 # Lock pitch
	var visuals_node: Node3D = get_node("Visuals")
	if is_instance_valid(visuals_node) and look_direction != Vector3.ZERO:
		visuals_node.look_at(global_position + look_direction, Vector3.UP)
		visuals_node.rotation.x = 0
		visuals_node.rotation.z = 0

	# ISP Compliance: Fetch and cast the player's inventory as a segregated IInventory interface
	var inventory: IInventory = player.get("inventory") as IInventory
	var player_hud = player.get("hud")
	var active_slot: int = player.get("active_slot_index")
	
	if is_instance_valid(inventory) and is_instance_valid(player_hud):
		# Verify if player is holding Lava Buckets (Slot 5)
		if active_slot == 5:
			# Delegate transactions rules to Domain TradingService (Strict DDD and clean SRP)
			# Consuming 1 Lava Bucket (Slot 5) and reward 1 Fried Chicken (Slot 6)
			if TradingService.execute_trade(inventory, 5, 1, 6, 1):
				# Hop excited with physical joy
				velocity.y = JUMP_VELOCITY
				
				# Refresh HUD active slot selection display dynamically
				player_hud.call("update_active_slot", 5)
				
				print("[Merchant] Hmmm! Hot lava! Thank you! Here is your famous Lava-Fried Chicken!")
			else:
				print("[Merchant] Hmmm? You are out of Lava Buckets!")
		else:
			print("[Merchant] Hmmm? Bring me a Bucket of Lava (Slot 5) to trade for my Lava-Fried Chicken!")
	else:
		print("[Merchant] Hmmm? Bring me a Bucket of Lava (Slot 5) to trade for my Lava-Fried Chicken!")

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Run simple AI state machine
	_wander_timer -= delta
	if _wander_timer <= 0:
		_is_wandering = randf() > 0.4
		if _is_wandering:
			var angle := randf() * TAU
			_wander_direction = Vector3(cos(angle), 0, sin(angle))
			_wander_timer = randf_range(2.0, 5.0)
		else:
			_wander_direction = Vector3.ZERO
			_wander_timer = randf_range(1.0, 3.0)

	# 3. Apply wander velocity
	if _is_wandering:
		velocity.x = _wander_direction.x * SPEED
		velocity.z = _wander_direction.z * SPEED
		
		# Turn visuals towards wander direction cleanly using look_at()
		var visuals_node: Node3D = get_node("Visuals")
		if is_instance_valid(visuals_node):
			# Align model forward vector (-Z) towards the travel direction
			var target_look_at: Vector3 = global_position + _wander_direction
			visuals_node.look_at(target_look_at, Vector3.UP)
			visuals_node.rotation.x = 0 # Lock pitch axis rotation
			visuals_node.rotation.z = 0 # Lock roll axis rotation
		
		# Jump over blocks automatically if colliding with walls on floor level
		if is_on_wall() and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
