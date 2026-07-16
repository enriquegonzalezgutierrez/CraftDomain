# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/SheepEntity.gd
# Description: Physical character controller for the Fluffy Sheep.
#              Manages high-frequency physics ticks, grass grazing animations, 
#              interactive shearing transactions, and unshaded wool particles.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual bobs, 
#   sound triggers, and particle emissions, delegating state decisions to SheepAIBehavior.
# - 120 FPS Guardrail: Computes procedural neck tilts and scale-shaving transitions
#   at 120Hz inside the physics thread to guarantee ultra-smooth movements.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SheepEntity
extends PassiveEntity


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 2)
	entity_habitat = 0 
	name = "Entity_SHEEP"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/sheep") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_SHEEP"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(5, 1) # Raw wool fibres (Leaves proxy)
	inv.add_item(16, 1) # Mutton meat


## Interactive Shearing: Allows players to shear the sheep for Blue Wool (ID 43)
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node) or domain_entity.is_dead:
		return
		
	var active_slot := player_node.get("active_slot_index") as int
	var inventory := player_node.get("inventory") as IInventory
	if not is_instance_valid(inventory):
		return
		
	# Verify if player holds a sharp tool: Wooden Sword (17) or Chrono-Scythe (85)
	var slot_data: Object = (inventory as InventoryComponent).get_slot_data(active_slot)
	var is_holding_shears := false
	if slot_data != null:
		var held_id: int = slot_data.get("item_id") as int
		is_holding_shears = (held_id == 17 or held_id == 85)
		
	var is_fluffy := get_meta(SheepAIBehavior.META_IS_FLUFFY) as bool if has_meta(SheepAIBehavior.META_IS_FLUFFY) else true
	
	if is_holding_shears and is_fluffy:
		_execute_shearing_transaction(player_node, inventory)
	else:
		# Standard passive bleat
		AudioService.play_sfx_static("sheep_baa", global_position)


func _execute_shearing_transaction(player_node: CharacterBody3D, inventory: IInventory) -> void:
	set_meta(SheepAIBehavior.META_IS_FLUFFY, false)
	
	# Give 1x Blue Wool (ID 43) to the player
	inventory.add_item(43, 1)
	
	AudioService.play_sfx_static("sheep_baa_shear", global_position)
	_spawn_wool_shear_particles()
	
	# Surprise jump reaction
	velocity.y = JUMP_VELOCITY * 0.72
	
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call(
			"show_quest_notification", 
			tr("NOTIFICATION_FOUND_PREFIX") + " 1x " + tr("BLOCK_BLUE_WOOL").to_upper(),
			tr("NOTIFICATION_CONSUME_FOOD_HEADER")
		)


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_grazing_animations(delta)
	_process_wool_scaling_interpolation(delta)


func _process_grazing_animations(delta: float) -> void:
	if not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var state := 0 # 0 = WANDERING, 1 = GRAZING
	if has_meta(SheepAIBehavior.META_STATE):
		state = get_meta(SheepAIBehavior.META_STATE) as int
		
	var body := visual_component.body_bob_node
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	
	if state == 1: # STATE_GRAZING
		# Tilt the neck down to munch the grass
		body.rotation.x = lerp_angle(body.rotation.x, deg_to_rad(20.0), delta * 6.0)
		body.rotation.y = sin(time_sec * 18.0) * 0.05
		
		# Spawn grass eating particles periodically
		if Engine.get_physics_frames() % 10 == 0:
			_spawn_grazing_grass_particles()
			AudioService.play_sfx_static("footstep_grass", global_position)
	else: # STATE_WANDERING
		body.rotation.x = lerp_angle(body.rotation.x, 0.0, delta * 5.0)
		body.rotation.y = lerp_angle(body.rotation.y, 0.0, delta * 5.0)


func _process_wool_scaling_interpolation(delta: float) -> void:
	if not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var is_fluffy := get_meta(SheepAIBehavior.META_IS_FLUFFY) as bool if has_meta(SheepAIBehavior.META_IS_FLUFFY) else true
	var body := visual_component.body_bob_node
	
	# Smoothly interpolate scale: Shaved/Sheared (small body) vs Fluffy (large fluffy cloud)
	var target_scale := Vector3.ONE if is_fluffy else Vector3(0.82, 0.88, 0.90)
	body.scale = body.scale.lerp(target_scale, delta * 4.5)


## Triggered by SheepAIBehavior upon completing a successful grass munch
func _play_grazing_joy_hop() -> void:
	velocity.y = JUMP_VELOCITY * 0.5
	AudioService.play_sfx_static("sheep_baa", global_position)


func _spawn_grazing_grass_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.3
	
	var mouth_offset := -global_transform.basis.z.normalized() * 0.4
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = Vector3.UP + mouth_offset * 0.5
	particles.spread = 30.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.78, 0.25) # Grass green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + mouth_offset + Vector3(0.0, 0.05, 0.0)
	particles.emitting = true


func _spawn_wool_shear_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 16
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.55
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.4
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.95, 0.9) # Wool white
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + Vector3(0.0, 0.4, 0.0)
	particles.emitting = true
