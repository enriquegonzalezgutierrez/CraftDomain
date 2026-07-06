# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Controller representing an isolated 3D Model 
#              Showcase and Asset Pipeline Diagnostics Sandbox.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                showcase layout and viewport rendering pipelines.
# PURE STATIC DIAGNOSTICS OVERHAUL:
#              - Removed "Simulate Walk". Entities are now completely frozen 
#                in their base bind-pose (no bobbing, no AI processes).
#              - Reintroduced strict `Vector3.ZERO` position clamping to completely 
#                prevent models from sinking, sliding, or drifting.
#              - Added "AUTO-ROTATE" toggle so developers can freeze the pedestal 
#                to perfectly inspect the Z-axis alignment.
#              - Neutral Studio Lighting: Swapped the colored neon rim lights (teal/magenta) 
#                for clean, white studio ambient lights to allow accurate texture diagnostics.
#              - Diagnostic UI Preservation: Retained SpeechBubble and FloatingQuestArrow 
#                nodes on the model so developers can verify dynamic vertical elevations.
#              - i18n Localization: Extracted and wrapped all hardcoded interface texts 
#                using the translation engine's `tr()`.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/ModelShowcase.gd
# ==============================================================================
class_name ModelShowcase
extends Panel

## Emitted when the user closes the showcase
signal closed

## Reference to the player (injected on instantiation)
var player: CharacterBody3D

# Internal Viewport and 3D nodes
var _viewport: SubViewport
var _camera: Camera3D
var _pedestal: Node3D
var _spotlight: SpotLight3D
var _ambient_light_left: OmniLight3D
var _ambient_light_right: OmniLight3D

# Procedural Voxel Treadmill nodes (Hologrid floor)
var _treadmill: MeshInstance3D
var _treadmill_mat: StandardMaterial3D

# Internal UI Nodes
var _list_container: VBoxContainer
var _title_label: Label
var _stats_label: Label
var _rotate_btn: Button

# Active showcase state tracking
var _active_node: Node3D
var _selected_asset_id: int = -1
var _is_rotating: bool = true

# Symmetrical catalog mapping
const ASSET_CATALOG: Dictionary = {
	"MOBS (LIVING ENTITIES)": [
		{"id": 0, "name": "NPC_NAME_PIG", "mesh_name": "pig.glb", "is_prop": false},
		{"id": 1, "name": "NPC_NAME_CHICKEN", "mesh_name": "chicken.glb", "is_prop": false},
		{"id": 2, "name": "NPC_NAME_SHEEP", "mesh_name": "sheep.glb", "is_prop": false},
		{"id": 3, "name": "NPC_NAME_COW", "mesh_name": "cow.glb", "is_prop": false},
		{"id": 10, "name": "NPC_NAME_ZOMBIE", "mesh_name": "zombie.glb", "is_prop": false},
		{"id": 11, "name": "NPC_NAME_SHARK", "mesh_name": "shark.glb", "is_prop": false},
		{"id": 12, "name": "NPC_NAME_GARGOYLE", "mesh_name": "gargoyle.glb", "is_prop": false},
		{"id": 13, "name": "NPC_NAME_GOBLIN", "mesh_name": "goblin.glb", "is_prop": false},
		{"id": 107, "name": "NPC_NAME_GOLEM", "mesh_name": "golem.glb", "is_prop": false},
		{"id": 201, "name": "NPC_NAME_TURTLE", "mesh_name": "turtle.glb", "is_prop": false},
		{"id": 204, "name": "NPC_NAME_FOX", "mesh_name": "fox.glb", "is_prop": false},
		{"id": 205, "name": "NPC_NAME_BIRD", "mesh_name": "yellow_bird.glb", "is_prop": false},
		{"id": 206, "name": "NPC_NAME_CAT", "mesh_name": "cat.glb", "is_prop": false},
		{"id": 207, "name": "NPC_NAME_PARROT", "mesh_name": "parrot.glb", "is_prop": false},
		{"id": 208, "name": "NPC_NAME_CRAB", "mesh_name": "crab.glb", "is_prop": false},
		{"id": 209, "name": "NPC_NAME_ELEPHANT", "mesh_name": "elephant.glb", "is_prop": false},
		{"id": 210, "name": "NPC_NAME_OCTOPUS", "mesh_name": "octopus.glb", "is_prop": false},
		{"id": 211, "name": "NPC_NAME_RACCOON", "mesh_name": "raccoon.glb", "is_prop": false},
		{"id": 212, "name": "NPC_NAME_GROWLITHE", "mesh_name": "growlithe.glb", "is_prop": false},
		{"id": 213, "name": "NPC_NAME_MONKEY", "mesh_name": "monkey.glb", "is_prop": false}
	],
	"DECORATIONS (STATIC PROPS)": [
		{"id": 200, "name": "NOTIFICATION_LOOT_FOUND_HEADER", "mesh_name": "chest.glb", "is_prop": true},
		{"id": 202, "name": "STREETLIGHT", "mesh_name": "streetlight_entity", "is_prop": true},
		{"id": 203, "name": "CAMPFIRE", "mesh_name": "campfire_entity", "is_prop": true},
		{"id": 213, "name": "NOTIFICATION_WISHING_WELL_HEADER", "mesh_name": "wishing_well_odyssey.glb", "is_prop": true},
		{"id": 215, "name": "NOTIFICATION_BARREL_SHATTERED_HEADER", "mesh_name": "barrel.glb", "is_prop": true}
	]
}


