# ==============================================================================
# Project: CraftDomain
# Description: Concrete Procedural Voxel Visual Representation Strategy.
#              Sculpts and decorates traditional modular block-box characters.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the programmatic 
#   voxel-box mesh assembly and accessory styling (pauldrons, crowns, turbans).
# - Open-Closed Principle (OCP): Consolidates all voxel building logic previously 
#   scattered across 6 different scripts into a single, cohesive strategy.
# - Dependency Inversion Principle (DIP): Independent of physical entities, 
#   binding blocks purely to injected SceneTree parents.
# WARNING RESOLUTION:
# - Cleared all unused private class variables, local variables, and prefixed 
#   unused signature parameters with an underscore to keep the Godot compiler silent.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/ProceduralVoxelRepresentation.gd
# ==============================================================================
class_name ProceduralVoxelRepresentation
extends IEntityVisualRepresentation

# Enums defining all supported voxel roles
enum RoleType {
	VILLAGER,
	MERCHANT,
	GUARD,
	FARMER,
	MINER,
	DRUID,
	GOLEM
}

@export var role_type: RoleType = RoleType.VILLAGER

# Handheld weapon/accessory references for voxel models
var _sword_joint: Node3D
var _hoe_joint: Node3D
var _headlamp_light: SpotLight3D

# Internal state tracking
var _host: CharacterBody3D
var _visual_component: NPCVisualComponent


## Concrete Implementation: Programmatically assembles the voxel box hierarchy
func build_representation(host: CharacterBody3D, _target_parent: Node3D) -> void:
	_host = host
	_visual_component = host.get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	if not is_instance_valid(_visual_component):
		push_error("[ProceduralVoxelRepresentation ERROR] NPCVisualComponent missing on host.")
		return
		
	var biome_id := _detect_current_biome()
	
	# Extract variety colors calculated deterministically on spawn
	var skin_color: Color = _visual_component.variant_skin_color
	var shirt_color: Color = _visual_component.variant_clothing_color
	var hair_color: Color = _visual_component.variant_hair_color
	
	# Fallback accessory colors
	var boots_color := Color(0.12, 0.12, 0.15)
	var pants_color := Color(0.18, 0.15, 0.12)
	var brow_brown := Color(0.18, 0.12, 0.08)
	var nose_brown := Color(0.55, 0.42, 0.32)
	
	# ==========================================================================
	# ROLE ASSEMBLY PIPELINE (SRP/OCP Compliant)
	# ==========================================================================
	match role_type:
		RoleType.GOLEM:
			_build_golem_model()
		RoleType.GUARD:
			_build_guard_model(skin_color, brow_brown, nose_brown)
		RoleType.MERCHANT:
			_build_merchant_model(biome_id, skin_color, shirt_color)
		RoleType.FARMER:
			_build_farmer_model(biome_id, skin_color, shirt_color)
		RoleType.MINER:
			_build_miner_model(skin_color, shirt_color)
		RoleType.DRUID:
			_build_druid_model(skin_color, hair_color, shirt_color)
		_:
			# Default: Standard Villager
			_build_villager_model(biome_id, skin_color, hair_color, shirt_color, pants_color, boots_color)


## Concrete Implementation: Procedural animations are handled by the NPCVisualComponent
func animate_movement(_velocity_flat: Vector2, _is_on_floor: bool, _delta: float) -> void:
	pass # Visual bobs and sways are automatically managed by NPCVisualComponent.gd


## Concrete Implementation: Triggers local weapon-swing Tweens
func trigger_attack_visuals() -> void:
	if role_type == RoleType.GUARD:
		_execute_voxel_sword_strike()
	elif role_type == RoleType.FARMER:
		_execute_voxel_hoe_strike()


func get_collision_box_size() -> Vector3:
	if role_type == RoleType.GOLEM:
		return Vector3(2.8, 3.5, 1.3)
	return Vector3(0.575, 1.5, 0.575) # Standard humanoid voxel height


