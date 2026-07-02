# ==============================================================================
# Project: CraftDomain
# Description: Abstract base class representing a physics-bound passive entity (NPC/Fauna).
#              Schedules procedural walk cycles, spatial state-machines, and variety.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Serves as a robust base 
#                contract with safe default virtual values for subclasses.
#              - Single Responsibility Principle (SRP): Decoupled into specialized 
#                components, leaving this class strictly in charge of sliding physics.
#              WARNING FIX:
#              - Added explicit static typing `Node` to intermediate parents 
#                on lines 188 and 205 to completely resolve `UNTYPED_DECLARATION` 
#                compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/PassiveEntity.gd
# ==============================================================================
class_name PassiveEntity
extends CharacterBody3D

# Base physics movement constants
const BASE_SPEED: float = 1.3
const JUMP_VELOCITY: float = 5.0

# Sibling Component references (Composite Pattern)
var ai_component: NPCAIComponent
var visual_component: NPCVisualComponent

# Domain Model Composition (DDD)
var domain_entity: VoxelEntity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# original Spawn Point used to anchor human NPCs so they never get lost (Tethering)
var _spawn_point: Vector3

# Dynamic floating Speech Bubble reference
var _bubble: Node3D
var _quest_check_timer: float = 0.5

# Deterministic unique Seed computed on coordinate hashes
var npc_seed: int = 0

# ==============================================================================
# CONVERSATION STATE MACHINE: Dynamic player gaze-lock variables
# ==============================================================================
var is_talking: bool = false
var _talking_partner: CharacterBody3D = null


func _init(spawn_pos: Vector3, initial_health: int = 1) -> void:
	position = spawn_pos
	_spawn_point = spawn_pos
	
	# Compute a deterministic seed based on coordinate hashes (stable on reloading)
	npc_seed = abs(int(spawn_pos.x * 73856093) ^ int(spawn_pos.z * 19349663))
	
	# Pure Domain Model initialization and signals binding
	domain_entity = VoxelEntity.new(initial_health)
	domain_entity.took_damage.connect(_on_domain_entity_took_damage)
	domain_entity.died.connect(_on_domain_entity_died)


func _ready() -> void:
	# Programmatic component compositions (Decoupling God files)
	ai_component = NPCAIComponent.new()
	add_child(ai_component)
	
	visual_component = NPCVisualComponent.new()
	add_child(visual_component)
	
	_build_visual_representation()
	_setup_floating_bubble()
	
	# Setup physics collision shape (Reads height scaling from visual component)
	var col := CollisionShape3D.new()
	col.name = "EntityCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = _get_collision_box_size() * Vector3(1.0, visual_component.variant_height_scale, 1.0)
	col.shape = box_shape
	col.position = _get_collision_box_position() * visual_component.variant_height_scale
	add_child(col)


func _build_visual_representation() -> void:
	assert(false, "[PassiveEntity] _build_visual_representation() must be implemented by concrete subclass.")


func _get_collision_box_size() -> Vector3:
	return Vector3(0.6, 0.8, 0.6)


func _get_collision_box_position() -> Vector3:
	return Vector3(0.0, 0.4, 0.0)


func _setup_floating_bubble() -> void:
	pass


func interact(_player: CharacterBody3D) -> void:
	pass


func start_talking(partner: CharacterBody3D) -> void:
	is_talking = true
	_talking_partner = partner
	velocity = Vector3.ZERO


func stop_talking() -> void:
	is_talking = false
	_talking_partner = null
	if is_instance_valid(ai_component):
		ai_component.task_timer = 1.0


func take_damage(amount: int, knockback_force: Vector3) -> void:
	if domain_entity.is_dead: 
		return
	if is_talking:
		stop_talking()
		
	velocity += knockback_force
	domain_entity.take_damage(amount)


func _on_domain_entity_took_damage(_amount: int) -> void:
	velocity.y = JUMP_VELOCITY
	
	# Force Panic state override on taking damage
	if is_instance_valid(ai_component):
		ai_component.current_task = NPCAIComponent.TaskState.PANIC
		ai_component.task_timer = randf_range(3.0, 5.0)
		var angle := randf() * TAU
		ai_component.wander_direction = Vector3(cos(angle), 0, sin(angle))


# ==============================================================================
# DEATH SEQUENCE & LOOT ORCHESTRATION
# ==============================================================================
func _on_domain_entity_died() -> void:
	_try_drop_player_loot()
	
	# 1. Disable physics and interactions instantly
	set_physics_process(false)
	var col := get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col):
		col.queue_free()
	if is_instance_valid(_bubble):
		_bubble.queue_free()
		
	# 2. Spawn death particles (Smoke puff)
	_spawn_death_particles()
	
	# 3. Animate visual components shrinking and spinning into oblivion
	var death_tween := create_tween().set_parallel(true)
	if is_instance_valid(visual_component) and is_instance_valid(visual_component.visual_root):
		death_tween.tween_property(visual_component.visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_component.visual_root, "rotation:y", deg_to_rad(180), 0.25).set_trans(Tween.TRANS_SINE)
		
	# 4. Erase entity safely from memory
	death_tween.chain().tween_callback(queue_free)


func _spawn_death_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.6
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, 2.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	particles.process_material = pm
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var mat := ORMMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8) # Smoke grey
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	
	# FIX: Explicit static typing on world parent reference
	var world_node: Node = get_parent() as Node
	if is_instance_valid(world_node):
		world_node.add_child(particles)
		particles.global_position = global_position + Vector3(0, 0.5, 0)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _try_drop_player_loot() -> void:
	# FIX: Explicit static typing on parent reference
	var parent: Node = get_parent() as Node
	if is_instance_valid(parent):
		var player_node := parent.get_node_or_null("Player") as CharacterBody3D
		if is_instance_valid(player_node):
			var inv: IInventory = player_node.get("inventory") as IInventory
			if is_instance_valid(inv):
				_drop_loot(inv)


## Virtual Method (LSP): Subclasses override this to implement concrete drops.
func _drop_loot(_inv: IInventory) -> void:
	pass


# ==============================================================================
# MAIN PHYSICS CALCULATIONS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if domain_entity.is_dead: 
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Process AI component decision tree calculations
	if is_instance_valid(ai_component):
		ai_component.process_ai(delta)
	
	_quest_check_timer -= delta
	if _quest_check_timer <= 0.0:
		_quest_check_timer = 0.5
		_update_quest_bubble_state()

	move_and_slide()


func _update_quest_bubble_state() -> void:
	if not is_instance_valid(_bubble):
		return
		
	var active_q := QuestService.get_active_quest()
	if active_q != null:
		var is_target := false
		if active_q.quest_id == "lost_bazaar" and name.contains("VILLAGER"):
			is_target = true
		elif active_q.quest_id == "fuel_fryer" and name.contains("MERCHANT"):
			is_target = true
		elif active_q.quest_id == "plains_defender" and name.contains("GUARD"):
			is_target = true
			
		if is_target:
			_bubble.call("set_text", "⭐ [ " + tr("BUBBLE_ACTIVE_MISSION").to_upper() + ": " + tr(active_q.title).to_upper() + " ] ⭐")
			return
			
	if name.contains("VILLAGER"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("MERCHANT"):
		_bubble.call("set_text", tr("BUBBLE_TRADE"))
	elif name.contains("GUARD"):
		_bubble.call("set_text", tr("BUBBLE_TALK"))
	elif name.contains("FARMER"):
		_bubble.call("set_text", tr("BUBBLE_FARMER"))


func _can_socialize() -> bool:
	return false


func _is_avian() -> bool:
	return false
