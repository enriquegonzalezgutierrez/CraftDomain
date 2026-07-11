# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/QuestTrackerWidget.gd
# Description: Infrastructure UI Widget responsible ONLY for updating the 
#              active quest objectives, distance, and inventory progress texts.
#              Layout and styling are strictly delegated to its .tscn scene.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuestTrackerWidget
extends Control

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D

@onready var _header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _objective_label: Label = $MarginContainer/VBoxContainer/ObjectiveLabel

var _last_active_quest_id: String = ""
var _last_active_quest_title: String = ""
var _is_first_frame: bool = true


func _ready() -> void:
	# Start hidden until a quest is actively loaded
	visible = false 


## Real-time metric updater: Decoupled quest evaluation loop
func update_widget() -> void:
	if not is_instance_valid(player):
		return
		
	var active_quest := QuestService.get_active_quest()
	_process_quest_notification_dispatch(active_quest)
	
	if active_quest != null:
		visible = true
		_title_label.text = tr(active_quest.title) # Localize dynamic JSON title
		_header_label.text = tr("HUD_ACTIVE_MISSION") # Localize heading
		
		var p_pos := player.global_position
		var dist_q := int(p_pos.distance_to(active_quest.target_position))
		
		# --- CASE A: SPECIAL HEIGHT COMPLETION ---
		if active_quest.quest_id == "cloud_ascent":
			var current_y := int(round(p_pos.y))
			_objective_label.text = "%s\n%s: Y=%d / 18" % [
				tr(active_quest.objective_text), 
				tr("QUEST_CURRENT_HEIGHT"), 
				current_y
			]
			if current_y >= 18:
				QuestService.complete_active_quest(player)
				
		# --- CASE B: INVENTORY GATHERING COMPLETION (UNIFIED WITH DISTANCE) ---
		elif active_quest.required_item_index >= 0 and active_quest.required_quantity > 0:
			# Render both: current stock progress AND current distance to natural resources hotspot
			_objective_label.text = "%s\n%s: %d / %d\n%s: %dm" % [
				tr(active_quest.objective_text), 
				tr("QUEST_PROGRESS"),
				active_quest.progress_counter, 
				active_quest.required_quantity,
				tr("QUEST_DISTANCE_PREFIX"),
				dist_q
			]
			
			if active_quest.progress_counter >= active_quest.required_quantity:
				QuestService.complete_active_quest(player)
				
		# --- CASE C: GEOGRAPHIC ARRIVAL COMPLETION ---
		else:
			if dist_q <= active_quest.target_range:
				if active_quest.autocomplete_on_arrival:
					QuestService.complete_active_quest(player)
				else:
					_objective_label.text = "%s\n[ %s ]" % [
						tr(active_quest.objective_text), 
						tr("QUEST_REACHED_INTERACT")
					]
			else:
				_objective_label.text = "%s\n%s: %dm" % [
					tr(active_quest.objective_text), 
					tr("QUEST_DISTANCE_PREFIX"), 
					dist_q
				]
	else:
		visible = false


func _process_quest_notification_dispatch(active_quest: Quest) -> void:
	if _is_first_frame:
		if active_quest != null:
			_last_active_quest_id = active_quest.quest_id
			_last_active_quest_title = active_quest.title
		_is_first_frame = false
		return
		
	# Case 1: Active quest transitioned from valid to null (Final quest of campaign complete)
	if active_quest == null and _last_active_quest_id != "":
		# Explicit static typing on parent HUD reference
		var parent_hud: PlayerHUD = get_parent() as PlayerHUD
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "CAMPAIGN_COMPLETE_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = ""
		_last_active_quest_title = ""
		
	# Case 2: Active quest transitioned to a new campaign link
	elif active_quest != null and active_quest.quest_id != _last_active_quest_id:
		# Explicit static typing on parent HUD reference
		var parent_hud: PlayerHUD = get_parent() as PlayerHUD
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "QUEST_COMPLETED_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = active_quest.quest_id
		_last_active_quest_title = active_quest.title
