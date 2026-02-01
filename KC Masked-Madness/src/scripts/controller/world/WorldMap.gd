## WorldMap - Smart spawning with 3x3 room grid and orthogonal transitions
extends Node2D
class_name WorldMap

const CHUNK_SIZE := 16  # tiles per chunk (room = chunk)
const TILE_SIZE := 16   # pixels per tile
const ROOM_SIZE := CHUNK_SIZE * TILE_SIZE  # 256 pixels per room
const GRID_RADIUS := 1  # 3x3 grid (radius 1 = center + 1 in each direction)
const DECOR_DENSITY := 0.07  # 7% of tiles get decor overlay
const HYSTERESIS := 0.1  # 10% buffer to prevent boundary jitter

var loaded_rooms: Dictionary = {}  # Vector2i -> Dictionary with "ground" and "objects" arrays
var current_room: Vector2i = Vector2i.ZERO  # Player's current room
var player: Node2D
var terrain_gen: TerrainGenerator
var initialized: bool = false

# Ground tile textures organized by biome and position
var ground_textures: Dictionary = {}

# Mixed ground tiles (array for random selection)
var mixed_ground_tiles: Array[Texture2D] = []

# Layer containers
var ground_layer: Node2D
var object_layer: Node2D  # Renamed from decor_layer for clarity

# Decor position registry for enemy claiming
var decor_positions: Dictionary = {}  # Vector2 -> bool (true = available, false = claimed)

# Object spawning weights (BSP room generation)
# Names must match folder names or special-effects-objects file names
const OBJECT_SPAWN_WEIGHTS = {
	"tree": 30,
	"hard-lamp": 8,
	"single-blockers": 15,
	"fence-build": 12,
	"chainlink-fence-build": 8,
	# Special objects (from special-effects-objects folder)
	"explode-barrel": 5,
	"toxic-barrel": 5,
	"common-chest": 8,
	"golden-chest": 3,
	"health-crate": 6,
}

func _ready():
	add_to_group("world_map")  # So enemies can find us
	print("WorldMap initialized - Room size: ", ROOM_SIZE, "px, Grid: ", (GRID_RADIUS * 2 + 1), "x", (GRID_RADIUS * 2 + 1))
	setup_layers()
	setup_terrain_generator()
	load_ground_textures()
	load_mixed_ground_tiles()
	# load_decor_tiles removed - using ObjectBuilder
	find_player()

func setup_layers():
	ground_layer = Node2D.new()
	ground_layer.z_index = -10
	ground_layer.name = "GroundLayer"
	add_child(ground_layer)

	object_layer = Node2D.new()
	object_layer.z_index = -5 # Objects layer, above ground
	object_layer.name = "ObjectLayer"
	# Ensure YSort if needed, but for now simple Z-index
	add_child(object_layer)

func setup_terrain_generator():
	terrain_gen = TerrainGenerator.new()
	add_child(terrain_gen)

func load_ground_textures():
	var base_path = "res://assets/asset-pcg-core/ground layer/"

	# Arid desert (only has left, middle, right)
	ground_textures["arid_desert_middle"] = load(base_path + "arid desert/middle.png")
	ground_textures["arid_desert_left"] = load(base_path + "arid desert/left.png")
	ground_textures["arid_desert_right"] = load(base_path + "arid desert/right.png")

	# Green lush (full 9-grid)
	for pos in ["top-left", "top-middle", "top-right", "middle-left", "middle-middle", "middle-right", "bottom-left", "bottom-middle", "bottom-right"]:
		ground_textures["green_lush_" + pos] = load(base_path + "green lush/" + pos + ".png")

	# Purple bloom (full 9-grid)
	for pos in ["top-left", "top-middle", "top-right", "middle-left", "middle-middle", "middle-right", "bottom-left", "bottom-middle", "bottom-right"]:
		ground_textures["purple_bloom_" + pos] = load(base_path + "purple bloom/" + pos + ".png")

	print("Loaded ", ground_textures.size(), " ground textures")

