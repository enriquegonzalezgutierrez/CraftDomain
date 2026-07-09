# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & Physics (Entities)
# Class: FoxEntity
# Description: Physical character controller for the forest predator Fox.
#              It delegates all leaves scans, crawling crouches, and pounce leaps
#              to the decoupled FoxAIBehavior strategy, managing visual flattening
#              offsets and strike damage upon landings.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   translations, collision shapes, and dynamic crouching mesh scales.
# - Liskov Substitution Principle (LSP): Fully compatible with the PassiveEntity 
#   base contract, relying 100% on the base physics loop for standard translations.
# - Dependency Inversion Principle (DIP): Injects the FoxAIBehavior strategy 
#   during ready state initialization to keep code decoupled.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/FoxEntity.gd
# ==============================================================================
class_name FoxEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	# Foxes spawn with 2 Hearts of health (4 HP)
	super(spawn_pos, 4)
	name = "Entity_FOX"


func _ready() -> void:
	# HIGH PERFORMANCE: Register in the passive group for target lookups
	add_to_group("passives")
	
	# Cache component references pre-configured in the scene
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_nameplate_height()
	
	# ==========================================================================
	# BEHAVIOR STRATEGY INJECTION (SOLID / OCP COMPLIANCE)
	# Inject the specialized Fox predator AI strategy dynamically on ready,
	# completely overriding the default generic wildlife behavior assigned by Bootstrap.
	# ==========================================================================
	if is_instance_valid(ai_component):
		ai_component.active_behavior = FoxAIBehavior.new()


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
# ==============================================================================
func _is_avian() -> bool:
	return false


func _can_socialize() -> bool:
	return true


func _on_domain_entity_took_damage(_amount: int) -> void:
	# Startle escape jumps
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


func _drop_loot(inv: IInventory) -> void:
	# Drops 1x Meat rations (ID 16)
	inv.add_item(16, 1)


# ==============================================================================
# TACTICAL PRESENTATION & SNEAKING CROUCH & STRIKES
# ==============================================================================

## Visual Crouch: Smoothly scales model height down to simulate stealth prowling
## Note: Invoked via reflective calls by the FoxAIBehavior strategy
func _set_crouch_height(is_crouched: bool) -> void:
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		var target_scale_y := 0.65 if is_crouched else 1.0
		var target_pos_y := 0.01 if is_crouched else 0.02
		
		# Smooth visual interpolation
		visual_component.visual_root.scale.y = lerp(visual_component.visual_root.scale.y, target_scale_y, 0.12)
		visual_component.visual_root.position.y = lerp(visual_component.visual_root.position.y, target_pos_y, 0.12)


## Pounce Strike: Emits pounce bark and inflicts damage (1 Heart / 2 HP) on prey
## Note: Invoked via reflective calls by the FoxAIBehavior strategy
func _execute_pounce_strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	# Play high-pitched canine alert statically (Service Locator)
	AudioService.play_sfx_static("npc_chat", global_position)
	
	# Execute damage strike upon landing
	if target.has_method("take_damage"):
		var direction_vec := (target.global_position - global_position).normalized()
		var pounce_knockback := direction_vec * 4.2 + Vector3(0.0, 1.8, 0.0)
		target.call("take_damage", 2, pounce_knockback, self) # Inflicts 2 HP (1 Heart)
