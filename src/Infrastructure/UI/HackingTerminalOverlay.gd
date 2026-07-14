# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/HackingTerminalOverlay.gd
# Description: Infrastructure UI Coordinator managing the Cyber Hacking minigame.
#              Players must toggle a grid of nodes to pure Cyan to bypass the firewall.
#              Corrected: Silenced the explicit INTEGER_DIVISION compiler warning.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HackingTerminalOverlay
extends Panel

signal hacked_successfully
signal closed

const GRID_SIZE: int = 4
const TIME_LIMIT_SEC: float = 60.0

const COLOR_CYAN := Color(0.0, 0.95, 0.95, 0.85)
const COLOR_MAGENTA := Color(0.95, 0.0, 0.95, 0.85)
const COLOR_DIM := Color(0.12, 0.12, 0.15, 0.8)

@onready var _grid_container: GridContainer = $TerminalCard/MarginContainer/VBoxContainer/PuzzleGrid
@onready var _timer_label: Label = $TerminalCard/MarginContainer/VBoxContainer/HeaderHBox/TimerLabel
@onready var _status_label: Label = $TerminalCard/MarginContainer/VBoxContainer/StatusLabel
@onready var _close_btn: Button = $TerminalCard/MarginContainer/VBoxContainer/CloseButton

# Array representing the 2D grid: true = Cyan (Aligned), false = Magenta (Corrupted)
var _grid_state: Array[bool] = []
var _time_remaining: float = TIME_LIMIT_SEC
var _is_active: bool = false
var _buttons: Array[Button] = []


func _ready() -> void:
	_close_btn.pressed.connect(_on_close_pressed)
	_initialize_puzzle_grid()
	_scramble_grid()
	
	_is_active = true
	_status_label.text = "SYSTEM LOCKED: ALIGN ALL CONDUITS TO CYAN"
	_status_label.modulate = Color(0.95, 0.15, 0.15)


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
	
	var normal_style := StyleBoxFlat.new()
	normal_style.set_corner_radius_all(4)
	normal_style.border_width_bottom = 4
	
	for i in range(GRID_SIZE * GRID_SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Clone style dynamically to allow individual color overrides
		var unique_style := normal_style.duplicate() as StyleBoxFlat
		btn.add_theme_stylebox_override("normal", unique_style)
		btn.add_theme_stylebox_override("hover", unique_style)
		btn.add_theme_stylebox_override("pressed", unique_style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.pressed.connect(_on_node_clicked.bind(i))
		_grid_container.add_child(btn)
		_buttons.append(btn)


func _scramble_grid() -> void:
	for i in range(_grid_state.size()):
		_grid_state[i] = true # Start all cyan
		
	var simulation_clicks := randi_range(8, 15)
	for i in range(simulation_clicks):
		var random_index := randi() % _grid_state.size()
		_toggle_node_and_neighbors(random_index)
		
	_refresh_grid_visuals()


func _on_node_clicked(index: int) -> void:
	if not _is_active:
		return
		
	AudioService.play_sfx_static("ui_click")
	_toggle_node_and_neighbors(index)
	_refresh_grid_visuals()
	_check_win_condition()


func _toggle_node_and_neighbors(index: int) -> void:
	var x := index % GRID_SIZE
	
	# WARNING FIXED: Explicitly cast divisions to prevent narrowing conversions
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
		var is_cyan: bool = _grid_state[i]
		
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style != null:
			style.bg_color = COLOR_CYAN if is_cyan else COLOR_MAGENTA
			style.border_color = style.bg_color.darkened(0.4)


func _update_timer_display() -> void:
	var seconds := max(0, int(ceil(_time_remaining)))
	_timer_label.text = "T-MINUS: %02d SEC" % seconds
	
	if seconds <= 10:
		_timer_label.label_settings.font_color = Color(0.95, 0.15, 0.15)
	else:
		_timer_label.label_settings.font_color = Color(1.0, 1.0, 1.0)


func _check_win_condition() -> void:
	var is_won := true
	for state: bool in _grid_state:
		if not state:
			is_won = false
			break
			
	if is_won:
		_execute_hack_success()


func _execute_hack_success() -> void:
	_is_active = false
	_status_label.text = "FIREWALL BYPASSED. ACCESS GRANTED."
	_status_label.modulate = Color(0.2, 0.95, 0.35)
	AudioService.play_sfx_static("chest_open")
	
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void:
		hacked_successfully.emit()
		_on_close_pressed()
	)


func _execute_hack_failure() -> void:
	_is_active = false
	_status_label.text = "INTRUSION DETECTED. LOCKDOWN INITIATED."
	_status_label.modulate = Color(0.95, 0.15, 0.15)
	
	for btn: Button in _buttons:
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style != null:
			style.bg_color = COLOR_DIM
			style.border_color = Color.BLACK
			
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
