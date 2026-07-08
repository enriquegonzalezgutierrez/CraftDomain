# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Class: SharkEntity
# Description: Physical character controller representing a hostile aquatic Shark.
#              Schedules animation rigging, handles water bounds, and registers its 
#              specialized FaunaAIBehavior strategy dynamically on ready.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively physical body 
#   water translations and target visual attachments, delegating movement and 
#   chase logic to the injected FaunaAIBehavior.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   parent class, utilizing its base physics processes and gravity vectors transparently.
# - Dependency Inversion Principle (DIP): Receives its behavioral decision tree 
#   via dynamic strategy injection on startup.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D

# Dynamic cached reference to visual model
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Sharks spawn with 4 Hearts of health (8 HP)
	super(spawn_pos, 8)
	name = "Entity_SHARK"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for target scans
	add_to_group("hostiles")
	
	# Cache component references pre-configured in the scene
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	_locate_player()
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Programmatically instantiates NPCAIComponent if missing from old scenes
	# ==========================================================================
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FaunaAIBehavior.new()


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
	
	if is_instance_valid(_nameplate):
		_nameplate.position.y = _collision_height + 0.35


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# Overrides nameplate color return value to warning crimson red
# ==============================================================================
func _get_nameplate_color() -> Color:
	return Color(1.0, 0.15, 0.15)


func _get_habitat() -> int:
	return 2 # AQUATIC


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


## Hostiles do not panic when hit
func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


## Drops 1x Sand Block on death
func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


# ==============================================================================
# PHYSICAL LIFE-CYCLE & TAIL-WAG OSCILLATOR
# ==============================================================================

func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	# Apply tail-wagging visual animations in real-time
	_process_procedural_swimming(delta)
	super(delta)


func _process_procedural_swimming(delta: float) -> void:
	if is_instance_valid(_model_node):
		var anim_time: float = Time.get_ticks_msec() / 1000.0
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			# Tail-wagging scales speed dynamically with flat physical velocity
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = deg_to_rad(-90.0) + sin(anim_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(anim_time * swim_speed * 0.5) * 0.08 
		else:
			_model_node.rotation.y = lerp(_model_node.rotation.y, deg_to_rad(-90.0), delta * 5.0)
			_model_node.rotation.z = sin(anim_time * 1.5) * 0.03