func load_mixed_ground_tiles():
	var base_path = "res://assets/asset-pcg-core/ground layer/mixed ground/"
	var tile_ids = ["0059", "0060", "0061", "0090", "0091", "0092", "0093", "0094", "0095", "0097", "0098", "0099", "0113", "0114", "0115", "0116"]
	for tile_id in tile_ids:
		var texture = load(base_path + "tile_" + tile_id + ".png")
		if texture:
			mixed_ground_tiles.append(texture)
	print("Loaded ", mixed_ground_tiles.size(), " mixed ground tiles")

func _process(_delta):
	if not player or not is_instance_valid(player):
		find_player()
		return
	update_rooms()

func update_rooms():
	var new_room = world_to_room(player.global_position)

	# First time initialization - load full 3x3 grid
	if not initialized:
		current_room = new_room
		load_full_grid(current_room)
		initialized = true
		print("WorldMap initialized at room: ", current_room)
		return

	# Check if player crossed room boundary (with hysteresis)
	if not should_change_room(new_room):
		return

	# Calculate movement delta
	var delta = new_room - current_room
	var dx = delta.x
	var dy = delta.y

	# Orthogonal movement (1 room in cardinal direction)
	if abs(dx) + abs(dy) == 1:
		shift_grid(dx, dy)
	# Diagonal or teleport - rebuild full grid
	elif dx != 0 or dy != 0:
		rebuild_grid(new_room)

	current_room = new_room

# Hysteresis check - only change room when clearly past boundary
func should_change_room(new_room: Vector2i) -> bool:
	if new_room == current_room:
		return false

	# Calculate how far into the new room the player is
	var room_center = Vector2(current_room) * ROOM_SIZE + Vector2(ROOM_SIZE / 2, ROOM_SIZE / 2)
	var player_offset = player.global_position - room_center

	# Only switch if player is beyond center + hysteresis buffer
	var threshold = ROOM_SIZE * (0.5 + HYSTERESIS)
	return abs(player_offset.x) > threshold or abs(player_offset.y) > threshold

# Load full 3x3 grid around a room
func load_full_grid(center: Vector2i):
	for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var room_pos = center + Vector2i(x, y)
			if not loaded_rooms.has(room_pos):
				load_room(room_pos)
	print("Loaded full 3x3 grid around room: ", center, " (", loaded_rooms.size(), " rooms)")

# Rebuild entire grid (for teleport/diagonal movement)
func rebuild_grid(new_center: Vector2i):
	# Unload all rooms
	var rooms_to_unload = loaded_rooms.keys().duplicate()
	for room_pos in rooms_to_unload:
		unload_room(room_pos)

	# Load new grid
	load_full_grid(new_center)
	print("Rebuilt grid at room: ", new_center)

# Shift grid orthogonally - despawn far edge, spawn new edge
func shift_grid(dx: int, dy: int):
	if dx == 1:  # Moved east
		# Despawn west column
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			unload_room(Vector2i(current_room.x - GRID_RADIUS, current_room.y + y))
		# Spawn east column
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			load_room(Vector2i(current_room.x + GRID_RADIUS + 1, current_room.y + y))

	elif dx == -1:  # Moved west
		# Despawn east column
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			unload_room(Vector2i(current_room.x + GRID_RADIUS, current_room.y + y))
		# Spawn west column
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			load_room(Vector2i(current_room.x - GRID_RADIUS - 1, current_room.y + y))

	elif dy == 1:  # Moved south
		# Despawn north row
		for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			unload_room(Vector2i(current_room.x + x, current_room.y - GRID_RADIUS))
		# Spawn south row
		for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			load_room(Vector2i(current_room.x + x, current_room.y + GRID_RADIUS + 1))

	elif dy == -1:  # Moved north
		# Despawn south row
		for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			unload_room(Vector2i(current_room.x + x, current_room.y + GRID_RADIUS))
		# Spawn north row
		for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			load_room(Vector2i(current_room.x + x, current_room.y - GRID_RADIUS - 1))

