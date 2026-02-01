extends StaticBody2D
class_name Chest

# Chest that can be shot to open and drop a random weapon
# Extends StaticBody2D so projectiles can hit it

var is_open = false
var loot_tier = "common"  # "common" or "golden"
var health = 3  # Hits to open

# Weapon drop pools by tier
const COMMON_WEAPONS = ["pistol", "revolver", "smg", "shotgun"]
const GOLDEN_WEAPONS = ["assault_rifle", "sniper_rifle", "minigun", "laser", "rocket_launcher"]

func _ready():
	add_to_group("interactables")
	add_to_group("destructible")

	# Determine tier from name
	if name.contains("golden"):
		loot_tier = "golden"
		health = 5

func take_damage(amount: int = 1):
	if is_open:
		return

	health -= amount

	# Flash effect
	modulate = Color(2, 2, 2)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if health <= 0:
		open_chest()

func open_chest():
	if is_open:
		return

	is_open = true

	# Swap to open texture
	var sprite = get_node_or_null("Sprite_R1_C1")
	if not sprite:
		for child in get_children():
			if child is Sprite2D:
				sprite = child
				break

	if sprite:
		var open_tex_path = ""
		if loot_tier == "golden":
			open_tex_path = "res://assets/sprites/ui/objects/special-effects-objects/golden-chest-open.png"
		else:
			open_tex_path = "res://assets/sprites/ui/objects/special-effects-objects/common-chest-open.png"

		var open_tex = load(open_tex_path)
		if open_tex:
			sprite.texture = open_tex

	# Spawn weapon pickup
	spawn_weapon_drop()

	# Emit event
	EventBus.chest_opened.emit(global_position, loot_tier)

func spawn_weapon_drop():
	var weapon_pool = COMMON_WEAPONS if loot_tier == "common" else GOLDEN_WEAPONS
	var weapon_name = weapon_pool[randi() % weapon_pool.size()]

	# Create weapon pickup
	var pickup = Area2D.new()
	pickup.name = "WeaponPickup_" + weapon_name
	pickup.add_to_group("weapon_pickups")
	pickup.collision_layer = 0
	pickup.collision_mask = 2  # Player layer

	# Add sprite
	var sprite = Sprite2D.new()
	var weapon_data = BalanceDB.get_weapon_data(weapon_name)
	var sprite_path = weapon_data.get("sprite_path", "res://assets/sprites/Weapons/pistol-starter.png")
	sprite.texture = load(sprite_path)
	sprite.scale = Vector2(0.8, 0.8)
	pickup.add_child(sprite)

	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	pickup.add_child(collision)

	# Store weapon name
	pickup.set_meta("weapon_name", weapon_name)

	# Connect pickup signal
	pickup.body_entered.connect(_on_weapon_pickup_body_entered.bind(pickup, weapon_name))

	# Add to scene
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(0, -8)
	pickup.z_index = 50

	# Add float animation
	var float_tween = pickup.create_tween().set_loops()
	float_tween.tween_property(pickup, "position:y", pickup.position.y - 4, 0.5).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(pickup, "position:y", pickup.position.y + 4, 0.5).set_trans(Tween.TRANS_SINE)

func _on_weapon_pickup_body_entered(body: Node2D, pickup: Area2D, weapon_name: String):
	if body.is_in_group("player"):
		# Give weapon to player
		var player = body
		if player.weapon_manager:
			player.weapon_manager.add_weapon(weapon_name)
			player.weapon_manager.switch_weapon(player.weapon_manager.weapons.size() - 1)
			print("Player picked up: ", weapon_name)

		EventBus.item_picked_up.emit(weapon_name, pickup.global_position)
		pickup.queue_free()

func interact():
	# For non-projectile interaction (e.g., pressing E)
	take_damage(health)
