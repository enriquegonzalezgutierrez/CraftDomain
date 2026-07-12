# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/HostileEntity.gd
# Description: Physical character controller representing a hostile Cave Zombie.
#              Sanitization is delegated strictly to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HostileEntity
extends PassiveEntity

const BASE_MODEL_PATH := "res://assets/models/mobs/zombie/zombie_base.fbx"

var player: CharacterBody3D
var _quest_bubble: Node3D

const COOLDOWN_GROAN_MIN_SEC: float = 10.0
const COOLDOWN_GROAN_MAX_SEC: float = 22.0

var _groan_timer: float = randf_range(3.0, 10.0)


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	name = "Entity_ZOMBIE"


func _ready() -> void:
	add_to_group("hostiles")
	if is_in_group("passives"):
		remove_from_group("passives") 
	
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	_setup_graphics_representation()
	_locate_player()
	_setup_nameplate_height()
	_setup_quest_bubble()
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	if not is_instance_valid(ai_component):
		ai_component = NPCAIComponent.new()
		add_child(ai_component)
		
	if is_instance_valid(ai_component):
		ai_component.active_behavior = ZombieAIBehavior.new()


func _setup_graphics_representation() -> void:
	if FileAccess.file_exists(BASE_MODEL_PATH):
		_build_glb_representation()
	else:
		_build_procedural_representation()


func _build_glb_representation() -> void:
	var strategy_script := load("res://src/Infrastructure/Life/SkeletalVisualRepresentation.gd") as GDScript
	if strategy_script == null:
		_build_procedural_representation()
		return
		
	var strategy: Resource = strategy_script.new()
	strategy.set("base_model_path", BASE_MODEL_PATH)
	
	strategy.set("anim_idle_path", ANIM_DIR + "zombie/zombie_idle.fbx")
	strategy.set("anim_walk_path", ANIM_DIR + "zombie/zombie_walk.fbx")
	strategy.set("anim_attack_path", ANIM_DIR + "zombie/zombie_attack.fbx")
	strategy.set("anim_jump_path", ANIM_DIR + "zombie/zombie_jump.fbx")
	
	visual_representation = strategy as IEntityVisualRepresentation
	visual_representation.build_representation(self, visual_component.body_bob_node)


func _build_procedural_representation() -> void:
	var skin_color := Color(0.45, 0.55, 0.42) 
	var shirt_color := Color(0.12, 0.45, 0.55) 
	var pants_color := Color(0.24, 0.22, 0.32) 
	
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(-0.1, 0.275, 0.0), pants_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.16, 0.55, 0.18), Vector3(0.1, 0.275, 0.0), pants_color)
	visual_component.create_box(visual_component.body_bob_node, Vector3(0.44, 0.75, 0.32), Vector3(0, 0.925, 0), shirt_color)
	
	visual_component.head_node = Node3D.new()
	visual_component.head_node.name = "HumanHead"
	visual_component.head_node.position = Vector3(0, 1.3, 0)
	visual_component.body_bob_node.add_child(visual_component.head_node)
	visual_component.create_box(visual_component.head_node, Vector3(0.35, 0.38, 0.35), Vector3(0, 0.19, 0), skin_color)
	visual_component.create_box(visual_component.head_node, Vector3(0.08, 0.15, 0.08), Vector3(0.0, 0.12, -0.21), skin_color * 0.9)


func _setup_quest_bubble() -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var sb_script := load("res://src/Infrastructure/UI/SpeechBubble.gd") as Script
		if sb_script != null:
			_quest_bubble = sb_script.new() as Node3D
			_quest_bubble.name = "QuestBubble"
			add_child(_quest_bubble)
			_quest_bubble.call("set_text", tr("BUBBLE_TARGET_MONSTER"))
			_quest_bubble.position = Vector3(0.0, _collision_height + 0.65, 0.0)


func _get_entity_name_key() -> String:
	return "NPC_NAME_ZOMBIE"


func _get_nameplate_color() -> Color:
	return Color(0.95, 0.15, 0.15) 


func _get_humanoid_role() -> int:
	return -1 


func _has_ui_decorations() -> bool:
	return true


func _locate_player() -> void:
	var world_node := get_parent()
	if is_instance_valid(world_node) and "player" in world_node:
		player = world_node.get("player") as CharacterBody3D


func _on_domain_entity_took_damage(_amount: int) -> void:
	pass 


func _drop_loot(inv: IInventory) -> void:
	inv.consume_item(15, 1) 
	
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "plains_defender":
		var _un := inv.add_item(active_q.reward_item_index, active_q.reward_quantity)
		if is_instance_valid(player):
			QuestService.complete_active_quest(player)


func _play_zombie_groan() -> void:
	AudioService.play_sfx_static("zombie_groan", global_position)


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_groan_timer -= delta
		if _groan_timer <= 0.0:
			_groan_timer = randf_range(COOLDOWN_GROAN_MIN_SEC, COOLDOWN_GROAN_MAX_SEC)
			_play_zombie_groan()
