## Enemy - Walk to decor, but turns aggressive if player seen
extends CharacterBody2D
class_name Enemy

# Enemy AI: Find decor, walk to it, stand there
# If player is detected, enter AGGRESSIVE state and fire weapon

enum State {
	IDLE,           # Looking for decor to claim
	WALK_TO_DECOR,  # Walking toward claimed decor
	STANDING,       # At decor, just standing
	AGGRESSIVE,     # Attacking player
	DYING
}

@export var enemy_type: String = "elephant"
@export var max_health: int = 50
@export var speed: float = 12.0
@export var xp_reward: int = 25

var current_health: int
var current_state: State = State.IDLE
var claimed_decor_pos: Vector2 = Vector2.INF
var world_map: Node  # Reference to WorldMap for decor claiming
var knockback_velocity: Vector2 = Vector2.ZERO

var player: Node2D
var aim_pivot: Node2D
var weapon_manager: WeaponManager
var swear_bubble: Sprite2D # Visual indicator for aggro

# Animal sprite textures
const ANIMAL_SPRITES = {
	"elephant": preload("res://assets/sprites/enemies/elephant.png"),
	"giraffe": preload("res://assets/sprites/enemies/giraffe.png"),
	"hippo": preload("res://assets/sprites/enemies/hippo.png"),
	"monkey": preload("res://assets/sprites/enemies/monkey.png"),
	"panda": preload("res://assets/sprites/enemies/panda.png"),
	"parrot": preload("res://assets/sprites/enemies/parrot.png"),
	"penguin": preload("res://assets/sprites/enemies/penguin.png"),
	"pig": preload("res://assets/sprites/enemies/pig.png"),
	"rabbit": preload("res://assets/sprites/enemies/rabbit.png"),
	"snake": preload("res://assets/sprites/enemies/snake.png")
}

const ANIMAL_HEALTH = {
	"elephant": 100, "hippo": 90, "giraffe": 80,
	"panda": 60, "pig": 55, "monkey": 50,
	"rabbit": 35, "snake": 30, "parrot": 25, "penguin": 30
}

const ANIMAL_SPEEDS = {
	"elephant": 12, "hippo": 14, "giraffe": 16,
	"panda": 18, "pig": 19, "monkey": 22,
	"rabbit": 26, "snake": 24, "parrot": 28, "penguin": 20
}

# Mapping animals to a preferred weapon
const ANIMAL_WEAPONS = {
	"elephant": "shotgun",
	"hippo": "revolver",
	"giraffe": "sniper_rifle",
	"panda": "assault_rifle",
	"pig": "pistol",
	"monkey": "smg",
	"rabbit": "pistol",
	"snake": "smg",
	"parrot": "pistol",
	"penguin": "pistol"
}

func _ready():
	add_to_group("enemies")
	z_index = -8
	current_health = max_health
	
	aim_pivot = get_node_or_null("AimPivot")
	weapon_manager = get_node_or_null("WeaponManager")
	swear_bubble = get_node_or_null("SwearBubble")
	if swear_bubble: swear_bubble.visible = false
	
	find_player()
	
	# DetectionArea signals
	var detection_area = get_node_or_null("DetectionArea")
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func find_world_map():
	if not is_inside_tree(): return
	var world_maps = get_tree().get_nodes_in_group("world_map")
	if world_maps.size() > 0:
		world_map = world_maps[0]

func _physics_process(_delta):
	if current_state == State.DYING: return

	match current_state:
		State.IDLE: handle_idle_state()
		State.WALK_TO_DECOR: handle_walk_to_decor_state()
		State.STANDING: handle_standing_state()
		State.AGGRESSIVE: handle_aggressive_state()
			
	if weapon_manager:
		weapon_manager.process_weapons(_delta)

	if knockback_velocity.length() > 5.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * _delta)
		move_and_slide()
	elif knockback_velocity.length() > 0:
		knockback_velocity = Vector2.ZERO

func handle_idle_state():
	if not world_map:
		find_world_map()
		return
	var nearest_decor = world_map.get_nearest_available_decor(global_position)
	if nearest_decor != Vector2.INF:
		if world_map.claim_decor(nearest_decor):
			claimed_decor_pos = nearest_decor
			current_state = State.WALK_TO_DECOR

