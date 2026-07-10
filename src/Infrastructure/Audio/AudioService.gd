# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Audio Service managing programmatic soundtrack players,
#              flawless signal-based looping, and safe positional 3D sound effects.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively audio buffers,
#   soundtrack crossfading, and dynamic spatial SFX instantiation.
# - Open-Closed Principle (OCP): Dynamic multi-extension scanner with adjustable 
#   3D spatial attenuation bounds. Allows custom distances for ambient animals 
#   without hardcoding specific rules inside the audio loop.
# - Dependency Inversion Principle (DIP): Injected dependencies are used to 
#   subscribe to Domain/Infrastructure events reactively.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Audio/AudioService.gd
# ==============================================================================
class_name AudioService
extends Node

# Static instance provider for global access (Service Locator Pattern)
static var instance: AudioService = null

# Situational Track Enum
enum TrackType {
	NONE,
	MENU,
	WORLD,
	COMBAT,
	CYBER,
	POLAR
}

# Standardized Resource Paths for Music (Music is enum-bound, SFX is dynamic)
const MENU_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/menu_music.mp3"
const WORLD_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/world_music.mp3"
const COMBAT_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/combat_music.mp3"
const CYBER_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/cyber_music.mp3"
const POLAR_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/polar_music.mp3"

# Base directory for dynamic SFX loading
const SFX_BASE_DIR := "res://assets/audio/"

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

# Loaded Audio Stream Resources Cache
var _streams_cache: Dictionary = {}
var _sfx_cache: Dictionary = {} # Dynamically populated via Lazy Loading (OCP)

# Current active track state
var _current_track: TrackType = TrackType.NONE
var _crossfade_tween: Tween
var _check_timer: float = 1.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_preload_audio_resources()
	_initialize_players()


## Caches all heavy EDM soundtrack files on boot to prevent main thread lag.
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


func _initialize_players() -> void:
	name = "AudioService"
	
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "PlayerA"
	_player_a.volume_db = -80.0
	_player_a.bus = "Music"
	_player_a.finished.connect(func() -> void: _player_a.play())
	add_child(_player_a)
	
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "PlayerB"
	_player_b.volume_db = -80.0
	_player_b.bus = "Music"
	_player_b.finished.connect(func() -> void: _player_b.play())
	add_child(_player_b)


func _process(delta: float) -> void:
	if _current_track == TrackType.MENU or _current_track == TrackType.NONE:
		return
		
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_evaluate_situational_soundtrack()


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
		4, 9: _crossfade_to_track(TrackType.POLAR)
		7: _crossfade_to_track(TrackType.CYBER)
		_: _crossfade_to_track(TrackType.WORLD)


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
# OBSERVATION INJECTION SYSTEMS
# ==============================================================================

func _subscribe_to_player_signals() -> void:
	if not is_instance_valid(player):
		return
	var entity: VoxelEntity = player.get("domain_entity") as VoxelEntity
	if is_instance_valid(entity) and not entity.took_damage.is_connected(_on_player_took_damage):
		entity.took_damage.connect(_on_player_took_damage)
	if player.has_signal("sword_swung") and not player.sword_swung.is_connected(_on_player_sword_swung):
		player.sword_swung.connect(_on_player_sword_swung)


func _subscribe_to_world_signals() -> void:
	if not is_instance_valid(world_controller):
		return
	if world_controller.has_signal("block_modified") and not world_controller.block_modified.is_connected(_on_block_modified):
		world_controller.block_modified.connect(_on_block_modified)


func _on_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	var sound_pos := Vector3(global_pos) + Vector3(0.5, 0.5, 0.5)
	if type == BlockType.Type.AIR:
		play_sfx_local("block_break", sound_pos)
	else:
		play_sfx_local("block_place", sound_pos)


func _on_player_sword_swung() -> void:
	if is_instance_valid(player):
		play_sfx_local("hit_sword", player.global_position)


func _on_player_took_damage(_amount: int) -> void:
	if is_instance_valid(player):
		play_sfx_local("player_hit", player.global_position)


# ==============================================================================
# DYNAMIC MULTI-EXTENSION LAZY-LOADING SFX LOCATOR (OCP / SOLID COMPLIANCE)
# ==============================================================================

## Fetches a sound stream from cache. If not found, dynamically scans for 
## .ogg, .mp3, or .wav files, supporting any downloaded format instantly.
func _get_or_load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name] as AudioStream
		
	# Scans multiple extensions sequentially to prevent missing formats!
	var extensions: Array[String] = [".ogg", ".mp3", ".wav"]
	
	for ext: String in extensions:
		var path := SFX_BASE_DIR + sfx_name + ext
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_sfx_cache[sfx_name] = stream
				print("[AudioService] Dynamically cached audio file: ", sfx_name, ext)
				return stream
				
	push_warning("[AudioService WARNING] Failed to locate audio asset: %s with formats (.ogg, .mp3, .wav)" % sfx_name)
	return null


## Static Service Locator API: Allows any scene node to trigger sounds globally.
## [param max_distance]: Optional parameter to set a custom 3D spatial attenuation boundary.
static func play_sfx_static(sfx_name: String, global_pos: Vector3 = Vector3.ZERO, max_distance: float = 20.0) -> void:
	if is_instance_valid(instance):
		instance.play_sfx_local(sfx_name, global_pos, max_distance)


## Local router: Fetches stream dynamically and plays it.
func play_sfx_local(sfx_name: String, global_pos: Vector3 = Vector3.ZERO, max_distance: float = 20.0) -> void:
	var stream := _get_or_load_sfx(sfx_name)
	if stream == null:
		return
		
	# If global_pos is Vector3.ZERO or we are in the main menu, output as flat stereo
	if global_pos == Vector3.ZERO:
		var player_2d := AudioStreamPlayer.new()
		player_2d.stream = stream
		player_2d.volume_db = -3.0
		player_2d.bus = "SFX"
		add_child(player_2d)
		player_2d.play()
		player_2d.finished.connect(player_2d.queue_free)
	else:
		_play_sound_3d(stream, global_pos, -2.0, max_distance)


## Instantiates and plays a 3D positional sound, auto-freeing itself upon completion.
func _play_sound_3d(stream: AudioStream, global_pos: Vector3, db_volume: float = 0.0, max_distance: float = 20.0) -> void:
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = db_volume
	player_3d.bus = "SFX"
	
	# ==========================================================================
	# TACTICAL RANGE ATTENUATION MODEL (OCP / SOLID COMPLIANCE)
	# Sets max_distance dynamically based on the caller specification.
	# Scales 'unit_size' proportionally so that the sound volume rolls off 
	# logarithmically. This allows ambient bird songs to be heard faintly 
	# in the far background while keeping close-combat attacks short-ranged.
	# ==========================================================================
	player_3d.max_distance = max_distance
	player_3d.unit_size = max_distance / 4.0 
	player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# ==========================================================================
	# 3D SPATIAL ANCHOR RESOLUTION (SOLID / GODOT FIX)
	# ==========================================================================
	var parent_node: Node = self
	if is_instance_valid(world_controller):
		parent_node = world_controller
	elif is_instance_valid(get_tree()) and is_instance_valid(get_tree().root):
		parent_node = get_tree().root
		
	parent_node.add_child(player_3d)
	player_3d.global_position = global_pos
	player_3d.play()
	
	# Assures non-looping safe cleanup
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
