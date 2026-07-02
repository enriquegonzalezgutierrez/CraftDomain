# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure physics controller node representing a passive chicken/duck.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Safely extends PassiveEntity.
#              - Single Responsibility Principle (SRP): Delegates rendering setups 
#                and AI state execution to specialized sibling components.
#              UX MODELING OVERHAUL (CLAY DUCK CHICKEN):
#              - Assembled programmatically to perfectly match the high-fidelity 
#                clay-voxel duck reference: features a broad orange bill, centered 
#                red wattle, deep lateral black eyes, and wide flat webbed feet.
#              WARNING FIX:
#              - Removed the unused local variable `eye_black` from `_build_visual_representation()` 
#                to completely resolve the `UNUSED_VARIABLE` compiler warning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ChickenEntity.gd
# ==============================================================================
class_name ChickenEntity
extends PassiveEntity


func _init(spawn_pos: Vector3) -> void:
	super(spawn_pos, 1) # 1 Heart of health (2 HP)
	name = "Entity_CHICKEN"


## Concrete Setup: Assembles the detailed 3D model, binding voxel nodes 
## to the visual component joints.
func _build_visual_representation() -> void:
	var white := Color(0.98, 0.98, 0.98)           # Crisp clay white body
	var wing_grey := Color(0.92, 0.92, 0.94)       # Soft grey wing accents
	var orange := Color(0.95, 0.55, 0.0)           # High-contrast beak/feet orange
	var red := Color(0.92, 0.12, 0.15)             # Crimson wattle red
	
	# 1. Main Torso Body (White, attached to the bobbing joint of visual component)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.38, 0.42, 0.52), Vector3(0, 0.35, 0), white)
	
	# Lateral Grey Wings (Adds beautiful 3D volume and depth)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.04, 0.28, 0.36), Vector3(-0.21, 0.38, 0.02), wing_grey) # Left wing
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.04, 0.28, 0.36), Vector3(0.21, 0.38, 0.02), wing_grey)  # Right wing
	
	# Small White Tail (Sticking out the back)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.18, 0.18, 0.12), Vector3(0, 0.48, 0.28), white)
	
	# 2. Head Joint Setup
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "ChickenHead"
	visual_component.head_node.position = Vector3(0.0, 0.58, -0.16)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	
	visual_component.create_box(visual_component.head_node, Vector3(0.28, 0.38, 0.28), Vector3(0, 0.12, 0), white) # Main head block
	
	# Broad Orange Bill/Beak (Minecraft clay duck style)
	visual_component.create_box(visual_component.head_node, Vector3(0.34, 0.12, 0.22), Vector3(0, 0.05, -0.18), orange)
	
	# Crimson Red Wattle (Hanging centrally exactly under the bill)
	visual_component.create_box(visual_component.head_node, Vector3(0.12, 0.14, 0.08), Vector3(0, -0.06, -0.11), red)
	
	# Deep-set Black Voxel Eyes (Assigned to visual component tracking)
	visual_component.left_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.11, 0.19, -0.18), eye_black_color_fallback())
	visual_component.right_eye = visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.11, 0.19, -0.18), Color.WHITE) # Pupil white backing
	visual_component.create_box(visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), eye_pupil_color()) # Dark pupil
	
	# 3. Orange Legs & Swimming Flippers (Quadruped alignment, bobbing with the torso)
	# Left Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.18, 0.06), Vector3(-0.08, 0.1, 0.02), orange) # Left leg shaft
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.03, 0.24), Vector3(-0.08, 0.015, -0.06), orange) # Left flat webbed claw
	
	# Right Leg
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.06, 0.16, 0.06), Vector3(0.08, 0.1, -0.02), orange) # Right leg shaft
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.20, 0.03, 0.18), Vector3(0.08, 0.015, -0.06), orange) # Right claw


func _get_collision_box_size() -> Vector3:
	return Vector3(0.46, 0.69, 0.46)


func _get_collision_box_position() -> Vector3:
	return Vector3(0, 0.345, 0)


## Flag used by the animation ticker to configure bouncy avian walks
func _is_avian() -> bool:
	return true


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Avian panic bounce!
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


## Override (LSP): Drops 1x Fried Chicken on death.
func _drop_loot(inv: IInventory) -> void:
	# Item ID 16: Fried Chicken
	var _un1 := inv.add_item(16, 1)


func eye_black_color_fallback() -> Color:
	return Color(0.12, 0.12, 0.14)


func eye_pupil_color() -> Color:
	return Color(0.05, 0.05, 0.08)
