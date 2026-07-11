# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/PauseMenuWidget.gd
# Description: SRP-compliant UI Widget strictly managing Pause Menu input routing,
#              dynamic translations, and transition animations. Layout is defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PauseMenuWidget
extends Panel

var hud_orchestrator: PlayerHUD
var _settings_overlay: SettingsMenu

const SETTINGS_MENU_SCENE := preload("res://src/Infrastructure/UI/settings_menu.tscn")

@onready var _menu_card: Panel = $CenterContainer/MenuCard
@onready var _resume_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/ResumeButton
@onready var _settings_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/SettingsButton
@onready var _quit_btn: Button = $CenterContainer/MenuCard/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
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
