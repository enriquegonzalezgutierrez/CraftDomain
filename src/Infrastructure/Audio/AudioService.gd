# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Audio Service managing programmatic soundtrack players,
#              flawless signal-based looping, and safe bidirectional crossfading transitions.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively audio buffers and 
#   fade transactions.
# - Dependency Inversion Principle (DIP): Receives player and world dependencies 
#   explicitly via injection instead of parent SceneTree queries, and evaluates 
#   time statically through CelestialService.
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

# --- INJECTED DEPENDENCIES (DIP COMPLIANT) ---
var player: CharacterBody3D
var world_controller: WorldController

# Double-buffered players to allow seamless crossfading
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_buffer_is_a: bool = true

# Loaded Audio Stream Resources Cache (LAG SPIKE PREVENTION)
var _streams_cache: Dictionary = {}

# Current active track state
var _current_track: TrackType = TrackType.NONE

# Active crossfade tween to prevent overlaps
var _crossfade_tween: Tween

# Throttled update timer
var _check_timer: float = 1.0


func _ready() -> void:
	_preload_audio_resources()
	_initialize_players()


## Caches all audio files on boot to prevent main thread lag during transitions.
## Uses ResourceLoader.exists() to guarantee safety when executing in exported binaries.
func _preload_audio_resources() -> void:
	print("[AudioService] Preloading all situation progressive EDM tracks...")
	_streams_cache[TrackType.MENU] = load(MENU_MUSIC_PATH)
	_streams_cache[TrackType.WORLD] = load(WORLD_MUSIC_PATH)
	
	# Load optional situational tracks with fallback safeguards if not generated yet
	if ResourceLoader.exists(COMBAT_MUSIC_PATH):
		_streams_cache[TrackType.COMBAT] = load(COMBAT_MUSIC_PATH)
	else:
		_streams_cache[TrackType.COMBAT] = _streams_cache[TrackType.WORLD] # Fallback
		
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
	
	# Reprodutor A Setup
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "PlayerA"
	_player_a.volume_db = -80.0
	_player_a.bus = "Music"
	# Programmatic looping connected directly to finished signal
	_player_a.finished.connect(func() -> void: _player_a.play())
	add_child(_player_a)
	
	# Reprodutor B Setup
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "PlayerB"
	_player_b.volume_db = -80.0
	_player_b.bus = "Music"
	_player_b.finished.connect(func() -> void: _player_b.play())
	add_child(_player_b)


## Throttled Frame update: Evaluates player biome and daylight state once a second
func _process(delta: float) -> void:
	if _current_track == TrackType.MENU or _current_track == TrackType.NONE:
		return # Do not run world tracking while in Main Menu
		
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_evaluate_situational_soundtrack()


## Scans player coordinates and celestial orbits to dispatch the appropriate EDM track
func _evaluate_situational_soundtrack() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller) or not player.get("is_active"):
		return
		
	# 1. Check Night state (Triggers high-energy Combat Big Room)
	# DIP Compliance: Evaluates night state statically
	var is_night: bool = CelestialService.is_night_time_static()
		
	if is_night:
		_crossfade_to_track(TrackType.COMBAT)
		return
		
	# 2. Check Biome State
	var biome_id := 2 # Plains default
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if is_instance_valid(generator):
		var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var p_pos := player.global_position
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise) as BiomeService.BiomeProfile
			biome_id = profile.biome_id
			
	match biome_id:
		4, 9: # Frostbite Glaciers or Cloud Kingdom (Triggers Melodic Techno)
			_crossfade_to_track(TrackType.POLAR)
		7: # Neon Ruins (Triggers Cyber Future House)
			_crossfade_to_track(TrackType.CYBER)
		_: # Standard Overworld (Triggers Progressive House)
			_crossfade_to_track(TrackType.WORLD)


## Programmatic double-buffered crossfade executing smooth volume transition over 2.0 seconds
func _crossfade_to_track(target_track: TrackType) -> void:
	if _current_track == target_track:
		return # Track already playing
		
	var stream: AudioStream = _streams_cache.get(target_track) as AudioStream
	if stream == null:
		return
		
	_current_track = target_track
	
	# Identify active (fading out) and inactive (fading in) buffers
	var active_player := _player_a if _active_buffer_is_a else _player_b
	var inactive_player := _player_b if _active_buffer_is_a else _player_a
	_active_buffer_is_a = not _active_buffer_is_a # Toggle active buffer
	
	# Load and play the new track silently
	inactive_player.stream = stream
	inactive_player.volume_db = -80.0
	inactive_player.play()
	
	print("[AudioService] Crossfading to EDM Track Type: ", target_track)
	
	if is_instance_valid(_crossfade_tween) and _crossfade_tween.is_running():
		_crossfade_tween.kill()
		
	_crossfade_tween = create_tween().set_parallel(true)
	# Smoothly crossfade volumes in parallel
	_crossfade_tween.tween_property(active_player, "volume_db", -80.0, 2.0).set_trans(Tween.TRANS_SINE)
	_crossfade_tween.tween_property(inactive_player, "volume_db", -6.0, 2.0).set_trans(Tween.TRANS_SINE)
	
	# Stop the old player once it is completely silent to save CPU cycles
	_crossfade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(active_player) and active_player.playing:
			active_player.stop() # Safe manual stop, does not emit finished signal
	)


## Public API: Initial Menu Music Play
func play_menu_music() -> void:
	_current_track = TrackType.MENU
	_active_buffer_is_a = true
	
	_player_a.stream = _streams_cache[TrackType.MENU] as AudioStream
	_player_a.volume_db = -6.0
	_player_a.play()


## Public API: Cinematic crossfade from Menu to first Overworld exploration track
func crossfade_to_world() -> void:
	_crossfade_to_track(TrackType.WORLD)


## Public API: Cinematic crossfade back to Menu Music
func crossfade_to_menu() -> void:
	_crossfade_to_track(TrackType.MENU)


## Silently halts all players instantly
func stop_all() -> void:
	if is_instance_valid(_crossfade_tween):
		_crossfade_tween.kill()
		
	if is_instance_valid(_player_a) and _player_a.playing:
		_player_a.stop()
	if is_instance_valid(_player_b) and _player_b.playing:
		_player_b.stop()
