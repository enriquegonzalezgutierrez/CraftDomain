# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service orchestrating the Village Alert Alarm Network.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the registration,
#   deregistration, and proximity threat broadcasting of defenders.
# - Open-Closed Principle (OCP): Decoupled from concrete AI behaviors. Works on any 
#   defending node that exposes a combat target property.
# - Dependency Inversion Principle (DIP): Pure data-oriented RefCounted service,
#   completely decoupled from Godot's SceneTree or physics engines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/AlertNetworkService.gd
# ==============================================================================
class_name AlertNetworkService
extends RefCounted

# Static instance provider for global access (Service Locator Pattern)
static var instance: AlertNetworkService = null

# Active registered defenders (Guards and Golems) in the loaded chunks
var _defenders: Array[CharacterBody3D] = []

# Mutex to ensure thread-safe registrations during parallel chunk loads
var _lock: Mutex


func _init() -> void:
	_lock = Mutex.new()
	instance = self


## Registers an active defender node into the village protector pool on spawn
func register_defender(defender: CharacterBody3D) -> void:
	_lock.lock()
	if is_instance_valid(defender) and not _defenders.has(defender):
		_defenders.append(defender)
		print("[AlertNetwork] Registered village protector: ", defender.name)
	_lock.unlock()


## Unregisters a defender upon death or chunk unloads
func unregister_defender(defender: CharacterBody3D) -> void:
	_lock.lock()
	if _defenders.has(defender):
		_defenders.erase(defender)
		print("[AlertNetwork] Unregistered village protector: ", defender.name)
	_lock.unlock()


## Static Service Locator API: Broadcasts an active threat coordinate alarm.
## Searches for registered defenders within a 30m radius and dispatches them to assist.
static func broadcast_alarm(attacker: CharacterBody3D, victim_pos: Vector3) -> void:
	if is_instance_valid(instance):
		instance.broadcast_alarm_local(attacker, victim_pos)


## Coordinates local proximity sweeps, setting defender combat targets dynamically
func broadcast_alarm_local(attacker: CharacterBody3D, victim_pos: Vector3) -> void:
	if not is_instance_valid(attacker):
		return
		
	_lock.lock()
	# Max radius (meters squared) for defenders to hear the alarm thuds/screams
	var alert_radius_sq := 900.0 # 30 meters squared
	var dispatched_count := 0
	
	# FIX: Explicit static typing on loop defender iterator
	for defender: CharacterBody3D in _defenders:
		if is_instance_valid(defender):
			var dist_sq := defender.global_position.distance_squared_to(victim_pos)
			
			if dist_sq <= alert_radius_sq:
				# Verify if the defender is currently un-engaged or has an inactive target
				var current_target: CharacterBody3D = defender.get("_combat_target") as CharacterBody3D
				if not is_instance_valid(current_target) or current_target.get("domain_entity").is_dead:
					
					# DIP Compliance: Dynamically inject the attacking zombie as the combat target
					defender.set("_combat_target", attacker)
					dispatched_count += 1
					
	if dispatched_count > 0:
		print("[AlertNetwork] Threat detected at ", victim_pos, "! Dispatched ", dispatched_count, " defenders to intercept.")
	_lock.unlock()


## Cleans up the registries during world transitions or returns to main menu
func clear_network() -> void:
	_lock.lock()
	_defenders.clear()
	_lock.unlock()
