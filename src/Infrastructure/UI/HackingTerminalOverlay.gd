# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/HackingTerminalOverlay.gd
# Description: Infrastructure UI Coordinator managing the Cyber Hacking minigame,
#              screen-space double vision glitch effects, puzzle matrix states, 
#              and victory/failure conditions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HackingTerminalOverlay
extends Panel

signal hacked_successfully
signal closed

const GRID_SIZE: int = 4
const TIME_LIMIT_SEC: float = 60.0
const NODE_BTN_SCENE := preload("res://src/Infrastructure/UI/Widgets/hacking_node_button.tscn")
const GLITCH_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/screen_double_vision.gdshader"

const COLOR_LOCKED := Color(0.95, 0.15, 0.15)
const COLOR_SUCCESS := Color(0.2, 0.95, 0.35)
const COLOR_NORMAL := Color(1.0, 1.0, 1.0)

@onready var _grid_container: GridContainer = $TerminalCard/MarginContainer/VBoxContainer/PuzzleGrid
@onready var _timer_label: Label = $TerminalCard/MarginContainer/VBoxContainer/HeaderHBox/TimerLabel
@onready var _status_label: Label = $TerminalCard/MarginContainer/VBoxContainer/StatusLabel
@onready var _close_btn: Button = $TerminalCard/MarginContainer/VBoxContainer/CloseButton

var _grid_state: Array[bool] = []
var _time_remaining: float = TIME_LIMIT_SEC
var _is_active: bool = false
var _buttons: Array[Button] = []

var _glitch_overlay: ColorRect
var _glitch_material: ShaderMaterial


func _ready() -> void:
	_close_btn.pressed.connect(_on_close_pressed)
	_setup_screen_glitch_overlay()
	_initialize_puzzle_grid()
	_scramble_grid()
	
	_is_active = true
	_status_label.text = tr("HACKING_STATUS_LOCKED")
	_status_label.modulate = COLOR_LOCKED


func _setup_screen_glitch_overlay() -> void:
	if not ResourceLoader.exists(GLITCH_SHADER_PATH):
		return
		
	_glitch_overlay = ColorRect.new()
	_glitch_overlay.name = "ScreenGlitchOverlay"
	_glitch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_glitch_material = ShaderMaterial.new()
	_glitch_material.shader = load(GLITCH_SHADER_PATH) as Shader
	_glitch_material.set_shader_parameter("opacity", 0.15)
	_glitch_overlay.material = _glitch_material
	
	add_child(_glitch_overlay)
	move_child(_glitch_overlay, 0)


func _process(delta: float) -> void:
	if not _is_active:
		return
		
	_time_remaining -= delta
	_update_timer_display()
	
	if _time_remaining <= 0.0:
		_execute_hack_failure()


func _initialize_puzzle_grid() -> void:
	_grid_state.resize(GRID_SIZE * GRID_SIZE)
	_grid_container.columns = GRID_SIZE
	
	for i in range(GRID_SIZE * GRID_SIZE):
		var btn := NODE_BTN_SCENE.instantiate() as Button
		btn.pressed.connect(_on_node_clicked.bind(i))
		_grid_container.add_child(btn)
		_buttons.append(btn)


func _scramble_grid() -> void:
	for i in range(_grid_state.size()):
		_grid_state[i] = true 
		
	var simulation_clicks := randi_range(8, 15)
	for i in range(simulation_clicks):
		_toggle_node_and_neighbors(randi() % _grid_state.size())
		
	_refresh_grid_visuals()


func _on_node_clicked(index: int) -> void:
	if not _is_active:
		return
		
	AudioService.play_sfx_static("ui_click")
	_trigger_glitch_pulse(0.45, 0.018)
	_toggle_node_and_neighbors(index)
	_refresh_grid_visuals()
	_check_win_condition()


func _trigger_glitch_pulse(target_opacity: float, target_split: float) -> void:
	if not is_instance_valid(_glitch_material):
		return
		
	_glitch_material.set_shader_parameter("double_vision_split", target_split)
	var tw := create_tween()
	tw.tween_property(_glitch_material, "shader_parameter/opacity", target_opacity, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glitch_material, "shader_parameter/opacity", 0.15, 0.20).set_trans(Tween.TRANS_SINE)


func _toggle_node_and_neighbors(index: int) -> void:
	var x := index % GRID_SIZE
	var y := floori(float(index) / float(GRID_SIZE))
	
	_toggle_cell(x, y)
	_toggle_cell(x - 1, y)
	_toggle_cell(x + 1, y)
	_toggle_cell(x, y - 1)
	_toggle_cell(x, y + 1)


func _toggle_cell(x: int, y: int) -> void:
	if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
		var idx := x + (y * GRID_SIZE)
		_grid_state[idx] = not _grid_state[idx]


func _refresh_grid_visuals() -> void:
	for i in range(_buttons.size()):
		var btn: Button = _buttons[i]
		if btn.has_method("set_node_state"):
			btn.call("set_node_state", _grid_state[i])


func _update_timer_display() -> void:
	var seconds := max(0, int(ceil(_time_remaining)))
	_timer_label.text = tr("HACKING_TIMER_FORMAT") % seconds
	_timer_label.label_settings.font_color = COLOR_LOCKED if seconds <= 10 else COLOR_NORMAL


func _check_win_condition() -> void:
	for state: bool in _grid_state:
		if not state:
			return
	_execute_hack_success()


func _execute_hack_success() -> void:
	_is_active = false
	_status_label.text = tr("HACKING_STATUS_SUCCESS")
	_status_label.modulate = COLOR_SUCCESS
	_trigger_glitch_pulse(0.80, 0.035)
	AudioService.play_sfx_static("chest_open")
	
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void:
		hacked_successfully.emit()
		_on_close_pressed()
	)


func _execute_hack_failure() -> void:
	_is_active = false
	_status_label.text = tr("HACKING_STATUS_FAILURE")
	_status_label.modulate = COLOR_LOCKED
	_trigger_glitch_pulse(1.00, 0.05)
	
	for btn: Button in _buttons:
		if btn.has_method("set_locked_state"):
			btn.call("set_locked_state")
			
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(_on_close_pressed)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