# Convert world position to room coordinates
func world_to_room(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ROOM_SIZE)),
		int(floor(world_pos.y / ROOM_SIZE))
	)

func load_room(room_pos: Vector2i):
	if loaded_rooms.has(room_pos):
		return  # Already loaded

	var base_tile = room_pos * CHUNK_SIZE
	var ground_sprites: Array[Sprite2D] = []
	var room_objects: Array[Node2D] = []

	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var tile_pos = base_tile + Vector2i(x, y)
			var world_pos = Vector2(tile_pos) * TILE_SIZE
			var sprite_pos = world_pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

			# Get biome and position from terrain generator
			var terrain_data = terrain_gen.get_biome_and_position(tile_pos, TILE_SIZE)
			var biome_name = terrain_data["biome_name"]
			var position_name = terrain_data["position"]

			# Get texture based on biome type
			var texture: Texture2D = null

			if biome_name == "mixed_ground":
				# Random tile from mixed ground array (deterministic)
				texture = get_mixed_ground_tile(tile_pos)
			else:
				# Get texture key for other biomes
				var texture_key = get_texture_key(biome_name, position_name)
				texture = ground_textures.get(texture_key)

			if texture:
				var sprite = Sprite2D.new()
				sprite.texture = texture
				sprite.position = sprite_pos
				ground_layer.add_child(sprite)
				ground_sprites.append(sprite)

	# Spawn objects (replacing decor)
	spawn_room_objects(room_pos, room_objects)

	loaded_rooms[room_pos] = {"ground": ground_sprites, "objects": room_objects}

# Better hash with good distribution for random placement
func hash_tile(tile_x: int, tile_y: int, salt: int = 0) -> int:
	var seed_val = terrain_gen.world_seed if terrain_gen else 0
	# Use a better mixing function for uniform distribution
	var h = seed_val
	h = h ^ (tile_x * 374761393)
	h = h ^ (tile_y * 668265263)
	h = h ^ (salt * 1274126177)
	h = h ^ (h >> 13)
	h = h * 1597334677
	h = h ^ (h >> 12)
	return abs(h)

func get_mixed_ground_tile(tile_pos: Vector2i) -> Texture2D:
	if mixed_ground_tiles.is_empty():
		return null
	var hash_val = hash_tile(tile_pos.x, tile_pos.y, 1)
	var index = hash_val % mixed_ground_tiles.size()
	return mixed_ground_tiles[index]

func get_texture_key(biome_name: String, position_name: String) -> String:
	# Arid desert only has left/middle/right, map 9-grid to 3
	if biome_name == "arid_desert":
		if position_name.ends_with("left"):
			return "arid_desert_left"
		elif position_name.ends_with("right"):
			return "arid_desert_right"
		else:
			return "arid_desert_middle"

	# Green lush and purple bloom have full 9-grid
	return biome_name + "_" + position_name

func unload_room(room_pos: Vector2i):
	if not loaded_rooms.has(room_pos):
		return  # Not loaded

	var room_data = loaded_rooms[room_pos]

	# Free ground sprites
	if room_data.has("ground"):
		for sprite in room_data["ground"]:
			if sprite and is_instance_valid(sprite):
				sprite.queue_free()

	# Free objects and unregister positions
	if room_data.has("objects"):
		for obj in room_data["objects"]:
			if obj and is_instance_valid(obj):
				if obj.has_node("DecorAnchor"):
					unregister_decor_position(obj.get_node("DecorAnchor").global_position)
				obj.queue_free()

	loaded_rooms.erase(room_pos)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func get_loaded_room_count() -> int:
	return loaded_rooms.size()

func get_current_room() -> Vector2i:
	return current_room

# ===== OBJECT SPAWNING =====

