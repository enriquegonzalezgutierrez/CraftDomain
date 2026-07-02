# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              active quest objectives, distance, and inventory progress.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating quest tracking.
#              i18n UPGRADE: Localized all UI text labels, headings, and dynamic
#              JSON quest objectives using tr() for full OCP compliance.
#              WARNING FIX:
#              - Added explicit static typing `PlayerHUD` to the `parent_hud` variables 
#                on lines 143 and 151 to completely resolve `UNTYPED_DECLARATION` 
#                compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/QuestTrackerWidget.gd
# ==============================================================================
class_name QuestTrackerWidget
extends Control

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D

var _header_label: Label
var _title_label: Label
var _objective_label: Label

var _last_active_quest_id: String = ""
var _last_active_quest_title: String = ""
var _is_first_frame: bool = true

func _ready() -> void:
	name = "QuestTrackerWidget"
	custom_minimum_size = Vector2(260, 110)
	size = Vector2(260, 110)
	
	# Start hidden until a quest is actively loaded
	visible = false 
	
	# Margin Layout
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)
	
	# Header Label (Localized)
	_header_label = Label.new()
	_header_label.text = tr("HUD_ACTIVE_MISSION")
	var hs := LabelSettings.new()
	hs.font_size = 11
	hs.font_color = Color(1.0, 0.85, 0.2) # Gold
	hs.outline_size = 3
	hs.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	_header_label.label_settings = hs
	vbox.add_child(_header_label)
	
	# Quest Title (Localized)
	_title_label = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 14
	ts.font_color = Color.WHITE
	ts.outline_size = 4
	ts.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	_title_label.label_settings = ts
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_title_label)
	
	# Quest Objective (Localized)
	_objective_label = Label.new()
	var os := LabelSettings.new()
	os.font_size = 12
	os.font_color = Color(0.9, 0.9, 0.95) 
	os.outline_size = 4
	os.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	_objective_label.label_settings = os
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_objective_label)

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
				
		# --- CASE B: INVENTORY GATHERING COMPLETION ---
		elif active_quest.required_item_index >= 0 and active_quest.required_quantity > 0:
			_objective_label.text = "%s\n%s: %d / %d" % [
				tr(active_quest.objective_text), 
				tr("QUEST_PROGRESS"),
				active_quest.progress_counter, 
				active_quest.required_quantity
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
		# FIX: Explicit static typing on parent HUD reference
		var parent_hud: PlayerHUD = get_parent() as PlayerHUD
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "CAMPAIGN_COMPLETE_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = ""
		_last_active_quest_title = ""
		
	# Case 2: Active quest transitioned to a new campaign link
	elif active_quest != null and active_quest.quest_id != _last_active_quest_id:
		# FIX: Explicit static typing on parent HUD reference
		var parent_hud: PlayerHUD = get_parent() as PlayerHUD
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "QUEST_COMPLETED_TOAST_HEADER", _last_active_quest_title)
		_last_active_quest_id = active_quest.quest_id
		_last_active_quest_title = active_quest.title