func handle_walk_to_decor_state():
	if claimed_decor_pos == Vector2.INF:
		current_state = State.IDLE
		return
	if world_map and not world_map.decor_positions.has(claimed_decor_pos):
		claimed_decor_pos = Vector2.INF
		current_state = State.IDLE
		return
	var distance_to_decor = global_position.distance_to(claimed_decor_pos)
	if distance_to_decor <= 5.0:
		global_position = claimed_decor_pos
		velocity = Vector2.ZERO
		current_state = State.STANDING
		return
	var direction = (claimed_decor_pos - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func handle_standing_state():
	velocity = Vector2.ZERO

func handle_aggressive_state():
	if not player or not is_instance_valid(player):
		current_state = State.IDLE
		if weapon_manager: weapon_manager.stop_firing()
		if swear_bubble: swear_bubble.visible = false
		return
	
	# Look at player
	if aim_pivot:
		aim_pivot.look_at(player.global_position)
	
	# Stay roughly in place or strafe? For now just stand and shoot
	velocity = Vector2.ZERO
	
	# Trigger firing if not already
	if weapon_manager and not weapon_manager.is_firing:
		weapon_manager.start_firing()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		enter_aggressive_state()

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		exit_aggressive_state()

func enter_aggressive_state():
	if current_state == State.DYING: return
	current_state = State.AGGRESSIVE
	if swear_bubble: swear_bubble.visible = true
	# Optional: play "angry" sound or effect

func exit_aggressive_state():
	if current_state == State.AGGRESSIVE:
		current_state = State.IDLE
		if weapon_manager: weapon_manager.stop_firing()
		if swear_bubble: swear_bubble.visible = false

func take_damage(amount: int):
	current_health -= amount
	EventBus.enemy_damaged.emit(self, amount)

	# When shot, walk to the next closest decor item
	if current_state != State.DYING:
		seek_new_decor()

	if current_health <= 0:
		die()

func seek_new_decor():
	# Release current decor claim if we have one
	if world_map and claimed_decor_pos != Vector2.INF:
		world_map.release_decor(claimed_decor_pos)
		claimed_decor_pos = Vector2.INF

	# Stop firing if we were aggressive
	if weapon_manager:
		weapon_manager.stop_firing()
	if swear_bubble:
		swear_bubble.visible = false

	# Find and claim new decor to walk to
	if not world_map:
		find_world_map()
	if world_map:
		var nearest_decor = world_map.get_nearest_available_decor(global_position)
		if nearest_decor != Vector2.INF:
			if world_map.claim_decor(nearest_decor):
				claimed_decor_pos = nearest_decor
				current_state = State.WALK_TO_DECOR
				return
	# Fallback to idle if no decor available
	current_state = State.IDLE

func die():
	if current_state == State.DYING: return
	current_state = State.DYING
	if weapon_manager: weapon_manager.stop_firing()
	set_process(false)
	set_physics_process(false)
	if world_map and claimed_decor_pos != Vector2.INF:
		world_map.release_decor(claimed_decor_pos)
	EventBus.enemy_died.emit(self, global_position)
	EventBus.player_xp_gained.emit(xp_reward)
	Pools.return_enemy(self)

func apply_enemy_type(type_name: String):
	enemy_type = type_name
	if ANIMAL_HEALTH.has(enemy_type):
		max_health = ANIMAL_HEALTH[enemy_type]
		current_health = max_health
	if ANIMAL_SPEEDS.has(enemy_type):
		speed = ANIMAL_SPEEDS[enemy_type]
	
	# Set XP reward
	if max_health >= 80: xp_reward = 75
	elif max_health >= 50: xp_reward = 50
	else: xp_reward = 25

	var sprite: Sprite2D = $Sprite2D
	if sprite and ANIMAL_SPRITES.has(enemy_type):
		sprite.texture = ANIMAL_SPRITES[enemy_type]
	
	# Give weapon
	if weapon_manager:
		var w_name = ANIMAL_WEAPONS.get(enemy_type, "pistol")
		weapon_manager.weapons = [w_name]
		weapon_manager.current_weapon_index = 0
		weapon_manager.setup_weapons()  # Initialize fire_timers for new weapon
		weapon_manager.update_weapon_data(w_name)
		
		# Accuracy Feature: Slower = more accurate, Faster = less accurate
		# Base speed for normalization is 20.0
		weapon_manager.spread_multiplier = speed / 20.0
		print("Enemy ", enemy_type, " accuracy multiplier: ", weapon_manager.spread_multiplier)

func prepare_for_pool():
	if weapon_manager: weapon_manager.stop_firing()
	velocity = Vector2.ZERO
	visible = false
	if world_map and claimed_decor_pos != Vector2.INF:
		world_map.release_decor(claimed_decor_pos)
		claimed_decor_pos = Vector2.INF
	set_process(false)
	set_physics_process(false)
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

func prepare_for_spawn():
	current_state = State.IDLE
	claimed_decor_pos = Vector2.INF
	velocity = Vector2.ZERO
	visible = true
	z_index = -8
	if swear_bubble: swear_bubble.visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	set_physics_process(true)

func reset():
	prepare_for_spawn()
	apply_enemy_type(enemy_type)
