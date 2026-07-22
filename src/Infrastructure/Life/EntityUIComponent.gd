# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/EntityUIComponent.gd
# Description: Infrastructure Component managing floating UI decorations for 
#              NPCs (Nameplates, Speech Bubbles, and Quest Indicator Arrows).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EntityUIComponent
extends Node

const SPEECH_BUBBLE_SCENE := preload("res://src/Infrastructure/UI/speech_bubble.tscn")

var host: CharacterBody3D

var _nameplate: Label3D
var _bubble: Node3D
var _quest_arrow: MeshInstance3D
var _collision_height: float = 1.5


func initialize(p_host: CharacterBody3D, collision_height: float) -> void:
	host = p_host
	_collision_height = collision_height
	
	_setup_nameplate()
	_setup_quest_arrow()
	_setup_floating_bubble()


func update_ui_state(active_quest: Quest, quest_target_id: String) -> void:
	if not is_instance_valid(host):
		return
		
	var is_target := active_quest != null and quest_target_id == active_quest.quest_id
	
	_update_quest_arrow(is_target)
	_update_nameplate(is_target)
	_update_bubble(is_target)


func cleanup() -> void:
	if is_instance_valid(_nameplate): _nameplate.queue_free()
	if is_instance_valid(_bubble): _bubble.queue_free()
	if is_instance_valid(_quest_arrow): _quest_arrow.queue_free()


func _setup_nameplate() -> void:
	if not is_instance_valid(host) or is_instance_valid(_nameplate): return
		
	_nameplate = Label3D.new()
	_nameplate.name = "FloatingNameplate"
	_nameplate.pixel_size = 0.005
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = false
	_nameplate.render_priority = 5
	_nameplate.outline_modulate = Color.BLACK
	_nameplate.outline_size = 5
	_nameplate.position = Vector3(0.0, _collision_height + 0.35, 0.0)
	
	host.add_child(_nameplate)
	host.set("_nameplate", _nameplate)
	_apply_uniform_ui_scaling(_nameplate)


func _setup_quest_arrow() -> void:
	if not is_instance_valid(host) or is_instance_valid(_quest_arrow): return
		
	_quest_arrow = MeshInstance3D.new()
	_quest_arrow.name = "FloatingQuestArrow"
	
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.45, 0.22)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.4
	mat.no_depth_test = true
	mat.render_priority = 10
	
	prism.material = mat
	_quest_arrow.mesh = prism
	_quest_arrow.rotation.z = PI
	_quest_arrow.position = Vector3(0.0, _collision_height + 1.15, 0.0)
	_quest_arrow.visible = false
	
	host.add_child(_quest_arrow)
	host.set("_quest_arrow", _quest_arrow)
	_apply_uniform_ui_scaling(_quest_arrow)


func _setup_floating_bubble() -> void:
	var can_socialize: bool = host.call("_has_ui_decorations") if host.has_method("_has_ui_decorations") else false
	if not can_socialize or is_instance_valid(_bubble): return
		
	_bubble = SPEECH_BUBBLE_SCENE.instantiate() as Node3D
	host.add_child(_bubble)
	host.set("_bubble", _bubble)
	_bubble.position = Vector3(0.0, _collision_height + 0.65, 0.0)
	_apply_uniform_ui_scaling(_bubble)


func _update_quest_arrow(is_target: bool) -> void:
	if is_instance_valid(_quest_arrow):
		_quest_arrow.visible = is_target


func _update_nameplate(is_target: bool) -> void:
	if not is_instance_valid(_nameplate): return
		
	var base_name: String = tr(host.get("entity_name_key") as String).to_upper()
	var task_subtitle := _get_task_subtitle()
	
	if is_target:
		_nameplate.text = "⭐ " + base_name + " ⭐" + task_subtitle
		_nameplate.modulate = Color(1.0, 0.85, 0.2)
		_nameplate.no_depth_test = true
	else:
		_nameplate.text = base_name + task_subtitle
		_nameplate.modulate = host.call("_get_nameplate_color") as Color if host.has_method("_get_nameplate_color") else Color.WHITE
		_nameplate.no_depth_test = false
		
	_apply_uniform_ui_scaling(_nameplate)


func _update_bubble(is_target: bool) -> void:
	if not is_instance_valid(_bubble): return
		
	if is_target:
		_bubble.call("set_text", "⭐ [ " + tr("BUBBLE_ACTIVE_MISSION").to_upper() + " ] ⭐")
	else:
		var key: String = host.get("entity_name_key") as String
		if key == "NPC_NAME_MERCHANT":
			_bubble.call("set_text", tr("BUBBLE_TRADE"))
		elif key == "NPC_NAME_FARMER":
			_bubble.call("set_text", tr("BUBBLE_FARMER"))
		else:
			_bubble.call("set_text", tr("BUBBLE_TALK"))
			
	_apply_uniform_ui_scaling(_bubble)


func _get_task_subtitle() -> String:
	var ai: NPCAIComponent = host.get("ai_component") as NPCAIComponent if "ai_component" in host else null
	if not is_instance_valid(ai): return ""
		
	var task_name := "IDLE"
	var is_manual: bool = ai.get("is_manual_override") as bool if "is_manual_override" in ai else false
	var active_behavior: Resource = ai.get("active_behavior") as Resource if "active_behavior" in ai else null
	
	if not is_manual and active_behavior != null and active_behavior.has_method("get_active_state_name"):
		task_name = str(active_behavior.call("get_active_state_name", host))
	else:
		var task_val: int = ai.get("current_task") as int if "current_task" in ai else 0
		task_name = ai.call("_get_task_state_name", task_val) as String if ai.has_method("_get_task_state_name") else "IDLE"
		
	var lookup_key := task_name.replace("_", "").to_upper()
	if lookup_key == "WANDERING": lookup_key = "WANDER"
	elif lookup_key == "CHATTING": lookup_key = "CHAT"
	
	var translated := tr("SHOWCASE_TASK_" + lookup_key)
	if translated == "SHOWCASE_TASK_" + lookup_key:
		translated = task_name.replace("_", " ").to_upper()
		
	return "\n[ " + translated + " ]"


func _apply_uniform_ui_scaling(node: Node3D) -> void:
	if not is_instance_valid(host) or not is_instance_valid(node): return
	var global_scale_vec := host.global_transform.basis.get_scale()
	if global_scale_vec.x < 0.001 or global_scale_vec.y < 0.001 or global_scale_vec.z < 0.001: return
	node.scale = Vector3.ONE / global_scale_vec
