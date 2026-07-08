# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive flying Parrot, designed to be
#              attached to a '.tscn' scene file.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively flight
#                physics, wing tilt calculations, and life-signals, delegating
#                static visual and collision boundaries to the Godot Editor.
#              - Liskov Substitution Principle (LSP): Subclasses PassiveEntity
#                and satisfies the base contracts without code-based instantiation.
# ==============================================================================
class_name ParrotEntity
extends PassiveEntity

# Procedural flight animation variables
var _animation_time: float = 0.0
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Parrots spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_PARROT"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Bind pure Domain Model signals
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# Cache the 3D model child node to apply flight sways in real-time
	_model_node = get_node_or_null("Visuals/BodyBobJoint/parrot") as Node3D
	
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
	
	# Aligns nameplate correctly above the visual model (including its flight height)
	if is_instance_valid(_nameplate):
		_nameplate.position.y = 2.521 + 0.35


## Real-time Procedural Flight Simulator Loop (SRP)
func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		
		# Calculate speed vector (ignore vertical gravity velocity)
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		# 1. Thermal Hover Bobbing (Smooth vertical sine wave)
		var hover_bob := sin(_animation_time * 3.5) * 0.22
		
		# Determine if we are flying or grounded in the showcase
		var is_showcase := false
		var current_node := get_parent()
		while current_node != null:
			if current_node is SubViewport and current_node.name != "root":
				is_showcase = true
				break
			current_node = current_node.get_parent()
			
		if is_showcase:
			_model_node.position.y = 0.0 # Frozen grounded for inspection
		else:
			_model_node.position.y = 2.521 + hover_bob
		
		# 2. Wing Flap Tilting and Forward Pitch
		if is_moving:
			# High-frequency roll rotation (Z-axis) simulating active flapping
			_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
			# Tilt forward (X-axis) when moving fast
			_model_node.rotation.x = deg_to_rad(12.0)
		else:
			# Slow resting breeze tilts
			_model_node.rotation.z = sin(_animation_time * 1.8) * 0.04
			_model_node.rotation.x = 0.0


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Avian panic bounce velocity
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	inv.add_item(16, 1)


func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true
