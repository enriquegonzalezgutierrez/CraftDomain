# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/PauseMenuWidget.gd
# Description: SRP-compliant UI Widget strictly managing Pause Menu input routing,
#              dynamic translations, transition animations, and interactive lobby 
#              code copying functionality (UX).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PauseMenuWidget
extends Panel

var hud_orchestrator: PlayerHUD
var _settings_overlay: SettingsMenu

const SETTINGS_MENU_SCENE := preload("res://src/Infrastructure/UI/settings_menu.tscn")

@onready var _menu_card: Panel = $CenterContainer/MenuCard
@onready var _copy_code_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/CopyCodeButton
@onready var _resume_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/ResumeButton
@onready var _settings_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/SettingsButton
@onready var _quit_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/QuitButton

var _active_code_cache: String = ""


func _ready() -> void:
	_copy_code_btn.pressed.connect(_on_copy_code_pressed)
	_resume_btn.pressed.connect(_on_resume_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	
	_refresh_localized_text()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_localized_text()


## Dynamically translates the pause buttons texts (i18n compliant)
func _refresh_localized_text() -> void:
	if is_instance_valid(_resume_btn):
		_resume_btn.text = tr("HUD_PAUSE_RESUME")
	if is_instance_valid(_settings_btn):
		_settings_btn.text = tr("HUD_PAUSE_SETTINGS")
	if is_instance_valid(_quit_btn):
		_quit_btn.text = tr("HUD_PAUSE_QUIT")


## Plays an organic, elastic transition in/out of the pause overlay
func toggle_menu(p_visible: bool) -> void:
	var tween := create_tween().set_parallel(true)
	
	if p_visible:
		visible = true
		modulate.a = 0.0
		_menu_card.scale = Vector2(0.95, 0.95)
		
		_evaluate_network_lobby_code_display()
		
		tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_menu_card, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(_menu_card, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		tween.chain().tween_callback(func() -> void:
			visible = false
			if is_instance_valid(_settings_overlay):
				_settings_overlay.queue_free()
		)


func _evaluate_network_lobby_code_display() -> void:
	if not is_instance_valid(_copy_code_btn):
		return
		
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var net_service := bootstrap.get("network_service") as NetworkService
		if is_instance_valid(net_service) and net_service.active_join_code != "":
			_active_code_cache = net_service.active_join_code
			_copy_code_btn.text = tr("LOBBY_COPY_CODE") % _active_code_cache
			_copy_code_btn.visible = true
			DisplayServer.clipboard_set(_active_code_cache)
		else:
			_copy_code_btn.visible = false


func _on_copy_code_pressed() -> void:
	if _active_code_cache != "":
		DisplayServer.clipboard_set(_active_code_cache)
		AudioService.play_sfx_static("loot_pickup")
		
		if is_instance_valid(_copy_code_btn):
			_copy_code_btn.text = tr("LOBBY_CODE_COPIED")
			var feedback_timer := get_tree().create_timer(1.8)
			feedback_timer.timeout.connect(func() -> void:
				if is_instance_valid(_copy_code_btn) and _active_code_cache != "":
					_copy_code_btn.text = tr("LOBBY_COPY_CODE") % _active_code_cache
			)


func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toggle_menu(false)


func _on_settings_pressed() -> void:
	_settings_overlay = SETTINGS_MENU_SCENE.instantiate() as SettingsMenu
	_settings_overlay.closed.connect(_on_settings_closed)
	add_child(_settings_overlay)


func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()


func _on_quit_pressed() -> void:
	var bootstrap: Bootstrap = get_node_or_null("/root/Bootstrap") as Bootstrap
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")
