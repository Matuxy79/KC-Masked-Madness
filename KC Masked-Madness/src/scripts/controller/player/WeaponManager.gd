## WeaponManager script. handles weapons for both player and enemy.
extends Node
class_name WeaponManager

# Weapon brains. Keeps a list, decides when to shoot, and spawns projectiles.

@export var weapons: Array[String] = ["pistol", "revolver", "smg", "assault_rifle", "shotgun"]
@export var current_weapon_index: int = 0
@export var damage_multiplier: float = 1.0
@export var is_player: bool = false # Set to true for player-specific behavior

var fire_timers: Dictionary = {}
var pierce_bonus: int = 0 
var explosive_radius_multiplier: float = 1.0 
var fire_rate_multiplier: float = 1.0
var spread_multiplier: float = 1.0 # New: Affects accuracy

var temp_fire_rate_multiplier: float = 1.0
var temp_damage_multiplier: float = 1.0
var temp_projectile_speed_multiplier: float = 1.0
var powerup_timer: float = 0.0

var parent: Node2D
var aim_pivot: Node2D
var weapon_socket: Sprite2D
var muzzle: Marker2D

var current_weapon_data: Dictionary = {}
var burst_shots_left: int = 0
var burst_timer: float = 0.0
var burst_interval: float = 0.1

var is_firing: bool = false # Used for auto/semi firing state
var base_socket_pos: Vector2 = Vector2.ZERO
var kickback_offset: Vector2 = Vector2.ZERO

func _ready():
	parent = get_parent()
	aim_pivot = parent.get_node_or_null("AimPivot")
	if aim_pivot:
		weapon_socket = aim_pivot.get_node_or_null("WeaponSocket")
		if weapon_socket:
			muzzle = weapon_socket.get_node_or_null("Muzzle")
			base_socket_pos = weapon_socket.position
	
	if is_player:
		_setup_input_map()
	
	setup_weapons()
	
	# Load initial weapon data
	if not weapons.is_empty():
		update_weapon_data(weapons[current_weapon_index])

func _setup_input_map():
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")

	# Left Mouse Button
	var mouse_ev = InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("fire", mouse_ev):
		InputMap.action_add_event("fire", mouse_ev)

	# Space Bar
	var space_ev = InputEventKey.new()
	space_ev.keycode = KEY_SPACE
	if not InputMap.action_has_event("fire", space_ev):
		InputMap.action_add_event("fire", space_ev)

	# Weapon swap keys 1-5
	var weapon_keys = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for i in range(weapon_keys.size()):
		var action_name = "weapon_" + str(i + 1)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var key_ev = InputEventKey.new()
		key_ev.keycode = weapon_keys[i]
		if not InputMap.action_has_event(action_name, key_ev):
			InputMap.action_add_event(action_name, key_ev)

func setup_weapons():
	# Initialize fire timers
	for weapon_name in weapons:
		fire_timers[weapon_name] = 0.0

func process_weapons(delta: float):
	if not parent:
		return

	if powerup_timer > 0:
		powerup_timer -= delta
		if powerup_timer <= 0:
			clear_powerup()
	
	# Update fire timers
	for weapon_name in fire_timers.keys():
		if fire_timers[weapon_name] > 0:
			fire_timers[weapon_name] -= delta
	
	# Update burst timer
	if burst_shots_left > 0:
		burst_timer -= delta
		if burst_timer <= 0:
			fire_burst_shot()
	
	# Aiming logic (for player)
	if is_player and aim_pivot:
		var mouse_pos = parent.get_global_mouse_position()
		aim_pivot.look_at(mouse_pos)
		
	# Universal weapon flipping (prevent upside-down guns for both player and enemy)
	if aim_pivot and weapon_socket:
		var angle = aim_pivot.rotation_degrees
		while angle > 180: angle -= 360
		while angle < -180: angle += 360
		
		if abs(angle) > 90:
			weapon_socket.flip_v = true
		else:
			weapon_socket.flip_v = false

	# Handle continuous firing
	if is_firing:
		handle_firing_logic()
		
	# Smoothly return weapon socket to base position (Kickback recovery)
	if weapon_socket:
		kickback_offset = kickback_offset.lerp(Vector2.ZERO, delta * 15.0)
		weapon_socket.position = base_socket_pos + kickback_offset

func handle_firing_logic():
	if weapons.is_empty(): return
	var weapon_name = weapons[current_weapon_index]
	
	if burst_shots_left > 0: return

	var can_fire = fire_timers[weapon_name] <= 0
	var fire_mode = current_weapon_data.get("fire_mode", "semi")
	
	if can_fire:
		if fire_mode == "auto":
			fire_weapon_logic(weapon_name)
		elif fire_mode == "semi":
			fire_weapon_logic(weapon_name)
			is_firing = false # Only one shot for semi until reset
		elif fire_mode == "burst":
			start_burst(weapon_name)
			is_firing = false # Only one burst until reset
		elif fire_mode == "charge":
			fire_weapon_logic(weapon_name)
			is_firing = false

func start_firing():
	is_firing = true

func stop_firing():
	is_firing = false

func start_burst(weapon_name: String):
	var count = current_weapon_data.get("burst_count", 3)
	var interval = current_weapon_data.get("burst_interval", 0.06)
	
	burst_shots_left = count
	burst_interval = interval
	burst_timer = 0.0 # Start immediately
	
	var fire_rate = get_modified_fire_rate()
	fire_timers[weapon_name] = (1.0 / fire_rate) + (count * interval)