func get_collision_box_position() -> Vector3:
	if role_type == RoleType.GOLEM:
		return Vector3(0.0, 1.75, 0.0)
	return Vector3(0.0, 0.75, 0.0) # Centered at 0.75m


# ==============================================================================
# PROSEDURAL ROLE MESH BUILDERS
# ==============================================================================

func _build_villager_model(biome_id: int, skin_color: Color, hair_color: Color, robe_color: Color, pants_color: Color, boots_color: Color) -> void:
	# 1. Base Legs
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(-0.1, 0.14, 0.0), pants_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.16, 0.28, 0.16), Vector3(0.1, 0.14, 0.0), pants_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.18, 0.08, 0.20), Vector3(-0.1, 0.04, -0.02), boots_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.18, 0.08, 0.20), Vector3(0.1, 0.04, -0.02), boots_color)
	
	# 2. Torso Robe
	_build_custom_torso_robe(biome_id, robe_color, pants_color)
	
	# 3. Head Joint (Elongated tall forehead)
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.52, 0.35), Vector3(0, 0.26, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.10, 0.26, 0.12), Vector3(0, 0.06, -0.22), Color(0.55, 0.42, 0.32)) # Nose
	
	# Blinking Eyes (Green emerald)
	_visual_component.left_eye = _visual_component.create_box(_visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(-0.09, 0.15, -0.18), Color.WHITE)
	_visual_component.create_box(_visual_component.left_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.0, 0.75, 0.35))
	_visual_component.right_eye = _visual_component.create_box(_visual_component.head_node, Vector3(0.08, 0.08, 0.02), Vector3(0.09, 0.15, -0.18), Color.WHITE)
	_visual_component.create_box(_visual_component.right_eye, Vector3(0.04, 0.04, 0.01), Vector3(0, 0, -0.01), Color(0.0, 0.75, 0.35))
	
	# 4. Arms Folded
	_visual_component.arms_node = Node3D.new()
	_visual_component.arms_node.name = "ArmsJoint"
	_visual_component.arms_node.position = Vector3(0, 0.65, -0.23)
	_visual_component.body_bob_node.add_child(_visual_component.arms_node)
	_visual_component.create_box(_visual_component.arms_node, Vector3(0.58, 0.18, 0.23), Vector3(0, 0, 0), robe_color * 0.8)
	
	# 5. Headwear
	_build_custom_headwear(biome_id, hair_color)


func _build_custom_torso_robe(biome_id: int, base_color: Color, accessory_color: Color) -> void:
	match biome_id:
		0: # Bay of Sails (Sailor Stripes)
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color.WHITE)
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.75, 0), Color(0.12, 0.45, 0.82))
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.12, 0.47), Vector3(0, 0.25, 0), Color(0.12, 0.45, 0.82))
		1: # Warp Plateau (Mario Plumber Dungarees)
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.85, 0.12, 0.12))
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), Color(0.15, 0.35, 0.72))
		4: # Frostbite Glaciers (Winter white coat)
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.82, 0.82, 0.85))
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.48, 0.10, 0.48), Vector3(0, 0.15, 0), Color(0.98, 0.98, 0.98))
		_:
			# Default Plains Tunic
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), base_color)
			_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.48, 0.08, 0.48), Vector3(0, 0.45, 0), accessory_color)


func _build_custom_headwear(biome_id: int, hair_color: Color) -> void:
	match biome_id:
		0: # Sailor Bandana
			_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.50, 0), Color(0.12, 0.45, 0.82))
		1: # Mario Plumber Cap
			_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.52, 0), Color(0.85, 0.12, 0.12))
			_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.04, 0.12), Vector3(0, 0.48, -0.22), Color(0.85, 0.12, 0.12))
		4: # Winter Fur-Hood
			_visual_component.create_box(_visual_component.head_node, Vector3(0.39, 0.48, 0.39), Vector3(0, 0.26, 0.02), Color(0.82, 0.82, 0.85))
			_visual_component.create_box(_visual_component.head_node, Vector3(0.42, 0.52, 0.10), Vector3(0, 0.26, -0.15), Color(0.98, 0.98, 0.98))
		_:
			# Default Hair
			_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.46, 0.03), hair_color)


