# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Physics & Presentation)
# Description: Physics controller for the passive flying Yellow Bird.
# ==============================================================================
class_name BirdEntity
extends PassiveEntity

var _animation_time: float = 0.0
var _model_node: Node3D


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	name = "Entity_BIRD"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/yellow_bird") as Node3D
	
	_setup_nameplate_height()


func _process(delta: float) -> void:
	if domain_entity.is_dead: return
	if is_instance_valid(_model_node):
		_animation_time += delta
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		var hover_bob := sin(_animation_time * 4.0) * 0.25
		
		var is_showcase := false
		var current_node := get_parent()
		while current_node != null:
			if current_node is SubViewport and current_node.name != "root":
				is_showcase = true
				break
			current_node = current_node.get_parent()
			
		if is_showcase:
			_model_node.position.y = 0.0
		else:
			_model_node.position.y = 2.4549 + hover_bob
		
		if is_moving:
			_model_node.rotation.z = sin(_animation_time * 14.0) * 0.20
			_model_node.rotation.x = deg_to_rad(15.0)
		else:
			_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
			_model_node.rotation.x = 0.0


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(16, 1)


func _is_avian() -> bool: return true
func _can_socialize() -> bool: return true
