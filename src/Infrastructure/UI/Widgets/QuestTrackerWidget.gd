# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              active quest objectives, distance, and inventory progress bars.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating quest tracking layouts and metrics.
#              UPGRADED: Added a state machine to track quest transitions and 
#              dispatch sliding completion toast notifications to the parent HUD.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/QuestTrackerWidget.gd
# ==============================================================================
class_name QuestTrackerWidget
extends Panel

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D

var _title_label: Label
var _objective_label: Label

# ==============================================================================
# UPGRADE: Quest transition tracking states (Micro-Phase 6)
# ==============================================================================
var _last_active_quest_id: String = ""
var _last_active_quest_title: String = ""
var _is_first_frame: bool = true

func _ready() -> void:
	name = "QuestTrackerWidget"
	custom_minimum_size = Vector2(260, 110)
	size = Vector2(260, 110)
	
	# Glassmorphic dark slate card style
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.08, 0.08, 0.1, 0.6) 
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 0.7)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.25)
	add_theme_stylebox_override("panel", style)
	
	# Margin Layout
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)
	
	# Header Label
	var header := Label.new()
	header.text = "➔ ACTIVE MISSION"
	var hs := LabelSettings.new()
	hs.font_size = 11
	hs.font_color = Color(1.0, 0.85, 0.2) # Gold
	hs.outline_size = 2
	hs.outline_color = Color.BLACK
	header.label_settings = hs
	vbox.add_child(header)
	
	# Quest Title
	_title_label = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 14
	ts.font_color = Color.WHITE
	ts.outline_size = 3
	ts.outline_color = Color.BLACK
	_title_label.label_settings = ts
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_title_label)
	
	# Quest Objective
	_objective_label = Label.new()
	var os := LabelSettings.new()
	os.font_size = 11
	os.font_color = Color(0.85, 0.85, 0.9) 
	os.outline_size = 2
	os.outline_color = Color.BLACK
	_objective_label.label_settings = os
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_objective_label)

## Real-time metric updater: Decoupled quest evaluation loop
func update_widget() -> void:
	if not is_instance_valid(player):
		return
		
	var active_quest := QuestService.get_active_quest()
	
	# UPGRADE: Dispatch completed toast notifications upon quest state transitions
	_process_quest_notification_dispatch(active_quest)
	
	if active_quest != null:
		visible = true
		_title_label.text = active_quest.title
		
		var p_pos := player.global_position
		var dist_q := int(p_pos.distance_to(active_quest.target_position))
		
		# --- CASE A: SPECIAL HEIGHT COMPLETION (The Cloud Ascent) ---
		if active_quest.quest_id == "cloud_ascent":
			var current_y := int(round(p_pos.y))
			_objective_label.text = "%s\nCurrent Height: Y=%d / 18" % [active_quest.objective_text, current_y]
			if current_y >= 18:
				QuestService.complete_active_quest(player)
				
		# --- CASE B: INVENTORY GATHERING COMPLETION ---
		elif active_quest.required_item_index >= 0 and active_quest.required_quantity > 0:
			var inv: IInventory = player.get("inventory")
			var current_qty := 0
			if is_instance_valid(inv):
				current_qty = inv.get_slot_quantity(active_quest.required_item_index)
				
			_objective_label.text = "%s\nProgress: %d / %d" % [active_quest.objective_text, current_qty, active_quest.required_quantity]
			
			if current_qty >= active_quest.required_quantity:
				QuestService.complete_active_quest(player)
				
		# --- CASE C: GEOGRAPHIC ARRIVAL COMPLETION ---
		else:
			_objective_label.text = "%s\nDistance: %dm" % [active_quest.objective_text, dist_q]
			if active_quest.autocomplete_on_arrival and dist_q <= active_quest.target_range:
				QuestService.complete_active_quest(player)
	else:
		# Fallback state when all quests are finished
		visible = true
		_title_label.text = "All Quests Completed!"
		_objective_label.text = "Enjoy your infinite procedural voxel world."

# ==============================================================================
# UPGRADE: Process quest state changes to fire sliding toasts (Micro-Phase 6)
# ==============================================================================
func _process_quest_notification_dispatch(active_quest: Quest) -> void:
	if _is_first_frame:
		if active_quest != null:
			_last_active_quest_id = active_quest.quest_id
			_last_active_quest_title = active_quest.title
		_is_first_frame = false
		return
		
	# Case 1: Active quest transitioned from valid to null (Final quest of campaign complete)
	if active_quest == null and _last_active_quest_id != "":
		var parent_hud = get_parent()
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "Campaign Complete", _last_active_quest_title)
		_last_active_quest_id = ""
		_last_active_quest_title = ""
		
	# Case 2: Active quest transitioned to a new campaign link
	elif active_quest != null and active_quest.quest_id != _last_active_quest_id:
		var parent_hud = get_parent()
		if is_instance_valid(parent_hud) and parent_hud.has_method("show_quest_notification"):
			parent_hud.call("show_quest_notification", "Quest Completed", _last_active_quest_title)
		_last_active_quest_id = active_quest.quest_id
		_last_active_quest_title = active_quest.title
