# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Audio Service managing programmatic soundtrack players,
#              flawless signal-based looping, and safe positional 3D sound effects.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively audio buffers,
#   soundtrack crossfading, and dynamic spatial SFX instantiation.
# - Dependency Inversion Principle (DIP): Injected dependencies are used to 
#   subscribe to Domain/Infrastructure events reactively, preventing sound logic
#   from leaking into generation or interaction components.
# OBSERVER PATTERN SOUNDSCAPE:
# - Connects to `world_controller.block_modified` to spawn 3D soundscapes at 
#   exact block coordinates on break or placement.
# - Connects to `player_controller.took_damage` to trigger damage grunts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Audio/AudioService.gd
# ==============================================================================
class_name AudioService
extends Node

# Situational Track Enum
enum TrackType {
	NONE,
	MENU,
	WORLD,
	COMBAT,
	CYBER,
	POLAR
}

# Standardized Resource Paths matching Suno AI exports
const MENU_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/menu_music.mp3"
const WORLD_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/world_music.mp3"
const COMBAT_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/combat_music.mp3"
const CYBER_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/cyber_music.mp3"
const POLAR_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/polar_music.mp3"

# ==============================================================================
# OBSERVER SFX PATHS (Milestone 10) - Updated to OGG
# ==============================================================================
const SFX_BLOCK_BREAK_PATH := "res://assets/audio/block_break.ogg"
const SFX_BLOCK_PLACE_PATH := "res://assets/audio/block_place.ogg"
const SFX_HIT_SWORD_PATH := "res://assets/audio/hit_sword.ogg"
const SFX_PLAYER_HIT_PATH := "res://assets/audio/player_hit.ogg"

# --- INJECTED DEPENDENCIES (DIP COMPLIANT) ---
var player: CharacterBody3D:
	set(val):
		player = val
		_subscribe_to_player_signals()
		
var world_controller: Node3D:
	set(val):
		world_controller = val
		_subscribe_to_world_signals()

# Double-buffered players to allow seamless crossfading
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_buffer_is_a: bool = true

# Loaded Audio Stream Resources Cache (LAG SPIKE PREVENTION)
var _streams_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}

# Current active track state
var _current_track: TrackType = TrackType.NONE

# Active crossfade tween to prevent overlaps
var _crossfade_tween: Tween

# Throttled update timer
var _check_timer: float = 1.0


func _ready() -> void:
	_preload_audio_resources()
	_preload_sfx_resources()
	_initialize_players()


## Caches all soundtrack files on boot to prevent main thread lag.
func _preload_audio_resources() -> void:
	print("[AudioService] Preloading all progressive EDM tracks...")
	_streams_cache[TrackType.MENU] = load(MENU_MUSIC_PATH)
	_streams_cache[TrackType.WORLD] = load(WORLD_MUSIC_PATH)
	
	if ResourceLoader.exists(COMBAT_MUSIC_PATH):
		_streams_cache[TrackType.COMBAT] = load(COMBAT_MUSIC_PATH)
	else:
		_streams_cache[TrackType.COMBAT] = _streams_cache[TrackType.WORLD]
		
	if ResourceLoader.exists(CYBER_MUSIC_PATH):
		_streams_cache[TrackType.CYBER] = load(CYBER_MUSIC_PATH)
	else:
		_streams_cache[TrackType.CYBER] = _streams_cache[TrackType.WORLD]
		
	if ResourceLoader.exists(POLAR_MUSIC_PATH):
		_streams_cache[TrackType.POLAR] = load(POLAR_MUSIC_PATH)
	else:
		_streams_cache[TrackType.POLAR] = _streams_cache[TrackType.WORLD]


## Preloads the positional SFX files into memory to avoid I/O stutters when playing sounds.
func _preload_sfx_resources() -> void:
	print("[AudioService] Preloading gameplay sound effect resources...")
	if ResourceLoader.exists(SFX_BLOCK_BREAK_PATH):
		_sfx_cache["block_break"] = load(SFX_BLOCK_BREAK_PATH)
	if ResourceLoader.exists(SFX_BLOCK_PLACE_PATH):
		_sfx_cache["block_place"] = load(SFX_BLOCK_PLACE_PATH)
	if ResourceLoader.exists(SFX_HIT_SWORD_PATH):
		_sfx_cache["hit_sword"] = load(SFX_HIT_SWORD_PATH)
	if ResourceLoader.exists(SFX_PLAYER_HIT_PATH):
		_sfx_cache["player_hit"] = load(SFX_PLAYER_HIT_PATH)


func _initialize_players() -> void:
	name = "AudioService"
	
	# Player A Setup
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "PlayerA"
	_player_a.volume_db = -80.0
	_player_a.bus = "Music"
	_player_a.finished.connect(func() -> void: _player_a.play())
	add_child(_player_a)
	
	# Player B Setup
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "PlayerB"
	_player_b.volume_db = -80.0
	_player_b.bus = "Music"
	_player_b.finished.connect(func() -> void: _player_b.play())
	add_child(_player_b)


## Throttled Frame update: Evaluates player biome and daylight state once a second
func _process(delta: float) -> void:
	if _current_track == TrackType.MENU or _current_track == TrackType.NONE:
		return
		
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_evaluate_situational_soundtrack()