func _ready() -> void:
	# Fullscreen dark glassmorphic wash
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 0.98)
	add_theme_stylebox_override("panel", bg_style)
	
	_setup_showcase_ui()
	_populate_asset_list()
	_load_initial_empty_state()


func _setup_showcase_ui() -> void:
	var main_card := Panel.new()
	main_card.name = "ShowcaseCard"
	main_card.custom_minimum_size = Vector2(1000, 580)
	main_card.size = Vector2(1000, 580)
	main_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	main_card.offset_left = -500
	main_card.offset_right = 500
	main_card.offset_top = -290
	main_card.offset_bottom = 290
	
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(16)
	card_style.bg_color = Color(0.05, 0.05, 0.07, 0.96)
	card_style.border_width_left = 2; card_style.border_width_top = 2
	card_style.border_width_right = 2; card_style.border_width_bottom = 2
	card_style.border_color = Color(0.3, 0.85, 1.0, 0.4) 
	card_style.shadow_size = 25; card_style.shadow_color = Color(0, 0, 0, 0.5)
	main_card.add_theme_stylebox_override("panel", card_style)
	add_child(main_card)
	
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	main_card.add_child(hbox)
	
	# ==============================================================================
	# LEFT PANE: ASSET DIRECTORY
	# ==============================================================================
	var left_pane := MarginContainer.new()
	left_pane.custom_minimum_size = Vector2(360, 0)
	left_pane.add_theme_constant_override("margin_left", 24)
	left_pane.add_theme_constant_override("margin_top", 24)
	left_pane.add_theme_constant_override("margin_right", 12)
	left_pane.add_theme_constant_override("margin_bottom", 24)
	hbox.add_child(left_pane)
	
	var left_vbox := VBoxContainer.new()
	left_pane.add_child(left_vbox)
	
	var catalog_title := Label.new()
	catalog_title.text = tr("SHOWCASE_TITLE").to_upper() # Localized Title
	var ts := LabelSettings.new()
	ts.font_size = 18; ts.font_color = Color(0.2, 0.85, 0.85); ts.outline_size = 4; ts.outline_color = Color.BLACK
	catalog_title.label_settings = ts
	left_vbox.add_child(catalog_title)
	
	left_vbox.add_child(_create_spacer(14))
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)
	
	# ==============================================================================
	# RIGHT PANE: Isolated 3D Viewport
	# ==============================================================================
	var right_pane := Panel.new()
	right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.04, 0.04, 0.05, 0.6)
	right_style.set_corner_radius_all(14)
	right_style.border_width_left = 1; right_style.border_color = Color(0.25, 0.25, 0.3, 0.2)
	right_pane.add_theme_stylebox_override("panel", right_style)
	hbox.add_child(right_pane)
	
	var right_margin := MarginContainer.new()
	right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 24); right_margin.add_theme_constant_override("margin_top", 24)
	right_margin.add_theme_constant_override("margin_right", 24); right_margin.add_theme_constant_override("margin_bottom", 24)
	right_pane.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_margin.add_child(right_vbox)
	
	# Header & Telemetry Labels
	_title_label = Label.new()
	_title_label.text = tr("SHOWCASE_SELECT_MOB").to_upper() # Localized Instruction
	var dts := LabelSettings.new()
	dts.font_size = 20; dts.font_color = Color.WHITE; dts.outline_size = 4; dts.outline_color = Color.BLACK
	_title_label.label_settings = dts
	right_vbox.add_child(_title_label)
	
	_stats_label = Label.new()
	_stats_label.text = tr("SHOWCASE_INSPECT_DESC") # Localized Subtitle
	var sts := LabelSettings.new()
	sts.font_size = 11; sts.font_color = Color(0.65, 0.65, 0.7)
	_stats_label.label_settings = sts
	right_vbox.add_child(_stats_label)
	
	# 3D Viewport Container
	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	right_vbox.add_child(viewport_container)
	
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true # <--- CRITICAL: Air-gapped 3D world isolation!
	_viewport.msaa_3d = SubViewport.MSAA_4X
	_viewport.screen_space_aa = SubViewport.SCREEN_SPACE_AA_FXAA
	viewport_container.add_child(_viewport)
	
	_setup_3d_world_environment()
	
	# Interaction panel controls
	var controls_hbox := HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 14)
	right_vbox.add_child(controls_hbox)
	
	_rotate_btn = _create_tactile_button(Color(0.12, 0.55, 0.32, 0.8)) # Green Button
	_rotate_btn.text = tr("SHOWCASE_AUTO_ROTATE_ON").to_upper() # Localized Rotator Text
	_rotate_btn.pressed.connect(_on_rotate_toggled)
	controls_hbox.add_child(_rotate_btn)
	
	var back_btn := _create_tactile_button(Color(0.2, 0.2, 0.24, 1.0)) # Dark Grey Back
	back_btn.text = tr("SETTINGS_BACK").to_upper()
	back_btn.pressed.connect(func() -> void: closed.emit())
	controls_hbox.add_child(back_btn)


