extends StaticBody2D
class_name Fence

# Fence with per-segment collision - segments can be destroyed to create openings

var segments: Dictionary = {} # "row_col" -> { sprite: Sprite2D, collision: CollisionShape2D }
var tile_size: Vector2 = Vector2(16, 16)

func _ready():
	add_to_group("objects")
	add_to_group("fences")
	add_to_group("destructible")

	# Get tile_size from meta if set by ObjectBuilder
	if has_meta("tile_size"):
		tile_size = get_meta("tile_size")

	# Auto-register segments from children created by ObjectBuilder
	_register_existing_segments()

func _register_existing_segments():
	# Find all sprite/collision pairs created by ObjectBuilder
	var regex = RegEx.new()
	regex.compile("_R(\\d+)_C(\\d+)")

	for child in get_children():
		if child is Sprite2D:
			var result = regex.search(child.name)
			if result:
				var row = int(result.get_string(1))
				var col = int(result.get_string(2))
				var collision_name = "Collision_R%d_C%d" % [row, col]
				var collision = get_node_or_null(collision_name)
				if collision:
					setup_segment(row, col, child, collision)

func setup_segment(row: int, col: int, sprite: Sprite2D, collision: CollisionShape2D):
	var key = "%d_%d" % [row, col]
	segments[key] = {
		"sprite": sprite,
		"collision": collision,
		"row": row,
		"col": col
	}

func remove_segment(row: int, col: int) -> bool:
	var key = "%d_%d" % [row, col]
	if not segments.has(key):
		return false

	var segment = segments[key]
	if segment.sprite and is_instance_valid(segment.sprite):
		segment.sprite.queue_free()
	if segment.collision and is_instance_valid(segment.collision):
		segment.collision.queue_free()

	segments.erase(key)

	# Emit event for potential effects
	EventBus.fence_segment_destroyed.emit(global_position, row, col)

	return true

func remove_segment_at_world_pos(world_pos: Vector2) -> bool:
	# Convert world position to segment row/col
	var local_pos = world_pos - global_position
	var col = int(floor(local_pos.x / tile_size.x)) + 1
	var row = int(floor(local_pos.y / tile_size.y)) + 1
	return remove_segment(row, col)

func get_segment_count() -> int:
	return segments.size()

func is_empty() -> bool:
	return segments.is_empty()

func take_damage_at(world_pos: Vector2, _amount: int = 1):
	# For destructible interface - remove the hit segment
	remove_segment_at_world_pos(world_pos)

	# If all segments gone, remove the whole fence
	if is_empty():
		queue_free()
