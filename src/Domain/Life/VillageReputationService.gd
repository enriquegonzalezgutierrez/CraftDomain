# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service managing the player's village reputation and economic multipliers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively player reputation scores,
#   hostility checks, and barter discount multipliers.
# - Open-Closed Principle (OCP): Easily extendable with new rep thresholds (e.g. unlocking 
#   special titles, items, or elite quests).
# - Dependency Inversion Principle (DIP): Pure data-oriented RefCounted service,
#   completely decoupled from Godot's SceneTree or physics engines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/VillageReputationService.gd
# ==============================================================================
class_name VillageReputationService
extends RefCounted

# Static instance provider for global access (Service Locator Pattern)
static var instance: VillageReputationService = null

# Reputation ranges: -100 (WANTED outlaw) to +100 (HERO of the plains)
var _reputation_score: int = 0

# Threshold constants
const HOSTILE_THRESHOLD: int = -50
const HERO_THRESHOLD: int = 75

# Mutex to ensure thread-safe score modifications
var _lock: Mutex


func _init() -> void:
	_lock = Mutex.new()
	instance = self


## Modifies the player's reputation score, clamping it strictly within the -100..100 boundary.
func modify_reputation(amount: int) -> void:
	_lock.lock()
	var old_score := _reputation_score
	_reputation_score = clampi(_reputation_score + amount, -100, 100)
	
	if _reputation_score != old_score:
		print("[Reputation] Player karma shifted by ", amount, ". Current Score: ", _reputation_score, " (State: ", get_reputation_standing_name(), ")")
	_lock.unlock()


## Returns the player's current absolute reputation score
func get_reputation_score() -> int:
	_lock.lock()
	var score := _reputation_score
	_lock.unlock()
	return score


## Returns true if the player's reputation has fallen below the outlaw threshold,
## causing village defenders (Guards and Golems) to become hostile to the player.
func is_player_wanted() -> bool:
	_lock.lock()
	var wanted := _reputation_score <= HOSTILE_THRESHOLD
	_lock.unlock()
	return wanted


## Computes the barter trade price multiplier based on the player's reputation.
## - Hero (+100): Grants a 30% discount (multiplier 0.70)
## - Outlaw (-100): Increases prices by 30% (multiplier 1.30)
func get_barter_price_multiplier() -> float:
	_lock.lock()
	# Map reputation range [-100..100] linearly to a price offset [-0.30..0.30]
	var percent_offset: float = -float(_reputation_score) / 100.0 * 0.30
	var multiplier := clampf(1.0 + percent_offset, 0.70, 1.30)
	_lock.unlock()
	return multiplier


## Returns a descriptive string representing the player's active standing tier
func get_reputation_standing_name() -> String:
	_lock.lock()
	var score := _reputation_score
	_lock.unlock()
	
	if score <= -75:
		return "WANTED OUTLAW"
	elif score <= HOSTILE_THRESHOLD:
		return "SHUNNED INTRUDER"
	elif score < 25:
		return "NEUTRAL STRANGER"
	elif score < HERO_THRESHOLD:
		return "RESPECTED ALLY"
	else:
		return "HERO OF THE PLAINS"


## Cleans up the service state during world transitions or returns to main menu
func reset() -> void:
	_lock.lock()
	_reputation_score = 0
	_lock.unlock()
