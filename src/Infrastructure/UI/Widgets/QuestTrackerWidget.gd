# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/QuestTrackerWidget.gd
# Description: Infrastructure UI Widget managing active quest objective displays,
#              distance calculations, progress bars, and reactive notifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuestTrackerWidget
extends Control

var player: CharacterBody3D

@onready var _header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel

var _last_active_quest_id: String = ""
var _last_active_quest_title: String = ""
var _is_first_frame: bool = true


func _ready() -> void:
	visible = false
	_connect_domain_quest_signals()


func _connect_domain_quest_signals() -> void:
	QuestService._ensure_initialized()
	if is_instance_valid(QuestService.instance):
		QuestService.instance.active_quest_changed.connect(_on_active_quest_changed)


func _on_active_quest_changed(_new_quest: Quest) -> void:
	AudioService.play_sfx_static("loot_pickup")
	update_widget()


## Real-time metric updater called from HUD loop.
func update_widget() -> void:
	if not is_instance_valid(player):
		return
		
	var active_quest := QuestService.get_active_quest()
	_process_quest_notification_dispatch(active_quest)
	
	if active_quest != null:
		visible = true
		_title_label.text = tr(active_quest.title)
		_header_label.text = tr("HUD_ACTIVE_MISSION")
		_evaluate_active_quest_objective(active_quest)
	else:
		visible = false


func _evaluate_active_quest_objective(active_quest: Quest) -> void:
	var p_pos := player.global_position
	var dist_q := int(p_pos.distance_to(active_quest.target_position))
	
	if active_quest.quest_id == "cloud_ascent":
		_process_height_objective(active_quest, int(round(p_pos.y)))
	elif active_quest.required_item_index >= 0 and active_quest.required_quantity > 0:
		_process_gathering_objective(active_quest, dist_q)
	else:
		_process_arrival_objective(active_quest, dist_q)


func _process_height_objective(active_quest: Quest, current_y: int) -> void:
	_objective_label.text = "%s\n%s: Y=%d / 18" % [tr(active_quest.objective_text), tr("QUEST_CURRENT_HEIGHT"), current_y]
	if current_y >= 18:
		QuestService.complete_active_quest(player)


func _process_gathering_objective(active_quest: Quest, dist_q: int) -> void:
	_objective_label.text = "%s\n%s: %d / %d\n%s: %dm" % [
		tr(active_quest.objective_text), tr("QUEST_PROGRESS"),
		active_quest.progress_counter, active_quest.required_quantity,
		tr("QUEST_DISTANCE_PREFIX"), dist_q
	]
	if active_quest.progress_counter >= active_quest.required_quantity:
		QuestService.complete_active_quest(player)


func _process_arrival_objective(active_quest: Quest, dist_q: int) -> void:
	if dist_q <= active_quest.target_range:
		if active_quest.autocomplete_on_arrival:
			QuestService.complete_active_quest(player)
		else:
			_objective_label.text = "%s\n[ %s ]" % [tr(active_quest.objective_text), tr("QUEST_REACHED_INTERACT")]
	else:
		_objective_label.text = "%s\n%s: %dm" % [tr(active_quest.objective_text), tr("QUEST_DISTANCE_PREFIX"), dist_q]


func _process_quest_notification_dispatch(active_quest: Quest) -> void:
	if _is_first_frame:
		if active_quest != null:
			_last_active_quest_id = active_quest.quest_id
			_last_active_quest_title = active_quest.title
		_is_first_frame = false
		return
		
	if active_quest == null and _last_active_quest_id != "":
		_notify_hud("CAMPAIGN_COMPLETE_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = ""
		_last_active_quest_title = ""
	elif active_quest != null and active_quest.quest_id != _last_active_quest_id:
		_notify_hud("QUEST_COMPLETED_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = active_quest.quest_id
		_last_active_quest_title = active_quest.title


func _notify_hud(header_key: String, title: String) -> void:
	var parent_hud := get_parent() as PlayerHUD
	if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
		parent_hud.call("show_quest_notification", header_key, title)
