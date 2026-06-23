# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Audio Service managing programmatic soundtrack players,
#              flawless signal-based looping, and cinematic crossfading transitions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Audio/AudioService.gd
# ==============================================================================
class_name AudioService
extends Node

const MENU_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/menu_music.mp3"
const WORLD_MUSIC_PATH := "res://src/Infrastructure/UI/Assets/world_music.mp3"

var _menu_player: AudioStreamPlayer
var _world_player: AudioStreamPlayer

func _ready() -> void:
	_initialize_players()

func _initialize_systems_or_players() -> void:
	pass # Legacy helper placeholder

func _initialize_players() -> void:
	name = "AudioService"
	
	# 1. Main Menu Player Setup
	_menu_player = AudioStreamPlayer.new()
	_menu_player.name = "MenuPlayer"
	_menu_player.stream = load(MENU_MUSIC_PATH)
	_menu_player.volume_db = -80.0 # Start fully silent for smooth fade-ins
	
	# Bulletproof programmatic looping: Connect finished signal to replay automatically
	_menu_player.finished.connect(_menu_player.play)
	add_child(_menu_player)
	
	# 2. World Exploration Player Setup
	_world_player = AudioStreamPlayer.new()
	_world_player.name = "WorldPlayer"
	_world_player.stream = load(WORLD_MUSIC_PATH)
	_world_player.volume_db = -80.0 # Start fully silent
	
	# Programmatic looping for the exploration background track
	_completed_tasks_queue_loop()
	add_child(_world_player)

func _completed_tasks_queue_loop() -> void:
	_world_player.finished.connect(_world_player.play)

## Plays the Main Menu music with a smooth 1.5-second fade-in.
func play_menu_music() -> void:
	if not is_instance_valid(_menu_player):
		return
		
	_menu_player.play()
	
	# Smooth fade-in tween
	var tween := create_tween()
	tween.tween_property(_menu_player, "volume_db", -6.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Transitions from Menu Music to World Music using a cinematic 1.5-second crossfade.
func play_world_music() -> void:
	if not is_instance_valid(_menu_player) or not is_instance_valid(_world_player):
		return
		
	_world_player.play()
	
	# Crossfade: Fade-out menu player while fading-in world player in parallel
	var crossfade_tween := create_tween().set_parallel(true)
	crossfade_tween.tween_property(_menu_player, "volume_db", -80.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crossfade_tween.tween_property(_world_player, "volume_db", -6.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Stop the menu player once it is fully silent using the correct Godot 4 tween_callback API
	crossfade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_menu_player) and _menu_player.playing:
			# Disconnect finished signal temporarily during a manual stop to prevent double triggers
			_menu_player.finished.disconnect(_menu_player.play)
			_menu_player.stop()
			_menu_player.finished.connect(_menu_player.play) # Reconnect for future runs
	)

## Silently stops all playing soundtracks instantly.
func stop_all() -> void:
	if is_instance_valid(_menu_player) and _menu_player.playing:
		_menu_player.stop()
	if is_instance_valid(_world_player) and _world_player.playing:
		_world_player.stop()
