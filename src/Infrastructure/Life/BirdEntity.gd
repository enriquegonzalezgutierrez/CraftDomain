# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: BirdEntity
# Description: Physical character controller for the flying Yellow Bird.
#              Delegates all flight and perching decisions to the AvianAIBehavior 
#              strategy, managing procedural wing flap sways and dynamic, 
#              scale-aware nameplate floating.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, coordinate-facing rotations, and wing flap sways.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, utilizing inherited dynamic height solvers.
# - Open-Closed Principle (OCP): Nameplate tracking calculations are fully 
#   dynamic, adapting automatically to any scale configured in the .tscn editor.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name BirdEntity
extends PassiveEntity

# Animation and visual reference trackers
var _animation_time: float = 0.0
var _model_node: Node3D

# Visual model baseline Y-coordinate (Y-axis origin when perched)
const MODEL_BASE_Y: float = 0.0


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Birds spawn with 1 Heart of health (2 HP)
	super(spawn_pos, 2)
	name = "Entity_BIRD"


func _ready() -> void:
	# Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache components pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/yellow_bird") as Node3D
	
	# Fetch nameplate configurations from inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Avian flight/perch AI behavior strategy on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AvianAIBehavior.new()


func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Fried Chicken (acting as soft avian meat proxy)
	inv.add_item(16, 1)


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _is_avian() -> bool: 
	return true


func _can_fly() -> bool:
	return true # Bypasses gravity void-clamping inside base class PassiveEntity


func _can_socialize() -> bool: 
	return true


# ==============================================================================
# PROCEDURAL WING FLAP & ALTIMETRICAL ROTATIONS
# ==============================================================================

func _process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	if is_instance_valid(_model_node):
		# Read flight state from metadata safely (DIP)
		var flight_state := 0 # Default STATE_SOARING
		if has_meta(AvianAIBehavior.META_STATE):
			flight_state = get_meta(AvianAIBehavior.META_STATE) as int
			
		if flight_state == 2: # STATE_PERCHED (Resting flat on top of leaves)
			_model_node.position.y = MODEL_BASE_Y
			_model_node.rotation.z = 0.0
			_model_node.rotation.x = 0.0
		else:
			# FLIGHT FLAPPING ACTIVE STATE
			_animation_time += delta
			
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			
			# Smooth thermal hover bobbing
			var hover_bob := sin(_animation_time * 4.0) * 0.18
			
			# Handle Showcase Room visualization override
			var is_showcase := false
			var current_node := get_parent()
			while current_node != null:
				if current_node is SubViewport and current_node.name != "root":
					is_showcase = true
					break
				current_node = current_node.get_parent()
				
			if is_showcase:
				_model_node.position.y = MODEL_BASE_Y # Sinks flat to floor inside showroom
			else:
				_model_node.position.y = MODEL_BASE_Y + hover_bob
			
			if is_moving:
				# High-frequency Z-axis rotation roll to simulate flapping wings
				_model_node.rotation.z = sin(_animation_time * 16.0) * 0.22
				_model_node.rotation.x = deg_to_rad(10.0) # Pitch slightly forward
			else:
				# Slow resting glide sways
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
				
		# ======================================================================
		# UNIVERSAL DYNAMIC NAMEPLATE POSITIONER (OCP / SOLID COMPLIANT)
		# Sincroniza la etiqueta sumando la compensación de aleteo en tiempo real.
		# Se adapta automáticamente a cualquier escala (0.25, 1.0, 5.0) sin tocar código.
		# ======================================================================
		if is_instance_valid(_nameplate):
			var relative_offset := _model_node.position.y - MODEL_BASE_Y
			_nameplate.position.y = _collision_height + 0.35 + relative_offset
