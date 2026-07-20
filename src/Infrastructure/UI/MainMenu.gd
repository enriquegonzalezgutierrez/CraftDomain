# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/MainMenu.gd
# Description: Tactile Glassmorphic Main Menu controller. Handles game boots,
#              modal popups, cooperative lobby connections, and author attribution.
#              REFACTORED: Converted compile-time preloads to runtime load calls
#              to immunize the startup compiler from Windows file-locking race conditions.
#              COMPLIANCE: Decomposed monolithic methods into < 20 line helpers.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MainMenu
extends Control

signal play_pressed(should_clear_save: bool)
signal showcase_pressed 

var _settings_overlay: SettingsMenu
var _lobby_overlay: MultiplayerLobbyWidget
var _has_save_game: bool = false

@onready var _title_label: Label = $CenterContainer/MasterVBox/GameTitle
@onready var _menu_card: PanelContainer = $CenterContainer/MasterVBox/MenuCard

@onready var _play_continue_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/PlayButton
@onready var _multiplayer_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/MultiplayerButton
@onready var _new_game_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/NewGameButton
@onready var _showcase_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/ShowcaseButton
@onready var _settings_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/SettingsButton
@onready var _exit_btn: Button = $CenterContainer/MasterVBox/MenuCard/CardMargin/VBoxContainer/ExitButton

@onready var _confirm_modal: Panel = $ConfirmationModal
@onready var _modal_card: PanelContainer = $ConfirmationModal/CenterContainer/ModalCard
@onready var _modal_title: Label = $ConfirmationModal/CenterContainer/ModalCard/ModalMargin/VBoxContainer/ModalTitle
@onready var _modal_desc: Label = $ConfirmationModal/CenterContainer/ModalCard/ModalMargin/VBoxContainer/ModalDesc
@onready var _modal_confirm_btn: Button = $ConfirmationModal/CenterContainer/ModalCard/ModalMargin/VBoxContainer/HBoxContainer/ConfirmButton
@onready var _modal_cancel_btn: Button = $ConfirmationModal/CenterContainer/ModalCard/ModalMargin/VBoxContainer/HBoxContainer/CancelButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_has_save_game = FileAccess.file_exists("user://world_save/global_save.json")
	
	_connect_menu_signals()
	_refresh_localized_text()
	_play_entry_animation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()
	elif what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stop_video_stream()


func _process(delta: float) -> void:
	if is_instance_valid(_title_label):
		var speed_scale := float(Time.get_ticks_msec()) / 1000.0 * 1.5
		var anim_y := _title_label.position.y + sin(speed_scale) * 0.4
		_title_label.position.y = lerp(_title_label.position.y, anim_y, delta * 5.0)


func _connect_menu_signals() -> void:
	_play_continue_btn.pressed.connect(_on_play_pressed)
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	
	if _has_save_game:
		_new_game_btn.visible = true
		_new_game_btn.pressed.connect(_on_new_game_clicked_with_save)
	else:
		_new_game_btn.visible = false
		
	_showcase_btn.pressed.connect(func() -> void: showcase_pressed.emit())
	_settings_btn.pressed.connect(_on_settings_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)
	
	_modal_confirm_btn.pressed.connect(_on_overwrite_confirmed)
	_modal_cancel_btn.pressed.connect(_on_overwrite_cancelled)


func _refresh_localized_text() -> void:
	if is_instance_valid(_play_continue_btn):
		_play_continue_btn.text = tr("MENU_CONTINUE") if _has_save_game else tr("MENU_PLAY_WORLD")
	if is_instance_valid(_multiplayer_btn):
		_multiplayer_btn.text = tr("MENU_MULTIPLAYER").to_upper()
	if is_instance_valid(_new_game_btn):
		_new_game_btn.text = tr("MENU_NEW_GAME")
	if is_instance_valid(_showcase_btn):
		_showcase_btn.text = tr("MENU_ASSET_SHOWCASE")
	if is_instance_valid(_settings_btn):
		_settings_btn.text = tr("MENU_SETTINGS")
	if is_instance_valid(_exit_btn):
		_exit_btn.text = tr("MENU_EXIT")
		
	_refresh_text_title()
	_refresh_modal_labels()
	_refresh_copyright_label()


func _refresh_text_title() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = tr("MENU_GAME_TITLE").to_upper()


func _refresh_copyright_label() -> void:
	var copyright := get_node_or_null("CenterContainer/MasterVBox/CopyrightLabel") as Label
	if is_instance_valid(copyright):
		copyright.text = tr("MENU_COPYRIGHT")


func _refresh_modal_labels() -> void:
	if is_instance_valid(_modal_title):
		_modal_title.text = tr("MENU_RESET_WARNING_TITLE")
	if is_instance_valid(_modal_desc):
		_modal_desc.text = tr("MENU_RESET_WARNING_DESC")
	if is_instance_valid(_modal_confirm_btn):
		_modal_confirm_btn.text = tr("MENU_RESET_CONFIRM")
	if is_instance_valid(_modal_cancel_btn):
		_modal_cancel_btn.text = tr("MENU_RESET_CANCEL")


func _play_entry_animation() -> void:
	modulate.a = 0.0
	_menu_card.scale = Vector2(0.9, 0.9)
	_title_label.scale = Vector2(0.9, 0.9)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_play_pressed() -> void:
	play_pressed.emit(not _has_save_game)


func _on_multiplayer_pressed() -> void:
	var lobby_menu_scene := load("res://src/Infrastructure/UI/Widgets/multiplayer_lobby_widget.tscn") as PackedScene
	if is_instance_valid(lobby_menu_scene):
		_lobby_overlay = lobby_menu_scene.instantiate() as MultiplayerLobbyWidget
		_lobby_overlay.closed.connect(_on_lobby_closed)
		add_child(_lobby_overlay)


func _on_lobby_closed() -> void:
	if is_instance_valid(_lobby_overlay):
		_lobby_overlay.queue_free()
		_lobby_overlay = null


func _on_new_game_clicked_with_save() -> void:
	_confirm_modal.visible = true
	_confirm_modal.modulate.a = 0.0
	_modal_card.scale = Vector2(0.9, 0.9)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_modal_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_overwrite_confirmed() -> void:
	_confirm_modal.visible = false
	_has_save_game = false
	play_pressed.emit(true)


func _on_overwrite_cancelled() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_modal, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_modal_card, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void: _confirm_modal.visible = false)


func _on_settings_pressed() -> void:
	var settings_menu_scene := load("res://src/Infrastructure/UI/settings_menu.tscn") as PackedScene
	if is_instance_valid(settings_menu_scene):
		_settings_overlay = settings_menu_scene.instantiate() as SettingsMenu
		_settings_overlay.closed.connect(_on_settings_closed)
		add_child(_settings_overlay)


func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()


func _stop_video_stream() -> void:
	var video := get_node_or_null("MenuBackground") as VideoStreamPlayer
	if is_instance_valid(video):
		video.stop()


func _on_exit_pressed() -> void:
	_stop_video_stream()
	get_tree().quit()