func _setup_3d_world_environment() -> void:
	# Add isolated camera
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.position = Vector3(0.0, 1.6, 4.0) 
	_camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_viewport.add_child(_camera)
	
	# ==========================================================================
	# HIGH-CONTRAST LABORATORY LIGHTING
	# ==========================================================================
	_spotlight = SpotLight3D.new()
	_spotlight.name = "ShowcaseSpotlight"
	_spotlight.light_color = Color(1.0, 0.95, 0.90) 
	_spotlight.light_energy = 3.5
	_spotlight.spot_range = 10.0
	_spotlight.spot_angle = 45.0
	_spotlight.position = Vector3(0.0, 3.5, 0.0) 
	_spotlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0) 
	_spotlight.shadow_enabled = true
	_viewport.add_child(_spotlight)
	
	# NEUTRAL STUDY LIGHTING OVERHAUL: Changed from neons (teal/magenta) to white
	_ambient_light_left = OmniLight3D.new()
	_ambient_light_left.name = "LeftRimTeal"
	_ambient_light_left.light_color = Color(0.9, 0.92, 0.95) 
	_ambient_light_left.light_energy = 1.6
	_ambient_light_left.omni_range = 8.0
	_ambient_light_left.position = Vector3(-2.2, 1.2, 1.5)
	_viewport.add_child(_ambient_light_left)
	
	_ambient_light_right = OmniLight3D.new()
	_ambient_light_right.name = "RightRimViolet"
	_ambient_light_right.light_color = Color(0.95, 0.92, 0.9) 
	_ambient_light_right.light_energy = 1.2
	_ambient_light_right.omni_range = 8.0
	_ambient_light_right.position = Vector3(2.2, 1.2, -1.5)
	_viewport.add_child(_ambient_light_right)
	
	# Add isolated world environment
	var env := WorldEnvironment.new()
	env.name = "ShowcaseEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.04, 0.04, 0.05) 
	_viewport.add_child(env)
	
	# ==========================================================================
	# COHESIVE VOXEL TREADMILL FLOOR
	# ==========================================================================
	_treadmill = MeshInstance3D.new()
	_treadmill.name = "TreadmillFloor"
	_treadmill.position = Vector3(0.0, -0.42, 0.0)
	
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(4.0, 4.0)
	_treadmill.mesh = plane_mesh
	
	_treadmill_mat = StandardMaterial3D.new()
	_treadmill_mat.albedo_color = Color(0.12, 0.12, 0.15)
	
	if ResourceLoader.exists("res://assets/textures/road.png"):
		_treadmill_mat.albedo_texture = load("res://assets/textures/road.png") as Texture2D
		_treadmill_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_treadmill_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
		
	_treadmill.material_override = _treadmill_mat
	_viewport.add_child(_treadmill)
	
	# Add rotating Pedestal Platform
	_pedestal = Node3D.new()
	_pedestal.name = "PedestalNode"
	_pedestal.position = Vector3(0.0, -0.4, 0.0) 
	_viewport.add_child(_pedestal)
	
	_build_directional_arrow()


