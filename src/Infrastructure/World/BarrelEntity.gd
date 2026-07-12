# ==============================================================================
# Pathfile: res://src/Infrastructure/World/BarrelEntity.gd
# Description: Infrastructure Static Entity representing an interactive Breakable Barrel.
#              Manages collision setups, item looting, and destruction particles.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BarrelEntity
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/decorations/barrel.glb"


func _ready() -> void:
	name = "Prop_BARREL"
	
	# Locate and sanitize the static GLB model pre-instanced in the .tscn scene tree
	var model_node := get_node_or_null("Visuals/BodyBobJoint/barrel") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)


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