func spawn_room_objects(chunk_pos: Vector2i, room_objects: Array[Node2D]):
	# Use chunk coordinates to seed random number generator
	var room_seed = terrain_gen.hash_chunk(chunk_pos.x, chunk_pos.y)
	
	# Create a temporary local RNG instance for determinism
	var rng = RandomNumberGenerator.new()
	rng.seed = room_seed
	
	# Get room bounds in world coordinates
	var room_world_pos = Vector2(chunk_pos) * ROOM_SIZE
	var room_rect = Rect2(room_world_pos, Vector2(ROOM_SIZE, ROOM_SIZE))
	
	# Spawn random objects
	var num_objects = rng.randi_range(3, 8)
	
	for i in range(num_objects):
		var object_type = weighted_random_object(rng)
		var position = get_random_room_position(room_rect, rng)
		
		var obj = spawn_object(object_type, position)
		if obj:
			room_objects.append(obj)
	
	# Always spawn 1 special object per 5 rooms
	if room_seed % 5 == 0:
		var special_types = ["explode-barrel", "golden-chest", "warp-star", "locked-crate"]
		var object_type = special_types[rng.randi() % special_types.size()]
		var position = get_random_room_position(room_rect, rng)
		var obj = spawn_object(object_type, position)
		if obj:
			room_objects.append(obj)

func weighted_random_object(rng: RandomNumberGenerator) -> String:
	var total_weight = 0
	for weight in OBJECT_SPAWN_WEIGHTS.values():
		total_weight += weight
	
	var roll = rng.randi_range(0, total_weight - 1)
	var current = 0
	
	for object_type in OBJECT_SPAWN_WEIGHTS.keys():
		current += OBJECT_SPAWN_WEIGHTS[object_type]
		if roll < current:
			return object_type
	
	return "tree"  # Fallback

func spawn_object(object_type: String, position: Vector2) -> Node2D:
	var obj = ObjectBuilder.build_object(object_type)
	if not obj:
		return null
	
	obj.position = position
	obj.z_index = 0 # Relative to ObjectLayer
	
	object_layer.add_child(obj)
	
	# Register anchor for enemies
	if obj.has_node("DecorAnchor"):
		# Use deferred because global_position might not be ready if not in tree? 
		# It is in tree (add_child called).
		# We register the global position of the anchor node.
		# But since we just added it, position is local.
		# obj.position is set relative to object_layer.
		# object_layer is at (0,0) world usually.
		register_decor_position(obj.position) 
	
	return obj

func get_random_room_position(room_rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	# Avoid edges (leave 32px border)
	var margin = 32
	var x = rng.randf_range(room_rect.position.x + margin, room_rect.end.x - margin)
	var y = rng.randf_range(room_rect.position.y + margin, room_rect.end.y - margin)
	return Vector2(x, y)

# ===== DECOR REGISTRY FOR ENEMY CLAIMING =====

func register_decor_position(world_pos: Vector2):
	decor_positions[world_pos] = true  # true = available

func unregister_decor_position(world_pos: Vector2):
	decor_positions.erase(world_pos)

func claim_decor(world_pos: Vector2) -> bool:
	if decor_positions.has(world_pos) and decor_positions[world_pos]:
		decor_positions[world_pos] = false  # false = claimed
		return true
	return false

func release_decor(world_pos: Vector2):
	if decor_positions.has(world_pos):
		decor_positions[world_pos] = true  # true = available again

func get_available_decor_positions() -> Array[Vector2]:
	var available: Array[Vector2] = []
	for pos in decor_positions.keys():
		if decor_positions[pos]:
			available.append(pos)
	return available

func get_nearest_available_decor(from_pos: Vector2) -> Vector2:
	var available = get_available_decor_positions()
	if available.is_empty():
		return Vector2.INF  # No decor available

	var nearest = available[0]
	var nearest_dist = from_pos.distance_squared_to(nearest)

	for pos in available:
		var dist = from_pos.distance_squared_to(pos)
		if dist < nearest_dist:
			nearest = pos
			nearest_dist = dist

	return nearest

func get_decor_count() -> int:
	return decor_positions.size()

func get_available_decor_count() -> int:
	var count = 0
	for available in decor_positions.values():
		if available:
			count += 1
	return count