func fire_burst_shot():
	var weapon_name = weapons[current_weapon_index]
	fire_single_shot(weapon_name, current_weapon_data)
	
	burst_shots_left -= 1
	burst_timer = burst_interval

func fire_weapon_logic(weapon_name: String):
	var fire_rate = get_modified_fire_rate()
	
	# Set cooldown
	fire_timers[weapon_name] = 1.0 / fire_rate
	
	# Fire
	fire_single_shot(weapon_name, current_weapon_data)
	
	# Apply kickback
	if weapon_socket:
		var kick_amount = 4.0
		if weapon_name == "shotgun" or weapon_name == "sniper_rifle":
			kick_amount = 10.0
		kickback_offset = Vector2(-kick_amount, 0)

func fire_single_shot(weapon_name: String, weapon_data: Dictionary):
	# Calculate direction
	var base_direction = Vector2.RIGHT
	if aim_pivot:
		base_direction = Vector2.RIGHT.rotated(aim_pivot.rotation)
		
	var spread_deg = weapon_data.get("spread", 0.0) * spread_multiplier
	var pellets = weapon_data.get("pellets", 1)
	
	for i in range(pellets):
		var spread_angle = deg_to_rad(randf_range(-spread_deg/2.0, spread_deg/2.0))
		var final_direction = base_direction.rotated(spread_angle)
		spawn_projectile(weapon_name, weapon_data, final_direction)
	
	# Emit event
	EventBus.weapon_fired.emit(weapon_name, base_direction)

func spawn_projectile(weapon_name: String, weapon_data: Dictionary, direction: Vector2):
	var projectile = Pools.get_projectile()
	if not projectile:
		return
	
	# Position
	var spawn_pos = parent.global_position
	if muzzle:
		spawn_pos = muzzle.global_position
	
	# Stats
	var damage = weapon_data.get("damage", 10) * damage_multiplier * temp_damage_multiplier
	var speed = weapon_data.get("projectile_speed", 300) * temp_projectile_speed_multiplier
	var range_dist = weapon_data.get("range", 700)
	var explosive_radius = weapon_data.get("explosive_radius", 0.0) * explosive_radius_multiplier
	var knockback = weapon_data.get("knockback", 0.0)
	
	# Setup
	projectile.setup(damage, speed, direction, range_dist, explosive_radius, knockback)
	
	# Pierce
	var base_pierce = int(weapon_data.get("pierce", 0))
	projectile.pierce_count = base_pierce + pierce_bonus
	
	# Standardized Bullets
	var projectile_sprite = projectile.get_node_or_null("Sprite2D")
	if projectile_sprite:
		var bullet_tex = preload("res://assets/sprites/ui/Interface/effects/bullet.png")
		# Use special bullet for high tier weapons
		if weapon_name in ["sniper_rifle", "laser", "railgun", "rocket_launcher"]:
			bullet_tex = preload("res://assets/sprites/ui/Interface/effects/special-bullet.png")
		projectile_sprite.texture = bullet_tex

	# Set target group
	if is_player:
		projectile.target_group = "enemies"
	else:
		projectile.target_group = "player"

	# Add to scene and set position (remove from old parent first if needed)
	if projectile.get_parent():
		projectile.get_parent().remove_child(projectile)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.z_index = 100  # Ensure bullets render on top of everything

	EventBus.projectile_fired.emit(projectile, direction)

func get_modified_fire_rate() -> float:
	var base_rate = current_weapon_data.get("fire_rate", 1.0)
	return base_rate * fire_rate_multiplier * temp_fire_rate_multiplier

func update_weapon_data(weapon_name: String):
	current_weapon_data = BalanceDB.get_weapon_data(weapon_name)
	
	# Update visual
	if weapon_socket:
		var sprite_path = current_weapon_data.get("sprite_path", "")
		if sprite_path != "":
			var tex = load(sprite_path)
			if tex:
				weapon_socket.texture = tex
		else:
			weapon_socket.texture = null

func switch_weapon(index: int):
	if index >= 0 and index < weapons.size():
		current_weapon_index = index
		update_weapon_data(weapons[current_weapon_index])
		print("Switched to weapon: ", weapons[current_weapon_index])

func apply_powerup(powerup_data: Dictionary):
	clear_powerup()
	powerup_timer = powerup_data.get("duration", 30.0)
	if "effect" in powerup_data:
		var effect = powerup_data["effect"]
		var value = powerup_data["value"]
		match effect:
			"fire_rate_multiplier": temp_fire_rate_multiplier = value
			"damage_multiplier": temp_damage_multiplier = value
			"projectile_speed_multiplier": temp_projectile_speed_multiplier = value

func clear_powerup():
	temp_fire_rate_multiplier = 1.0
	temp_damage_multiplier = 1.0
	temp_projectile_speed_multiplier = 1.0
	powerup_timer = 0.0

func add_weapon(weapon_name: String):
	if weapon_name not in weapons:
		weapons.append(weapon_name)
		fire_timers[weapon_name] = 0.0

func remove_weapon(weapon_name: String):
	if weapon_name in weapons:
		weapons.erase(weapon_name)
		fire_timers.erase(weapon_name)