## Scans player coordinates and celestial orbits to dispatch the appropriate EDM track
func _evaluate_situational_soundtrack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller) or not player.get("is_active"):
		return
		
	var is_night: bool = CelestialService.is_night_time_static()
	if is_night:
		_crossfade_to_track(TrackType.COMBAT)
		return
		
	var biome_id := 2
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if is_instance_valid(generator):
		var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var p_pos := player.global_position
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise) as BiomeService.BiomeProfile
			biome_id = profile.biome_id
			
	match biome_id:
		4, 9:
			_crossfade_to_track(TrackType.POLAR)
		7:
			_crossfade_to_track(TrackType.CYBER)
		_:
			_crossfade_to_track(TrackType.WORLD)


## Programmatic double-buffered crossfade executing smooth volume transition over 2.0 seconds
func _crossfade_to_track(target_track: TrackType) -> void:
	if _current_track == target_track:
		return
		
	var stream: AudioStream = _streams_cache.get(target_track) as AudioStream
	if stream == null:
		return
		
	_current_track = target_track
	
	var active_player := _player_a if _active_buffer_is_a else _player_b
	var inactive_player := _player_b if _active_buffer_is_a else _player_a
	_active_buffer_is_a = not _active_buffer_is_a
	
	inactive_player.stream = stream
	inactive_player.volume_db = -80.0
	inactive_player.play()
	
	print("[AudioService] Crossfading to EDM Track Type: ", target_track)
	
	if is_instance_valid(_crossfade_tween) and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		
	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.tween_property(active_player, "volume_db", -80.0, 2.0).set_trans(Tween.TRANS_SINE)
	_crossfade_tween.tween_property(inactive_player, "volume_db", -6.0, 2.0).set_trans(Tween.TRANS_SINE)
	
	_crossfade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(active_player) and active_player.playing:
			active_player.stop()
	)


# ==============================================================================
# OBSERVATION INJECTION SYSTEMS & ROUTERS (Milestone 10)
# ==============================================================================

## Connects handlers to player actions reactively.
func _subscribe_to_player_signals() -> void:
	if not is_instance_valid(player):
		return
		
	# 1. Player damage grunt trigger
	var entity: VoxelEntity = player.get("domain_entity") as VoxelEntity
	if is_instance_valid(entity) and not entity.took_damage.is_connected(_on_player_took_damage):
		entity.took_damage.connect(_on_player_took_damage)
		
	# 2. Player sword swing whoosh trigger
	if player.has_signal("sword_swung") and not player.sword_swung.is_connected(_on_player_sword_swung):
		player.sword_swung.connect(_on_player_sword_swung)


## Connects handlers to block modifications reactively.
func _subscribe_to_world_signals() -> void:
	if not is_instance_valid(world_controller):
		return
		
	if world_controller.has_signal("block_modified") and not world_controller.block_modified.is_connected(_on_block_modified):
		world_controller.block_modified.connect(_on_block_modified)


## Handler: Spawns 3D sound effects at exact block coordinates when modified
func _on_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	var sound_pos := Vector3(global_pos) + Vector3(0.5, 0.5, 0.5)
	
	if type == BlockType.Type.AIR:
		# Block broken! Play break sound
		var break_stream: AudioStream = _sfx_cache.get("block_break") as AudioStream
		if break_stream != null:
			play_sound_3d(break_stream, sound_pos, -2.0)
	else:
		# Block placed! Play placement sound
		var place_stream: AudioStream = _sfx_cache.get("block_place") as AudioStream
		if place_stream != null:
			play_sound_3d(place_stream, sound_pos, -4.0)


## Handler: Plays metallic sword swish sound at the player's coordinate
func _on_player_sword_swung() -> void:
	if not is_instance_valid(player):
		return
		
	var sword_stream: AudioStream = _sfx_cache.get("hit_sword") as AudioStream
	if sword_stream != null:
		play_sound_3d(sword_stream, player.global_position, -3.0)


## Handler: Plays the damage grunt sound
func _on_player_took_damage(_amount: int) -> void:
	if not is_instance_valid(player):
		return
		
	var hit_stream: AudioStream = _sfx_cache.get("player_hit") as AudioStream
	if hit_stream != null:
		play_sound_3d(hit_stream, player.global_position, 0.0)


# ==============================================================================
# SPATIAL SFX LIFECYCLE INSTANTIATOR (Low-Level Memory Safe)
# ==============================================================================

## Instantiates and plays a 3D positional sound in the world, auto-freeing itself 
## once playback has completed to prevent memory leaks.
func play_sound_3d(stream: AudioStream, global_pos: Vector3, db_volume: float = 0.0) -> void:
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = db_volume
	player_3d.bus = "SFX" # Outputs to the standard SFX bus for volume control
	player_3d.max_distance = 18.0 # Culls sound outside range to save CPU
	
	add_child(player_3d) # <-- FIRST: Add to tree
	player_3d.global_position = global_pos # <-- SECOND: Set global position (Safe!)
	player_3d.play() # <-- THIRD: Play
	
	# Safe auto-destruction connection once the audio ends
	player_3d.finished.connect(player_3d.queue_free)


# ==============================================================================
# SYSTEM MANAGEMENT APIS
# ==============================================================================

func play_menu_music() -> void:
	_current_track = TrackType.MENU
	_active_buffer_is_a = true
	
	_player_a.stream = _streams_cache[TrackType.MENU] as AudioStream
	_player_a.volume_db = -6.0
	_player_a.play()


func crossfade_to_world() -> void:
	_crossfade_to_track(TrackType.WORLD)


func crossfade_to_menu() -> void:
	_crossfade_to_track(TrackType.MENU)


func stop_all() -> void:
	if is_instance_valid(_crossfade_tween):
		_crossfade_tween.kill()
		
	if is_instance_valid(_player_a) and _player_a.playing:
		_player_a.stop()
	if is_instance_valid(_player_b) and _player_b.playing:
		_player_b.stop()
