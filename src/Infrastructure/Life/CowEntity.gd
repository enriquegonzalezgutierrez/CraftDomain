# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/CowEntity.gd
# Description: Physical character controller for the passive Clay Cow.
#              Manages high-frequency physics ticks, soil grazing animations, 
#              interactive milking transactions, and ponderous ground-shake steps.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively visual sways, 
#   sound triggers, and particle emissions, delegating state decisions to CowAIBehavior.
# - 120 FPS Guardrail: Computes procedural neck tilts, step shakes, and milking splashes
#   at 120Hz inside the physics thread to guarantee ultra-smooth movements.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CowEntity
extends PassiveEntity

const COOLDOWN_MOO_MIN_SEC: float = 20.0
const COOLDOWN_MOO_MAX_SEC: float = 35.0
const STRIDE_INTERVAL_SEC: float = 1.4

var _moo_timer: float = randf_range(5.0, 20.0)
var _stride_accumulator: float = 0.0


func _init(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	super(spawn_pos, 6)
	entity_habitat = 0 
	name = "Entity_COW"


func _ready() -> void:
	add_to_group("passives")
	
	ai_component = get_node_or_null("NPCAIComponent") as NPCAIComponent
	visual_component = get_node_or_null("NPCVisualComponent") as NPCVisualComponent
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/cow") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
	
	_setup_nameplate_height()


func _get_entity_name_key() -> String:
	return "NPC_NAME_COW"


func _get_nameplate_color() -> Color:
	return Color(0.2, 0.85, 0.2)


func _drop_loot(inv: IInventory) -> void:
	inv.add_item(2, 1) # Dirt
	inv.add_item(16, 1) # Beef meat


## Interactive Milking: Allows players to milk the cow for high-nutrient rations
func interact(player_node: CharacterBody3D) -> void:
	if not is_instance_valid(player_node) or domain_entity.is_dead:
		return
		
	var inventory := player_node.get("inventory") as IInventory
	if not is_instance_valid(inventory):
		return
		
	var has_milk := get_meta(CowAIBehavior.META_HAS_MILK) as bool if has_meta(CowAIBehavior.META_HAS_MILK) else true
	
	if has_milk:
		_execute_milking_transaction(player_node, inventory)
	else:
		# Standard passive head shake moo
		AudioService.play_sfx_static("cow_moo", global_position)


func _execute_milking_transaction(player_node: CharacterBody3D, inventory: IInventory) -> void:
	set_meta(CowAIBehavior.META_HAS_MILK, false)
	
	# Give 1x Dairy Rations (Fried Chicken proxy ID 16)
	inventory.add_item(16, 1)
	
	AudioService.play_sfx_static("cow_moo", global_position)
	_spawn_milk_splash_particles()
	
	var hud := player_node.get("hud") as PlayerHUD
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call(
			"show_quest_notification", 
			tr("NOTIFICATION_FOUND_PREFIX") + " 1x " + tr("ITEM_FRIED_CHICKEN").to_upper(),
			tr("NOTIFICATION_CONSUME_FOOD_HEADER")
		)


## High-Frequency Physics Loop (Runs at 120Hz on the physics thread)
func _physics_tick(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	_process_grazing_animations(delta)
	_process_ponderous_step_shakes(delta)


func _process_grazing_animations(delta: float) -> void:
	if not is_instance_valid(visual_component) or not is_instance_valid(visual_component.body_bob_node):
		return
		
	var state := 0 # 0 = WANDERING, 1 = GRAZING
	if has_meta(CowAIBehavior.META_STATE):
		state = get_meta(CowAIBehavior.META_STATE) as int
		
	var body := visual_component.body_bob_node
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	
	if state == 1: # STATE_GRAZING
		# Tilt the neck down to munch the grass
		body.rotation.x = lerp_angle(body.rotation.x, deg_to_rad(20.0), delta * 6.0)
		body.rotation.y = sin(time_sec * 15.0) * 0.04
		
		# Spawn grass eating particles periodically
		if Engine.get_physics_frames() % 10 == 0:
			_spawn_grazing_grass_particles()
			AudioService.play_sfx_static("footstep_grass", global_position)
	else: # STATE_WANDERING
		body.rotation.x = lerp_angle(body.rotation.x, 0.0, delta * 5.0)
		body.rotation.y = lerp_angle(body.rotation.y, 0.0, delta * 5.0)


func _process_ponderous_step_shakes(delta: float) -> void:
	var flat_velocity := Vector2(velocity.x, velocity.z)
	if flat_velocity.length_squared() > 0.1 and is_on_floor():
		_stride_accumulator += delta
		if _stride_accumulator >= STRIDE_INTERVAL_SEC:
			_stride_accumulator = 0.0
			_play_ponderous_step_impact()
	else:
		_stride_accumulator = lerp(_stride_accumulator, 0.0, delta * 4.0)


func _play_ponderous_step_impact() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var dist := global_position.distance_to(player_node.global_position)
			if dist < 8.0:
				# Triggers a subtle camera shake for nearby players to convey the Clay Cow's mass
				var intensity := remap(dist, 0.0, 8.0, 0.05, 0.0)
				player_node.set("_shake_intensity", intensity)
				
	AudioService.play_sfx_static("footstep_stone", global_position)


## Triggered by CowAIBehavior upon completing a successful grass munch
func _play_grazing_joy_hop() -> void:
	velocity.y = JUMP_VELOCITY * 0.4
	AudioService.play_sfx_static("cow_moo", global_position)


func _spawn_grazing_grass_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 3
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.3
	
	var mouth_offset := -global_transform.basis.z.normalized() * 0.5
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.direction = Vector3.UP + mouth_offset * 0.5
	particles.spread = 30.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.78, 0.25) # Grass green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	particles.global_position = global_position + mouth_offset + Vector3(0.0, 0.05, 0.0)
	particles.emitting = true


func _spawn_milk_splash_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.45
	
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 2.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.98, 1.0, 0.9) # Milk white
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	
	# Spawn under the belly
	particles.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	particles.emitting = true


func _process(delta: float) -> void:
	if domain_entity.is_dead:
		return
		
	var is_panicking := false
	if is_instance_valid(ai_component) and ai_component.get("current_task") as int == 5:
		is_panicking = true
		
	if not is_panicking:
		_moo_timer -= delta
		if _moo_timer <= 0.0:
			_moo_timer = randf_range(COOLDOWN_MOO_MIN_SEC, COOLDOWN_MOO_MAX_SEC)
			AudioService.play_sfx_static("cow_moo", global_position, 50.0)
