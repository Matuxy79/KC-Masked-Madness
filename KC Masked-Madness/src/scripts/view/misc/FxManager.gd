## FxManager script. handles visual and audio effects.
extends Node
class_name FxManager

# FxManager - Handles visual and audio effects
# Manages particles, sounds, and screen effects

@export var particle_scenes: Dictionary = {}
@export var sound_effects: Dictionary = {}

var active_particles: Array[Node2D] = []
var footstep_timer: float = 0.0
@export var footstep_interval: float = 0.35
var is_player_moving: bool = false

func _ready():
	print("FxManager initialized")
	load_effect_resources()
	setup_signals()

func _process(delta):
	if is_player_moving:
		footstep_timer -= delta
		if footstep_timer <= 0:
			play_sound("move")
			footstep_timer = footstep_interval
	else:
		footstep_timer = 0 # Reset so it plays immediately when starting to move

func setup_signals():
	# Connect to EventBus signals for automatic effect triggering
	if not EventBus.projectile_hit.is_connected(_on_projectile_hit):
		EventBus.projectile_hit.connect(_on_projectile_hit)
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	if not EventBus.xp_gem_collected.is_connected(_on_xp_gem_collected):
		EventBus.xp_gem_collected.connect(_on_xp_gem_collected)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.weapon_fired.is_connected(_on_weapon_fired):
		EventBus.weapon_fired.connect(_on_weapon_fired)
	if not EventBus.player_level_up.is_connected(_on_player_level_up):
		EventBus.player_level_up.connect(_on_player_level_up)
	if not EventBus.enemy_damaged.is_connected(_on_enemy_damaged):
		EventBus.enemy_damaged.connect(_on_enemy_damaged)
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	if not EventBus.powerup_collected.is_connected(_on_powerup_collected):
		EventBus.powerup_collected.connect(_on_powerup_collected)
	if not EventBus.player_moved.is_connected(_on_player_moved):
		EventBus.player_moved.connect(_on_player_moved)

func load_effect_resources():
	# Load particle scenes (placeholders for now)
	particle_scenes = {
		"hit_effect": null,
		"explosion": null,
		"xp_collect": null
	}
	
	# Load sound effects with variations
	sound_effects = {
		"shoot": [
			preload("res://assets/Sounds/shoot-a.ogg"),
			preload("res://assets/Sounds/shoot-b.ogg"),
			preload("res://assets/Sounds/shoot-c.ogg"),
			preload("res://assets/Sounds/shoot-d.ogg"),
			preload("res://assets/Sounds/shoot-e.ogg"),
			preload("res://assets/Sounds/shoot-f.ogg"),
			preload("res://assets/Sounds/shoot-g.ogg"),
			preload("res://assets/Sounds/shoot-h.ogg")
		],
		"explosion": [
			preload("res://assets/Sounds/explosion-a.ogg"),
			preload("res://assets/Sounds/explosion-b.ogg"),
			preload("res://assets/Sounds/explosion-c.ogg")
		],
		"xp_collect": [
			preload("res://assets/Sounds/coin-a.ogg"),
			preload("res://assets/Sounds/coin-b.ogg"),
			preload("res://assets/Sounds/coin-c.ogg"),
			preload("res://assets/Sounds/coin-d.ogg")
		],
		"hurt": [
			preload("res://assets/Sounds/hurt-a.ogg"),
			preload("res://assets/Sounds/hurt-b.ogg"),
			preload("res://assets/Sounds/hurt-c.ogg"),
			preload("res://assets/Sounds/hurt-d.ogg"),
			preload("res://assets/Sounds/hurt-e.ogg")
		],
		"player_death": [
			preload("res://assets/Sounds/lose-a.ogg"),
			preload("res://assets/Sounds/lose-b.ogg"),
			preload("res://assets/Sounds/lose-c.ogg"),
			preload("res://assets/Sounds/lose-d.ogg")
		],
		"level_up": [
			preload("res://assets/Sounds/select-a.ogg")
		],
		"move": [
			preload("res://assets/Sounds/move-a.ogg"),
			preload("res://assets/Sounds/move-b.ogg"),
			preload("res://assets/Sounds/move-c.ogg"),
			preload("res://assets/Sounds/move-d.ogg")
		],
		"jump": [
			preload("res://assets/Sounds/jump-a.ogg"),
			preload("res://assets/Sounds/jump-b.ogg"),
			preload("res://assets/Sounds/jump-c.ogg"),
			preload("res://assets/Sounds/jump-d.ogg"),
			preload("res://assets/Sounds/jump-e.ogg"),
			preload("res://assets/Sounds/jump-f.ogg")
		],
		"fall": [
			preload("res://assets/Sounds/fall-a.ogg"),
			preload("res://assets/Sounds/fall-b.ogg")
		],
		"select": [
			preload("res://assets/Sounds/select-a.ogg")
		],
		"error": [
			preload("res://assets/Sounds/error-a.ogg"),
			preload("res://assets/Sounds/error-b.ogg"),
			preload("res://assets/Sounds/error-c.ogg")
		]
	}

func _on_projectile_hit(target: Node2D, _damage: int):
	play_hit_effect(target.global_position)
	play_sound("hurt")

func _on_enemy_damaged(_enemy: Node2D, _damage: int):
	pass

func _on_enemy_died(_enemy: Node2D, position: Vector2):
	play_explosion_effect(position)
	play_sound("explosion")

func _on_xp_gem_collected(_amount: int):
	play_xp_collect_effect()
	play_sound("xp_collect")

func _on_player_died():
	play_death_effect()
	play_sound("player_death")

func _on_weapon_fired(_weapon_name: String, _direction: Vector2):
	play_sound("shoot")

func _on_player_level_up(_new_level: int):
	play_sound("level_up")

func _on_game_started():
	play_sound("select")

func _on_powerup_collected(_duration: float):
	play_sound("select")

func _on_player_moved(_position: Vector2):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player is CharacterBody2D:
			is_player_moving = player.velocity.length() > 10.0
		else:
			is_player_moving = true
	else:
		is_player_moving = false

func play_hit_effect(_position: Vector2):
	pass

func play_explosion_effect(_position: Vector2):
	pass

func play_xp_collect_effect():
	pass

func play_death_effect():
	pass

func play_sound(sound_name: String):
	if sound_name in sound_effects:
		var variations = sound_effects[sound_name]
		if variations.size() > 0:
			var stream = variations[randi() % variations.size()]
			if stream:
				var audio_player = AudioStreamPlayer.new()
				audio_player.stream = stream
				audio_player.bus = "SFX"
				audio_player.pitch_scale = randf_range(0.9, 1.1)
				add_child(audio_player)
				audio_player.finished.connect(audio_player.queue_free)
				audio_player.play()

func play_particle_effect(effect_name: String, position: Vector2):
	if effect_name in particle_scenes:
		var scene = particle_scenes[effect_name]
		if scene:
			var particle = scene.instantiate()
			particle.global_position = position
			get_tree().current_scene.add_child(particle)
			active_particles.append(particle)

func cleanup_particles():
	for particle in active_particles:
		if particle and is_instance_valid(particle):
			if not particle.emitting:
				particle.queue_free()
				active_particles.erase(particle)

func screen_shake(intensity: float, duration: float):
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(intensity, duration)