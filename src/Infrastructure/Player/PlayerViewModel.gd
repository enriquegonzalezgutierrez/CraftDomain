# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Presentation service that programmatically constructs
#              3D handheld tool models out of colored boxes.
#              UX IMPROVED: Added dynamic idle breathing and movement-based bobbing
#              to make the first-person perspective feel highly immersive and alive.
#              WARNING FIX:
#              - Added explicit static typing `PlayerController` to the `player` 
#                variable on line 52 to completely resolve the 
#                `UNTYPED_DECLARATION` compiler warning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Player/PlayerViewModel.gd
# ==============================================================================
class_name PlayerViewModel
extends Node3D

## Enumeration of supported handheld tools
enum ToolType {
	NONE,
	SCROLL,     # Shown when selecting blocks (blueprints)
	PICKAXE,    # Shown when selecting Stone, Dirt, or Grass (mining)
	SWORD       # Shown when selecting the Sword slot (combat)
}

var active_tool: ToolType = ToolType.NONE
var _is_swinging: bool = false

# Internal mesh container nodes
var _tool_root: Node3D

# Viewmodel animation and bobbing trackers
var _bob_time: float = 0.0
var _idle_time: float = 0.0

# Original baseline position offset relative to the Camera (Bottom-Right of screen)
const BASELINE_POSITION := Vector3(0.32, -0.38, -0.52)
const BASELINE_ROTATION := Vector3(deg_to_rad(10), deg_to_rad(20), deg_to_rad(-5))

func _ready() -> void:
	name = "PlayerViewModel"
	position = BASELINE_POSITION
	rotation = BASELINE_ROTATION
	
	_tool_root = Node3D.new()
	_tool_root.name = "ToolRoot"
	add_child(_tool_root)
	
	# Start with Scroll by default
	switch_to_tool(ToolType.SCROLL)

func _process(delta: float) -> void:
	if _is_swinging:
		return # Do not apply bobbing math while a swing animation tween is active
		
	# 1. Obtain the player controller dynamically (Camera3D -> CharacterBody3D)
	# FIX: Added explicit static typing `PlayerController` to prevent variant warning
	var player: PlayerController = get_parent().get_parent() as PlayerController
	
	if is_instance_valid(player):
		# Calculate lateral movement speed (ignore vertical falling/jumping velocity)
		var flat_velocity := Vector2(player.velocity.x, player.velocity.z)
		var speed: float = flat_velocity.length()
		var is_moving: bool = speed > 0.5 and player.is_on_floor()
		
		# 2. Dynamic Bobbing Math
		var target_pos := BASELINE_POSITION
		
		if is_moving:
			# Fast, rhythmic bouncing tied to movement speed
			_bob_time += delta * speed * 1.8
			
			# Explicitly type variables as floats to satisfy Godot's static analyzer
			var bob_offset_x: float = cos(_bob_time) * 0.015
			var bob_offset_y: float = abs(sin(_bob_time)) * 0.02 - 0.01
			
			target_pos += Vector3(bob_offset_x, bob_offset_y, 0.0)
		else:
			# Subtle, slow breathing floating effect when standing still
			_idle_time += delta * 1.5
			
			var idle_offset_y: float = sin(_idle_time) * 0.008
			var idle_offset_x: float = cos(_idle_time * 0.5) * 0.004
			
			target_pos += Vector3(idle_offset_x, idle_offset_y, 0.0)
			
			# Gradually reset the walking bob phase to prevent snapping
			_bob_time = lerp(_bob_time, 0.0, delta * 5.0)

		# 3. Smoothly interpolate position for buttery smooth rendering
		position = position.lerp(target_pos, delta * 12.0)

## Programmatically swaps active handheld visual meshes instantly.
func switch_to_tool(new_tool: ToolType) -> void:
	if active_tool == new_tool and _tool_root.get_child_count() > 0:
		return # Already active
		
	active_tool = new_tool
	_clear_tool_mesh()
	
	match active_tool:
		ToolType.SCROLL:
			_build_scroll()
		ToolType.PICKAXE:
			_build_pickaxe()
		ToolType.SWORD:
			_build_sword()

## Executes a highly satisfying 3D swinging animation (0.15s) using Godot's Tween engine.
func play_swing_animation() -> void:
	if _is_swinging:
		return
		
	_is_swinging = true
	
	# Create a dual-step rotating swing animation
	var swing_tween := create_tween()
	
	# Step 1: Rapid downward strike rotation (0.06 seconds)
	var strike_rotation := BASELINE_ROTATION + Vector3(deg_to_rad(-45), deg_to_rad(-25), deg_to_rad(-10))
	var strike_position := BASELINE_POSITION + Vector3(-0.08, -0.05, -0.05)
	swing_tween.set_parallel(true)
	swing_tween.tween_property(self, "rotation", strike_rotation, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "position", strike_position, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Step 2: Smooth return recovery to baseline (0.09 seconds)
	swing_tween.chain().set_parallel(true)
	swing_tween.tween_property(self, "rotation", BASELINE_ROTATION, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing_tween.tween_property(self, "position", BASELINE_POSITION, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Reset state allowing the _process bobbing to take over again
	swing_tween.chain().tween_callback(func() -> void:
		_is_swinging = false
	)

func _clear_tool_mesh() -> void:
	for child in _tool_root.get_children():
		child.queue_free()

func _build_scroll() -> void:
	# Represent a rolled blueprint scroll (White paper core with oak handles)
	var paper_color := Color(0.95, 0.95, 0.88)
	var wood_color := Color(0.45, 0.3, 0.15)
	
	_create_box_mesh(_tool_root, Vector3(0.08, 0.32, 0.08), Vector3(0, 0, 0), paper_color) # Scroll tube
	_create_box_mesh(_tool_root, Vector3(0.02, 0.38, 0.02), Vector3(0, 0, 0), wood_color)  # Handle rod

func _build_pickaxe() -> void:
	# Represent a rugged Stone Pickaxe (Oak shaft with horizontal stone crosspiece)
	var handle_color := Color(0.45, 0.3, 0.15)
	var stone_color := Color(0.48, 0.48, 0.48)
	
	_create_box_mesh(_tool_root, Vector3(0.04, 0.45, 0.04), Vector3(0, 0, 0), handle_color) # Wooden Shaft
	_create_box_mesh(_tool_root, Vector3(0.32, 0.06, 0.06), Vector3(0, 0.18, 0.01), stone_color) # Stone Pick-Head
	_create_box_mesh(_tool_root, Vector3(0.06, 0.08, 0.08), Vector3(0, 0.18, 0), Color(0.3, 0.3, 0.3)) # Dark central binding bind

func _build_sword() -> void:
	# Represent a classic Wooden Sword (Oak grip, gold crossguard, steel-like blade)
	var blade_color := Color(0.85, 0.85, 0.85)
	var guard_color := Color(0.85, 0.6, 0.15)
	var hilt_color := Color(0.45, 0.3, 0.15)
	
	_create_box_mesh(_tool_root, Vector3(0.06, 0.52, 0.02), Vector3(0, 0.18, 0), blade_color) # Sword Blade
	_create_box_mesh(_tool_root, Vector3(0.18, 0.04, 0.05), Vector3(0, -0.08, 0), guard_color) # Crossguard
	_create_box_mesh(_tool_root, Vector3(0.04, 0.14, 0.04), Vector3(0, -0.16, 0), hilt_color)  # Grip Handle

func _create_box_mesh(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat: ORMMaterial3D = ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)
