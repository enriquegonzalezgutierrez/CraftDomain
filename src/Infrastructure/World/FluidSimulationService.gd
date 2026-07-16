# ==============================================================================
# Pathfile: res://src/Infrastructure/World/FluidSimulationService.gd
# Description: Infrastructure Service responsible for simulating high-performance
#              cellular automata fluid dynamics (Water & Lava flow/fusion rules).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively fluid update loops,
#   flow mathematics, and stone fusion rules.
# - Open-Closed Principle (OCP): Works dynamically. Listens to block changes via 
#   the Observer Pattern, keeping the world controller closed to modifications.
# - Dependency Inversion Principle (DIP): Modifies blocks globally through the 
#   abstract WorldController/WorldState networks.
# - Proactive Adjacency Wakeup: Re-registers neighboring stable fluids into the
#   simulation queue when solid blocks are mined, preventing underwater air pockets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FluidSimulationService
extends RefCounted

# Climatological tick timer parameters (Ticking every 0.25 seconds)
const UPDATE_INTERVAL: float = 0.25
var _tick_timer: float = UPDATE_INTERVAL

# Simulation limits to prevent infinite world flooding
const MAX_WATER_SPREAD: int = 4
const MAX_LAVA_SPREAD: int = 2
const MAX_UPDATES_PER_TICK: int = 64

# Dependencies injected on startup
var world_controller: Node3D
var world_state: WorldState

# Unstable coordinate queue: Vector3i (global_pos) -> FluidState (metadata)
var _active_fluids: Dictionary = {}

## Small helper struct to track fluid source origin and remaining flow energy.
class FluidState:
	var type: BlockType.Type
	var remaining_spread: int
	
	func _init(p_type: BlockType.Type, p_spread: int) -> void:
		type = p_type
		remaining_spread = p_spread


func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state


## Public Registration API: Call this when a fluid is placed or generated 
## to register it as an active, unstable fluid block.
func register_fluid_block(global_pos: Vector3i, type: BlockType.Type, max_spread: int = -1) -> void:
	if type != BlockType.Type.WATER and type != BlockType.Type.LAVA:
		return
		
	var default_spread := MAX_WATER_SPREAD if type == BlockType.Type.WATER else MAX_LAVA_SPREAD
	var spread := default_spread if max_spread == -1 else max_spread
	
	_active_fluids[global_pos] = FluidState.new(type, spread)


## Unregisters a block if it gets mined or overwritten by another solid block.
func unregister_fluid_block(global_pos: Vector3i) -> void:
	if _active_fluids.has(global_pos):
		_active_fluids.erase(global_pos)


# ==============================================================================
# OBSERVATION INJECTION RECEPTORS (DIP / OCP Compliance)
# ==============================================================================

## Symmetrical Observer Callback: Automatically registers or unregisters fluid 
## blocks on the simulation queue when WorldController fires block updates.
func _on_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	if type == BlockType.Type.WATER or type == BlockType.Type.LAVA:
		register_fluid_block(global_pos, type)
	else:
		unregister_fluid_block(global_pos)
		
		# Proactive Adjacent Fluid Activation:
		# If a solid block becomes AIR, scan all 6 neighbors. 
		# If any neighbor is a fluid, reactivate it so it flows into the empty space.
		if type == BlockType.Type.AIR:
			_reactivate_adjacent_fluids(global_pos)


