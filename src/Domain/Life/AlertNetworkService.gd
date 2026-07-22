# ==============================================================================
# Pathfile: res://src/Domain/Life/AlertNetworkService.gd
# Description: Pure Domain Service orchestrating the Village Alert Network.
#              Registers defenders and broadcasts threat alarms in spatial proximity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AlertNetworkService
extends RefCounted

static var instance: AlertNetworkService = null

const ALERT_RADIUS_SQ: float = 900.0 # 30 meters squared alarm distance

var _defenders: Array[Object] = []
var _lock: Mutex


func _init() -> void:
	_lock = Mutex.new()
	instance = self


## Registers an active defender object into the village protector pool on spawn.
func register_defender(defender: Object) -> void:
	_lock.lock()
	if is_instance_valid(defender) and not _defenders.has(defender):
		_defenders.append(defender)
		print("[AlertNetwork] Registered village protector: ", defender.get("name"))
	_lock.unlock()


## Unregisters a defender upon death or chunk unload.
func unregister_defender(defender: Object) -> void:
	_lock.lock()
	if _defenders.has(defender):
		_defenders.erase(defender)
		print("[AlertNetwork] Unregistered village protector: ", defender.get("name"))
	_lock.unlock()


## Static Service Locator API: Broadcasts an active threat coordinate alarm.
static func broadcast_alarm(attacker: Object, victim_pos: Vector3) -> void:
	if is_instance_valid(instance):
		instance.broadcast_alarm_local(attacker, victim_pos)


## Coordinates local proximity sweeps, setting defender combat targets dynamically.
func broadcast_alarm_local(attacker: Object, victim_pos: Vector3) -> void:
	if not is_instance_valid(attacker):
		return
		
	_lock.lock()
	var dispatched_count := _dispatch_defenders_to_threat(attacker, victim_pos)
	if dispatched_count > 0:
		print("[AlertNetwork] Threat detected at ", victim_pos, "! Dispatched ", dispatched_count, " defenders.")
	_lock.unlock()


func _dispatch_defenders_to_threat(attacker: Object, victim_pos: Vector3) -> int:
	var dispatched_count := 0
	for defender: Object in _defenders:
		if is_instance_valid(defender) and _evaluate_and_assign_defender(defender, attacker, victim_pos):
			dispatched_count += 1
	return dispatched_count


func _evaluate_and_assign_defender(defender: Object, attacker: Object, victim_pos: Vector3) -> bool:
	var def_pos: Vector3 = defender.get("global_position") as Vector3
	if def_pos.distance_squared_to(victim_pos) <= ALERT_RADIUS_SQ:
		var current_target: Object = defender.get("_combat_target") as Object
		var target_domain: Object = current_target.get("domain_entity") if is_instance_valid(current_target) else null
		var is_target_dead: bool = target_domain.get("is_dead") as bool if is_instance_valid(target_domain) else true
		
		if not is_instance_valid(current_target) or is_target_dead:
			defender.set("_combat_target", attacker)
			return true
	return false


## Cleans up defender registries during world transitions.
func clear_network() -> void:
	_lock.lock()
	_defenders.clear()
	_lock.unlock()