func _build_directional_arrow() -> void:
	var arrow_root := Node3D.new()
	arrow_root.name = "DiagnosticArrow"
	arrow_root.position = Vector3(0, 0.01, 0)
	_pedestal.add_child(arrow_root)
	
	var arrow_mat := ORMMaterial3D.new()
	arrow_mat.albedo_color = Color(0.2, 0.95, 0.3)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(0.2, 0.95, 0.3)
	arrow_mat.emission_energy_multiplier = 2.0
	
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.08, 0.02, 1.0)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, 0, -0.5)
	shaft.material_override = arrow_mat
	arrow_root.add_child(shaft)
	
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(0.3, 0.3, 0.02)
	head.mesh = head_mesh
	head.rotation_degrees = Vector3(-90, 0, 0)
	head.position = Vector3(0, 0, -1.0)
	head.material_override = arrow_mat
	arrow_root.add_child(head)
	
	var label3d := Label3D.new()
	label3d.text = tr("SHOWCASE_FRONT") # Localized Indicator
	label3d.pixel_size = 0.006
	label3d.position = Vector3(0, 0.05, -1.35)
	label3d.rotation_degrees = Vector3(-90, 0, 0) 
	label3d.modulate = Color(0.2, 0.95, 0.3)
	label3d.outline_modulate = Color.BLACK
	arrow_root.add_child(label3d)


func _populate_asset_list() -> void:
	for section: String in ASSET_CATALOG.keys():
		var items: Array = ASSET_CATALOG[section] as Array
		
		# Setup section headers
		var section_lbl := Label.new()
		section_lbl.text = "— " + section
		var ls := LabelSettings.new()
		ls.font_size = 10; ls.font_color = Color(0.5, 0.5, 0.55)
		section_lbl.label_settings = ls
		_list_container.add_child(section_lbl)
		
		for item: Dictionary in items:
			var btn := Button.new()
			# Translate item names directly using tr() if applicable, removing tags if necessary
			btn.text = "  " + tr(item["name"]) 
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 36)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var sn := StyleBoxFlat.new()
			sn.bg_color = Color(0.12, 0.12, 0.15, 0.4)
			sn.set_corner_radius_all(6)
			sn.border_width_left = 3
			sn.border_color = Color(0.2, 0.55, 0.85, 0.5) if not item["is_prop"] else Color(1.0, 0.82, 0.2, 0.5)
			
			var sh := sn.duplicate() as StyleBoxFlat
			sh.bg_color = Color(0.18, 0.18, 0.22, 0.7)
			sh.border_color = Color(1.0, 0.85, 0.2, 0.9) 
			
			btn.add_theme_stylebox_override("normal", sn)
			btn.add_theme_stylebox_override("hover", sh)
			btn.add_theme_stylebox_override("pressed", sn)
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.add_theme_font_size_override("font_size", 12)
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
			
			btn.pressed.connect(func() -> void: _on_asset_selected(item["id"] as int, item["name"] as String, item["is_prop"] as bool))
			_list_container.add_child(btn)


