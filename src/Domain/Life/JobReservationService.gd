# ==============================================================================
# Pathfile: res://src/Domain/Life/JobReservationService.gd
# Description: Pure Domain Service managing spatial job reservations to prevent
#              multiple NPCs from targeting the same voxel coordinate simultaneously.
#              (e.g., Two farmers trying to harvest the exact same wheat block).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively handles the thread-safe 
#   registration and validation of claimed world coordinates.
# - Dependency Inversion Principle (DIP): A pure data-oriented RefCounted service,
#   completely decoupled from Godot's SceneTree or physics engines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name JobReservationService
extends RefCounted

## Static instance provider for global access across the Domain (Service Locator Pattern)
static var instance: JobReservationService = null

## Thread-safe dictionary mapping targeted global coordinates to worker IDs
## Dictionary format: Vector3i (Job Coordinate) -> int (Worker Instance ID)
var _claimed_jobs: Dictionary = {}

## Mutex lock protecting concurrent reads/writes during background GOAP planning
var _lock: Mutex


func _init() -> void:
	_lock = Mutex.new()
	instance = self


## Attempts to reserve a specific global coordinate for a worker.
## Returns true if the coordinate was successfully claimed or already owned by this worker.
func claim_job(coord: Vector3i, worker_id: int) -> bool:
	_lock.lock()
	
	var is_available: bool = not _claimed_jobs.has(coord)
	var is_already_owned: bool = false
	
	if not is_available:
		var current_owner: int = _claimed_jobs[coord] as int
		is_already_owned = (current_owner == worker_id)
		
	if is_available or is_already_owned:
		_claimed_jobs[coord] = worker_id
		_lock.unlock()
		return true
		
	_lock.unlock()
	return false


## Releases a previously claimed job coordinate, making it available for other NPCs.
func release_job(coord: Vector3i, worker_id: int) -> void:
	_lock.lock()
	
	if _claimed_jobs.has(coord):
		var current_owner: int = _claimed_jobs[coord] as int
		if current_owner == worker_id:
			_claimed_jobs.erase(coord)
			
	_lock.unlock()


## Safely queries if a specific coordinate is currently claimed by any worker.
func is_job_claimed(coord: Vector3i) -> bool:
	_lock.lock()
	var claimed: bool = _claimed_jobs.has(coord)
	_lock.unlock()
	
	return claimed


## Returns the ID of the worker owning the job, or -1 if the job is available.
func get_job_owner(coord: Vector3i) -> int:
	_lock.lock()
	var owner_id: int = -1
	
	if _claimed_jobs.has(coord):
		owner_id = _claimed_jobs[coord] as int
		
	_lock.unlock()
	return owner_id


## Sweeps the registry and removes all active claims belonging to a specific worker.
## Called when an NPC dies, is unloaded, or abruptly changes their primary GOAP Goal.
func release_all_jobs_for_worker(worker_id: int) -> void:
	_lock.lock()
	var keys_to_remove: Array[Vector3i] = []
	
	for coord: Vector3i in _claimed_jobs.keys():
		var owner: int = _claimed_jobs[coord] as int
		if owner == worker_id:
			keys_to_remove.append(coord)
			
	for coord: Vector3i in keys_to_remove:
		_claimed_jobs.erase(coord)
		
	_lock.unlock()


## Fully clears the jobs registry (Called during world unloads or fast travel).
func clear_registry() -> void:
	_lock.lock()
	_claimed_jobs.clear()
	_lock.unlock()
