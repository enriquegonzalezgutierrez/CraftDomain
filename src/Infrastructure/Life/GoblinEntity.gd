# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Presentation & Physics / Hostiles)
# Class: GoblinEntity
# Description: Physical character controller for the hostile skirmisher Goblin.
#              Delegates all rapid chasing vectors, skirmishing retreats, 
#              and combat cooldowns to the decoupled GoblinAIBehavior strategy.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and entity nameplate styling.
# - Liskov Substitution Principle (LSP): Fully satisfies the base contracts 
#   declared in `PassiveEntity` by providing its unique nameplate key and red color.
# ==============================================================================
class_name GoblinEntity
extends PassiveEntity

# Sibling node references
var player: CharacterBody3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Goblins spawn with 2 Hearts of health (4 HP, fragile skirmisher)
	super(spawn_pos, 4)
	entity_habitat = 0 # Terrestrial
	name = "Entity_GOBLIN"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the hostile group for O(1) targeting sweeps
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") # Unregister from peaceful list (OCP/LSP)
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	# TANGENT SHIELD FIX: Strip materials of tangent-requiring shaders to avoid C++ warnings
	var model_node := get_node_or_null("Visuals/BodyBobJoint/goblin") as Node3D
	if is_instance_valid(model_node):
		_register_glb_materials(model_node)
	
	_locate_player()
	
	# Compute and register dynamic heights using inherited base class (LSP compliant)
	_setup_nameplate_height()
	
	# Inject the specialized Goblin skirmisher AI strategy dynamically on ready
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GoblinAIBehavior.new()


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
	return "NPC_NAME_GOBLIN"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) # Hostile Red (LSP Compliant)


func _has_ui_decorations() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass # Hostiles do not panic when hit


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Stone Block (acting as raw cave-rubble debris)
	inv.add_item(1, 1)


## Tactical Action bite: Inflicts damage and applies diagonal knockback
func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)
