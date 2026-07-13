# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SharkEntity.gd
# Description: Physical character controller for the hostile Great White Shark.
#              Sustains strict aquatic habitat limits polimorphically (OCP/LSP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SharkEntity
extends PassiveEntity

var player: CharacterBody3D
var _model_node: Node3D
var _model_base_y: float = 0.0

const COOLDOWN_ATTACK_MIN_SEC: float = 18.0
const COOLDOWN_ATTACK_MAX_SEC: float = 35.0

var _attack_sound_timer: float = randf_range(5.0, 15.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 8)
	entity_habitat = 2 # Aquatic (Water only)
	name = "Entity_SHARK"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") 
	
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/shark") as Node3D
	
	if is_instance_valid(_model_node):
		GLBModelSanitizer.sanitize_model(_model_node)
		_model_base_y = _model_node.rotation.y
	
	_locate_player()
	_setup_nameplate_height()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = SharkAIBehavior.new()


func _physics_tick(delta: float) -> void:
	_process_procedural_swimming(delta)


func _get_entity_name_key() -> String:
	return "NPC_NAME_SHARK"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


func _has_ui_decorations() -> bool:
	return true


## Polymorphic Override (OCP/LSP Compliant): Restricts the shark strictly to Water blocks
func _is_block_type_habitable(block_type: BlockType.Type) -> bool:
	return block_type == BlockType.Type.WATER


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(7, 1)


func _play_shark_vocal() -> void:
	AudioService.play_sfx_static("shark_attack", global_position)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 6.5, 2.5, dir.z * 6.5)
		_play_shark_vocal()
		if player.has_method("take_damage"):
			player.call("take_damage", 3, knockback)


func _process_procedural_swimming(delta: float) -> void:
	if is_instance_valid(_model_node):
		var anim_time := Time.get_ticks_msec() / 1000.0
		var flat_velocity := Vector2(velocity.x, velocity.z)
		var is_moving := flat_velocity.length_squared() > 0.1
		
		if is_moving:
			var swim_speed := flat_velocity.length() * 2.5
			_model_node.rotation.y = _model_base_y + sin(anim_time * swim_speed) * 0.22
			_model_node.rotation.z = cos(anim_time * swim_speed * 0.5) * 0.08 
		else:
			_model_node.rotation.y = lerp_angle(_model_node.rotation.y, _model_base_y, delta * 5.0)
			_model_node.rotation.z = sin(anim_time * 1.5) * 0.03


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_attack_sound_timer -= delta
		if _attack_sound_timer <= 0.0:
			_attack_sound_timer = randf_range(COOLDOWN_ATTACK_MIN_SEC, COOLDOWN_ATTACK_MAX_SEC)
			_play_shark_vocal()