## Scans all 6 adjacent neighbors and re-registers any stable fluid block into the queue.
func _reactivate_adjacent_fluids(global_pos: Vector3i) -> void:
	if world_state == null:
		return
		
	var offsets: Array[Vector3i] = [
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for offset: Vector3i in offsets:
		var neighbor_pos := global_pos + offset
		var neighbor_type := world_state.get_block(neighbor_pos)
		
		if neighbor_type == BlockType.Type.WATER or neighbor_type == BlockType.Type.LAVA:
			register_fluid_block(neighbor_pos, neighbor_type)


# ==============================================================================
# CELLULAR AUTOMATA CORE LOOPS
# ==============================================================================

## Public API: Called every frame by the WorldController. Updates timers and processes the queue.
func process_fluid_simulation(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = UPDATE_INTERVAL
		_simulate_cellular_tick()


## Main cellular automata algorithm
func _simulate_cellular_tick() -> void:
	if _active_fluids.size() == 0 or world_state == null or not is_instance_valid(world_controller):
		return
		
	# Gather a budgeted snapshot of active coordinates to process
	var active_keys := _active_fluids.keys()
	var processed_count := 0
	
	# New coordinates to add to the simulation on the next tick
	var next_tick_additions: Dictionary = {}
	var current_tick_removals: Array[Vector3i] = []
	
	for pos: Vector3i in active_keys:
		if processed_count >= MAX_UPDATES_PER_TICK:
			break
			
		processed_count += 1
		var state: FluidState = _active_fluids[pos] as FluidState
		
		# Double check if the block type has been overwritten in the world state
		var current_block := world_state.get_block(pos)
		if current_block != state.type:
			current_tick_removals.append(pos)
			continue
			
		# Flag to check if this fluid block has stabilized (finished spreading)
		var is_stable := true
		
		# ======================================================================
		# RULE 1: DOWNHILL GRAVITY FLOW (Highest priority)
		# ======================================================================
		var below_pos := pos + Vector3i(0, -1, 0)
		# Prevent flowing past bedrock
		if below_pos.y > 0:
			var below_block := world_state.get_block(below_pos)
			
			# Check stone/magma fusion rule
			if _check_and_apply_fusion(pos, state.type, below_pos, below_block):
				current_tick_removals.append(pos)
				continue
				
			if below_block == BlockType.Type.AIR:
				# Fluids falling down regain full spreading energy!
				var default_spread := MAX_WATER_SPREAD if state.type == BlockType.Type.WATER else MAX_LAVA_SPREAD
				world_controller.call("set_block_globally", below_pos, state.type)
				next_tick_additions[below_pos] = FluidState.new(state.type, default_spread)
				is_stable = false
				
		# ======================================================================
		# RULE 2: LATERAL SPREAD FLOW (Only if bottom is solid and we have spread energy)
		# ======================================================================
		if is_stable and state.remaining_spread > 0:
			var directions: Array[Vector3i] = [
				Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)
			]
			
			for dir: Vector3i in directions:
				var side_pos := pos + dir
				var side_block := world_state.get_block(side_pos)
				
				# Check stone/magma fusion rule
				if _check_and_apply_fusion(pos, state.type, side_pos, side_block):
					continue
					
				if side_block == BlockType.Type.AIR:
					world_controller.call("set_block_globally", side_pos, state.type)
					# Descending energy gradient
					next_tick_additions[side_pos] = FluidState.new(state.type, state.remaining_spread - 1)
					is_stable = false
					
		# If the fluid block has no more empty slots to spread to, it is marked as stable
		if is_stable:
			current_tick_removals.append(pos)
			
	# Apply mutations cleanly
	for rm_pos: Vector3i in current_tick_removals:
		_active_fluids.erase(rm_pos)
		
	for add_pos: Vector3i in next_tick_additions.keys():
		_active_fluids[add_pos] = next_tick_additions[add_pos]


## Custom Magma-Stone Fusion Rule: If Water and Lava collide, they neutralize 
## each other and turn into a solid, inert Stone Block.
func _check_and_apply_fusion(source_pos: Vector3i, source_type: BlockType.Type, target_pos: Vector3i, target_type: BlockType.Type) -> bool:
	var is_water_lava_clash := (
		(source_type == BlockType.Type.WATER and target_type == BlockType.Type.LAVA) or
		(source_type == BlockType.Type.LAVA and target_type == BlockType.Type.WATER)
	)
	
	if is_water_lava_clash:
		# Convert both origin and destination blocks to solid, inert Stone (ID 1)
		world_controller.call("set_block_globally", source_pos, BlockType.Type.STONE)
		world_controller.call("set_block_globally", target_pos, BlockType.Type.STONE)
		
		# Play a spatial steam/sizzling effect at the collision coordinate (Milestone 10 locator)
		AudioService.play_sfx_static("block_break", Vector3(target_pos))
		return true
		
	return false