func _build_merchant_model(biome_id: int, skin_color: Color, shirt_color: Color) -> void:
	var robe_color := Color(0.45, 0.15, 0.6)         # Royal violet
	var apron_color := Color(0.85, 0.6, 0.15)        # Gold apron
	var turban_color := Color(0.9, 0.82, 0.45)       # Soft gold
	
	if biome_id == 7: # Cyber Ruins (Black & Cyan)
		robe_color = Color(0.12, 0.12, 0.15)
		apron_color = Color(0.0, 0.95, 0.95)
		turban_color = Color(0.12, 0.12, 0.15)
		
	# Legs, Torso, Head
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.15, 0.1, 0.08)) # Boots
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.3, 0.5, 0.05), Vector3(0, 0.38, -0.23), apron_color) # Apron
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.34, 0.08, 0.48), Vector3(0, 0.45, 0), shirt_color) # Sash
	
	# Floating Zurrón (Leather pouch)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.12, 0.18, 0.12), Vector3(-0.24, 0.38, -0.15), Color(0.35, 0.22, 0.15))
	
	# Head
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9)
	
	# Turban & Jewel
	_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), turban_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.36, -0.20), Color(0.92, 0.12, 0.15)) # Ruby


func _build_guard_model(skin_color: Color, _brow_brown: Color, _nose_brown: Color) -> void:
	var steel_armor := Color(0.40, 0.40, 0.45)
	var iron_color := Color(0.55, 0.55, 0.60)
	
	# Legs, Torso, Pauldrons
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), steel_armor)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), steel_armor)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(-0.25, 0.75, 0), iron_color) # Pauldron L
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.14, 0.24, 0.38), Vector3(0.25, 0.75, 0), iron_color)  # Pauldron R
	
	# Head (Knight helmet)
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.22, 0.38), Vector3(0, 0.32, 0), steel_armor) # Helmet Dome
	_visual_component.create_box(_visual_component.head_node, Vector3(0.05, 0.18, 0.04), Vector3(0, 0.19, -0.20), iron_color)  # Visor
	_visual_component.create_box(_visual_component.head_node, Vector3(0.04, 0.28, 0.16), Vector3(0, 0.48, 0.05), Color(0.85, 0.12, 0.15)) # Plume
	
	# Voxel Weapons
	_sword_joint = Node3D.new()
	_sword_joint.name = "IronSwordJoint"
	_sword_joint.position = Vector3(-0.2, 0.5, 0.24)
	_sword_joint.rotation = Vector3(0, 0, deg_to_rad(-135))
	_visual_component.body_bob_node.add_child(_sword_joint)
	_visual_component.create_box(_sword_joint, Vector3(0.05, 0.45, 0.02), Vector3(0, 0.18, 0), iron_color) # Blade
	_visual_component.create_box(_sword_joint, Vector3(0.15, 0.04, 0.04), Vector3(0, -0.04, 0), Color(0.85, 0.6, 0.15)) # Guard


func _build_farmer_model(_biome_id: int, skin_color: Color, shirt_color: Color) -> void:
	var denim_color := Color(0.20, 0.35, 0.55)
	var hat_color := Color(0.88, 0.78, 0.42)
	
	# Legs, Torso, Hat
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.18, 0.14, 0.11))
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.42, 0.47), Vector3(0, 0.36, 0), denim_color) # Overalls
	
	# Head
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.65, 0.03, 0.65), Vector3(0, 0.36, 0), hat_color) # Straw hat brim
	
	# Handheld Hoe
	_hoe_joint = Node3D.new()
	_hoe_joint.name = "HarvestHoeJoint"
	_hoe_joint.position = Vector3(0.18, 0.52, 0.24)
	_hoe_joint.rotation = Vector3(0, 0, deg_to_rad(45))
	_visual_component.body_bob_node.add_child(_hoe_joint)
	_visual_component.create_box(_hoe_joint, Vector3(0.04, 0.52, 0.04), Vector3(0, 0, 0), Color(0.35, 0.22, 0.15)) # Handle shaft
	_visual_component.create_box(_hoe_joint, Vector3(0.10, 0.18, 0.04), Vector3(0, 0.21, -0.12), Color(0.5, 0.5, 0.52)) # Blade


