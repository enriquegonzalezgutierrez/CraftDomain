# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Wildlife)
# Class: TurtleEntity
# Description: Physical character controller for the Amphibious Sea Turtle.
#              Delegates all movement decisions, beach scuttling, and water 
#              swim buoyancy oscillations to the decoupled AmphibiousAIBehavior 
#              strategy, focusing strictly on physical collision translations and loot.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and entity nameplate height styling.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and green color.
# ==============================================================================
class_name TurtleEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 4)
	entity_habitat = 1 # Amphibious (Water, Sand, Mud)
	name = "Entity_TURTLE"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/turtle") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Amphibious AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = AmphibiousAIBehavior.new()


## Recursively duplicates and sanitizes materials across ALL mesh surfaces (Tangent Shield)
func _register_glb_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		# Multi-Surface Sweep: Sanitize every material index on the mesh
		for i: int in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
				
			if mat is BaseMaterial3D:
				var new_mat := mat.duplicate() as BaseMaterial3D
				# TANGENT WARNING SHIELD
				new_mat.normal_enabled = false
				new_mat.anisotropy_enabled = false
				new_mat.clearcoat_enabled = false
				new_mat.heightmap_enabled = false
				node.set_surface_override_material(i, new_mat)
			
	for child: Node in node.get_children():
		_register_glb_materials(child)


## Bypasses old procedural representation compiling
func _build_visual_representation() -> void:
	pass # Visual model is instanced directly in the .tscn scene file


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_TURTLE"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2) # Friendly/Passive Green


func _drop_loot(inv: IInventory) -> void:
	# Item ID 7: Sand Block
	inv.add_item(7, 1)


func _is_avian() -> bool:
	return true # Activates slight procedural crawl tilts inside base class


func _can_socialize() -> bool:
	return true
