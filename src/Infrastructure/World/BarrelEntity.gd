# ==============================================================================
# Pathfile: res://src/Infrastructure/World/BarrelEntity.gd
# Description: Infrastructure Static Entity representing an interactive Breakable Barrel.
#              Delegates model and material sanitization to GLBModelSanitizer (DRY).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BarrelEntity
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/decorations/barrel.glb"

var _model_node: Node3D


func _ready() -> void:
	name = "Prop_BARREL"
	_setup_model()
	_setup_collision()


func _setup_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene := load(MODEL_PATH) as PackedScene
		_model_node = model_scene.instantiate() as Node3D
		add_child(_model_node)
		
		# Telemetry-based alignment
		_model_node.scale = Vector3(1.0, 1.0, 1.0)
		_model_node.position = Vector3(0.0, 0.0, 0.0)
		_model_node.rotation_degrees = Vector3(0, 0, 0)
		
		# Centralized OCP/DRY Cleanup
		GLBModelSanitizer.sanitize_model(_model_node)
	else:
		push_error("[BarrelEntity] GLB model not found at path: " + MODEL_PATH)


func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "BarrelCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.72, 0.90, 0.72)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.45, 0.0) 
	add_child(col_shape)


func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node):
		return
		
	var inventory := player_node.get("inventory") as IInventory
	var hud := player_node.get("hud") as PlayerHUD
	
	if is_instance_valid(inventory):
		AudioService.play_sfx_static("footstep_wood", global_position)
		AudioService.play_sfx_static("loot_pickup")
		
		var rolled_item_id := 18 if randf() > 0.5 else 16
		inventory.add_item(rolled_item_id, 1)
		
		var reward_name := tr("BLOCK_CROP_SEED") if rolled_item_id == 18 else tr("ITEM_FRIED_CHICKEN")
		
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call(
				"show_quest_notification", 
				tr("NOTIFICATION_BARREL_SHATTERED_HEADER"), 
				tr("NOTIFICATION_FOUND_PREFIX") + " 1x " + reward_name.to_upper()
			)
			
		_spawn_wood_break_particles()
		
		var collider := get_node_or_null("BarrelCollider")
		if is_instance_valid(collider):
			collider.queue_free()
			
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)


func _spawn_wood_break_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.5
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.4, 0.3)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.15) 
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		parent_node.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 0.45, 0.0)
		particles.emitting = true
		get_tree().create_timer(0.7).timeout.connect(particles.queue_free)