func _build_miner_model(skin_color: Color, shirt_color: Color) -> void:
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.12, 0.1, 0.08)) # Boots
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), shirt_color)
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.47, 0.45, 0.47), Vector3(0, 0.35, 0), Color(0.38, 0.4, 0.42)) # Dungarees
	
	# Head
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), Color(0.95, 0.78, 0.12)) # Hard-hat
	
	# 3D Headlamp
	var lamp_casing := _visual_component.create_box(_visual_component.head_node, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.06, -0.22), Color(0.2, 0.2, 0.22))
	var lamp_lens := _visual_component.create_box(lamp_casing, Vector3(0.06, 0.06, 0.02), Vector3(0, 0, -0.035), Color(0.0, 0.95, 0.95))
	
	_headlamp_light = SpotLight3D.new()
	_headlamp_light.name = "HeadlampBeam"
	_headlamp_light.light_color = Color(0.92, 0.95, 1.0)
	_headlamp_light.light_energy = 2.4
	_headlamp_light.spot_range = 16.0
	_headlamp_light.shadow_enabled = true
	lamp_lens.add_child(_headlamp_light)


func _build_druid_model(skin_color: Color, hair_color: Color, _shirt_color: Color) -> void:
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.15, 0.1, 0.08)) # Boots
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), Color(0.18, 0.45, 0.15)) # Robe
	
	# Head
	_visual_component.head_node = Node3D.new()
	_visual_component.head_node.name = "HumanHead"
	_visual_component.head_node.position = Vector3(0, 1.05, 0)
	_visual_component.body_bob_node.add_child(_visual_component.head_node)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.35, 0.45, 0.35), Vector3(0, 0.225, 0), skin_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.18, 0.38), Vector3(0, 0.30, 0.03), hair_color)
	_visual_component.create_box(_visual_component.head_node, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.28, 0), Color(0.85, 0.6, 0.15)) # Crown


func _build_golem_model() -> void:
	var stone := Color(0.48, 0.48, 0.50)
	var moss := Color(0.25, 0.45, 0.18)
	
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(1.10, 1.45, 0.85), Vector3(0, 0.725, 0), stone) # Torso
	_visual_component.create_box(_visual_component.body_bob_node, Vector3(1.14, 0.32, 0.89), Vector3(0, 1.22, 0), moss)  # Mossy collar


# ==============================================================================
# FALLBACK ACTION TWEENS
# ==============================================================================

func _execute_voxel_sword_strike() -> void:
	if is_instance_valid(_sword_joint):
		var swing_tween := _host.create_tween()
		swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(-45), 0.08).set_trans(Tween.TRANS_SINE)
		swing_tween.tween_property(_sword_joint, "rotation:x", deg_to_rad(65), 0.12).set_trans(Tween.TRANS_SINE)


func _execute_voxel_hoe_strike() -> void:
	if is_instance_valid(_hoe_joint):
		var swing_tween := _host.create_tween()
		swing_tween.tween_property(_hoe_joint, "rotation:x", deg_to_rad(-45), 0.08).set_trans(Tween.TRANS_SINE)
		swing_tween.tween_property(_hoe_joint, "rotation:x", deg_to_rad(65), 0.12).set_trans(Tween.TRANS_SINE)


# ==============================================================================
# GEOGRAPHICAL DETECTORS
# ==============================================================================

func _detect_current_biome() -> int:
	if not is_instance_valid(_host):
		return 2
		
	var world_controller_ref := _host.get_parent()
	var default_biome_id := 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var generator: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if generator != null:
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(_host.global_position.x)), 
					int(round(_host.global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id