func _load_initial_empty_state() -> void:
	_title_label.text = tr("SHOWCASE_SELECT_MOB").to_upper()
	_stats_label.text = tr("SHOWCASE_INSPECT_DESC")


func _on_asset_selected(asset_id: int, asset_name: String, is_prop: bool) -> void:
	_clear_active_mob()
	
	_selected_asset_id = asset_id
	_title_label.text = tr(asset_name).to_upper()
	
	if is_prop:
		_active_node = PropRegistry.create_prop(asset_id, Vector3.ZERO) as Node3D
	else:
		_active_node = MobRegistry.create_mob(asset_id, Vector3.ZERO) as Node3D
		
	if is_instance_valid(_active_node):
		_pedestal.add_child(_active_node)
		
		# ======================================================================
		# PURE STATIC FREEZE (CALIBRATED):
		# We strictly disable processing AFTER the node is added to the scene tree.
		# This bypasses Godot's automatic `_ready()` process restoration.
		# ======================================================================
		_active_node.set_physics_process(false)
		_active_node.set_process(false)
		
		# Freeze the nested NPCVisualComponent (stops bobbing and breathing sways)
		var visual_comp := _active_node.get_node_or_null("NPCVisualComponent")
		if is_instance_valid(visual_comp):
			visual_comp.set_process(false)
		
		# ======================================================================
		# DIAGNOSTIC PRESERVATION FIX: 
		# We do NOT queue_free() SpeechBubble or FloatingQuestArrow nodes anymore. 
		# This allows developers to verify their correct vertical alignments.
		# ======================================================================


func _clear_active_mob() -> void:
	if is_instance_valid(_active_node):
		_active_node.queue_free()
		_active_node = null


func _on_rotate_toggled() -> void:
	_is_rotating = not _is_rotating
	if _is_rotating:
		_rotate_btn.text = tr("SHOWCASE_AUTO_ROTATE_ON").to_upper()
		_rotate_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		_rotate_btn.text = tr("SHOWCASE_AUTO_ROTATE_OFF").to_upper()
		_rotate_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _process(delta: float) -> void:
	# Rotate Pedestal slowly so developer can inspect all angles
	if is_instance_valid(_pedestal):
		if _is_rotating:
			_pedestal.rotate_y(delta * 0.45)
		else:
			# Snap perfectly forward when paused for precise front-facing inspection
			_pedestal.rotation = Vector3.ZERO
		
	# ==========================================================================
	# HERMETIC ANCHOR: Clamps local coordinates to pedestal origin every frame!
	# Prevents ANY sinking, sliding, or drifting caused by lingering node velocities.
	# ==========================================================================
	if is_instance_valid(_active_node):
		_active_node.position = Vector3.ZERO


func _create_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _create_tactile_button(base_color: Color) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var shadow_color := base_color.darkened(0.4)
	
	var sn := StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4
	sn.border_color = shadow_color
	sn.content_margin_left = 16
	sn.content_margin_right = 16
	sn.content_margin_top = 10
	sn.content_margin_bottom = 10
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	
	var sp := StyleBoxFlat.new()
	sp.bg_color = shadow_color
	sp.set_corner_radius_all(8)
	sp.border_width_top = 4
	sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	btn.item_rect_changed.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
	)
	
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	return btn
