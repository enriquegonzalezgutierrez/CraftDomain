# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/GargoyleEntity.gd
# Description: Physical character controller for the hostile nocturnal Gargoyle.
#              Coordinates state transitions, flight, and combat parameters (OCP).
#              Corrected: Resolved invisible nameplate due to bypassed update loops.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GargoyleEntity
extends PassiveEntity

# Viewmodel and camera parameters (Section 5.3)
const SPEED: float = 3.0
const MODEL_BASE_Y: float = 0.8982

var player: CharacterBody3D
var _model_node: Node3D
var _anim_player: AnimationPlayer

var _animation_time: float = 0.0
var _model_base_rot: Vector3 = Vector3.ZERO


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 12)
	entity_habitat = 0 # Terrestrial
	name = "Entity_GARGOYLE"


func _ready() -> void:
	# Register in the hostile group for O(1) targeting sweeps
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives")
		
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	_model_node = get_node_or_null("Visuals/BodyBobJoint/gargoyle") as Node3D
	
	if is_instance_valid(_model_node):
		_anim_player = _model_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_model_base_rot = _model_node.rotation
		GLBModelSanitizer.sanitize_model(_model_node)
		
	_locate_player()
	
	# Symmetrical lifecycle initialization call (Resolves missing nameplate)
	_execute_lifecycle_initialization()
	
	if is_instance_valid(ai_component):
		ai_component.active_behavior = GargoyleAIBehavior.new()


# ==============================================================================
# SOLID POLYMORPHIC CONTRACTS (LSP / OCP COMPLIANCE)
# ==============================================================================

func _get_entity_name_key() -> String:
	return "NPC_NAME_GARGOYLE"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) # Hostile Red (LSP Compliant)


func _build_visual_representation() -> void:
	pass


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(1, 1) # Drops 1x Stone Block on defeat


func _set_gargoyle_stone_appearance(is_stone: bool) -> void:
	if is_instance_valid(_model_node):
		_traverse_and_apply_stone_appearance(_model_node, is_stone)


func _traverse_and_apply_stone_appearance(node: Node, is_stone: bool) -> void:
	if node is MeshInstance3D:
		var mat := node.material_override as BaseMaterial3D
		if is_instance_valid(mat):
			if is_stone:
				mat.albedo_color = Color(0.48, 0.48, 0.50)
				mat.roughness = 1.0
			else:
				mat.albedo_color = Color(1.0, 1.0, 1.0)
				mat.roughness = 0.5
				
	for child in node.get_children():
		_traverse_and_apply_stone_appearance(child, is_stone)


func _bite_player() -> void:
	if is_instance_valid(player):
		var dir := (player.global_position - global_position).normalized()
		var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
		if player.has_method("take_damage"):
			player.call("take_damage", 1, knockback)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	if is_instance_valid(_model_node):
		_animation_time += delta
		var state := 0
		if has_meta(GargoyleAIBehavior.META_STATE):
			state = get_meta(GargoyleAIBehavior.META_STATE) as int
		
		if state == 1: 
			if is_instance_valid(_anim_player):
				var anims := _anim_player.get_animation_list()
				if anims.size() > 0:
					var target_anim: String = anims[0]
					if _anim_player.current_animation != target_anim or not _anim_player.is_playing():
						_anim_player.play(target_anim)
						
			var flat_velocity := Vector2(velocity.x, velocity.z)
			var is_moving := flat_velocity.length_squared() > 0.1
			var hover_bob := sin(_animation_time * 5.0) * 0.25
			_model_node.position.y = 2.5 + hover_bob
			
			if is_moving:
				_model_node.rotation.z = sin(_animation_time * 14.0) * 0.18
				_model_node.rotation.x = deg_to_rad(12.0)
			else:
				_model_node.rotation.z = sin(_animation_time * 2.0) * 0.05
				_model_node.rotation.x = 0.0
		else: 
			if is_instance_valid(_anim_player):
				_anim_player.stop()
				
			_model_node.position.y = lerp(_model_node.position.y, MODEL_BASE_Y, delta * 5.0)
			_model_node.rotation = _model_node.rotation.lerp(_model_base_rot, delta * 5.0)
			
		if is_instance_valid(_nameplate):
			var relative_offset := _model_node.position.y - MODEL_BASE_Y
			_nameplate.position.y = _collision_height + 0.35 + relative_offset


func _physics_process(delta: float) -> void:
	if domain_entity.is_dead:
		return

	var state := 0
	if has_meta(GargoyleAIBehavior.META_STATE):
		state = get_meta(GargoyleAIBehavior.META_STATE) as int

	if state == 0: 
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
	else: 
		velocity.y = move_toward(velocity.y, 0.0, SPEED * delta)

	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)

	_apply_absolute_boundary_forcefield(delta)
	
	# Symmetrical interface update tick (Resolves empty invisible nameplate)
	quest_check_timer -= delta
	if quest_check_timer <= 0.0:
		quest_check_timer = 0.5
		_update_quest_bubble_state()
		
	move_and_slide()
