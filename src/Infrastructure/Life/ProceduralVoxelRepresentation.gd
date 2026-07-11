# ==============================================================================
# Project: CraftDomain
# Description: Concrete Procedural Voxel Visual Representation Strategy.
#              Sculpts and decorates traditional modular block-box characters.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates the high-level 
#   triggering of visual presentations and hand animations, offloading 3D mesh 
#   assemblies to dedicated builders.
# - Open-Closed Principle (OCP): EXTREME REFACTOR. Completely purged all 
#   hardcoded drawing methods (like `_build_villager_model`). It now queries 
#   the `VoxelModelRegistry` polymorphically to run the active strategy, 
#   closing this class permanently to modifications.
# - Dependency Inversion Principle (DIP): Independent of physical entities, 
#   binding blocks purely to injected SceneTree parents.
# ==============================================================================
class_name ProceduralVoxelRepresentation
extends IEntityVisualRepresentation

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


## Concrete Implementation: Queries the dynamic VoxelModelRegistry and executes the strategy
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
	
	# ==========================================================================
	# DELEGATED SCULPTING PIPELINE (SOLID OCP Compliance)
	# Query the VoxelModelRegistry dynamically to fetch the appropriate builder.
	# ==========================================================================
	var builder := VoxelModelRegistry.get_builder(int(role_type))
	if builder != null:
		builder.build_model(_visual_component, skin_color, shirt_color, hair_color, biome_id)
		
	# Bind handheld accessories joints securely
	if is_instance_valid(_visual_component.body_bob_node):
		_sword_joint = _visual_component.body_bob_node.get_node_or_null("IronSwordJoint") as Node3D
		_hoe_joint = _visual_component.body_bob_node.get_node_or_null("HarvestHoeJoint") as Node3D
		
		# Look for Headlamp beam if Miner
		var head_node := _visual_component.body_bob_node.get_node_or_null("HumanHead")
		if is_instance_valid(head_node):
			# Miners may contain an active SpotLight3D lamp inside their helmet
			var lamp := head_node.find_child("HeadlampBeam", true, false) as SpotLight3D
			if is_instance_valid(lamp):
				_headlamp_light = lamp


## Concrete Implementation: Visual bobs and sways are automatically managed by NPCVisualComponent
func animate_movement(_velocity_flat: Vector2, _is_on_floor: bool, _delta: float) -> void:
	pass


## Concrete Implementation: Triggers local weapon-swing Tweens
func trigger_attack_visuals() -> void:
	if role_type == RoleType.GUARD:
		_execute_voxel_sword_strike()
	elif role_type == RoleType.FARMER:
		_execute_voxel_hoe_strike()


func get_collision_box_size() -> Vector3:
	# Delegate size calculation polymorphically to the registered builder strategy
	var builder := VoxelModelRegistry.get_builder(int(role_type))
	if builder != null:
		return builder.get_collision_box_size()
	return Vector3(0.575, 1.5, 0.575) # Standard humanoid voxel height


func get_collision_box_position() -> Vector3:
	var builder := VoxelModelRegistry.get_builder(int(role_type))
	if builder != null:
		return builder.get_collision_box_position()
	return Vector3(0.0, 0.75, 0.0) # Centered at 0.75m


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
