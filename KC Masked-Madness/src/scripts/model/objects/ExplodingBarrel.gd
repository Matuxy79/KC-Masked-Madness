extends StaticBody2D
class_name ExplodingBarrel

signal died

const EXPLOSION_RADIUS = 128.0
const EXPLOSION_DAMAGE = 50

var max_health = 20
var current_health = 20

func _ready():
	add_to_group("objects")
	add_to_group("destructible")

func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		explode()

func explode():
	# Damage enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(EXPLOSION_DAMAGE)
	
	# Emit event for BSP room reshape
	# Calculate room position (assuming WorldMap chunk size logic matches)
	# Default 16 tiles * 16 pixels = 256
	var room_size = 256
	var room_pos = Vector2i(floor(global_position.x / room_size), floor(global_position.y / room_size))
	
	EventBus.barrel_exploded.emit(global_position, room_pos)
	
	print("Barrel exploded at ", global_position)
	queue_free()
