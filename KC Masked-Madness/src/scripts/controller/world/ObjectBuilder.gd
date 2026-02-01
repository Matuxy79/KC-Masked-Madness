extends Node

# ObjectBuilder.gd
# Dynamically builds objects from assets/sprites/ui/objects/
# Handles: multi-sprite folders (tree, fence), single sprites, and special objects

const OBJECTS_PATH = "res://assets/sprites/ui/objects/"
const SPECIAL_PATH = "res://assets/sprites/ui/objects/special-effects-objects/"

var object_registry = {} # Dictionary<String, PackedScene>

func _ready():
	scan_and_build_all()

func get_object(object_name: String) -> PackedScene:
	return object_registry.get(object_name)

func build_object(object_name: String) -> Node2D:
	var scene = object_registry.get(object_name)
	if scene:
		return scene.instantiate()
	push_warning("ObjectBuilder: Unknown object type: " + object_name)
	return null

func scan_and_build_all():
	print("ObjectBuilder: Starting scan...")

	# 1. Scan top-level object folders (tree, fence-build, etc.)
	scan_top_level_folders()

	# 2. Scan special-effects-objects for individual items and subfolders
	scan_special_objects()

	print("ObjectBuilder: Scan complete. Total objects: ", object_registry.size())
	for key in object_registry.keys():
		print("  - ", key)

func scan_top_level_folders():
	var dir = DirAccess.open(OBJECTS_PATH)
	if not dir:
		push_error("ObjectBuilder: Cannot open " + OBJECTS_PATH)
		return

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			# Skip special-effects-objects - handled separately
			if folder_name != "special-effects-objects":
				var scene = build_from_folder(OBJECTS_PATH + folder_name)
				if scene:
					object_registry[folder_name] = scene
					print("ObjectBuilder: Built folder object: ", folder_name)
		folder_name = dir.get_next()
	dir.list_dir_end()

func scan_special_objects():
	var dir = DirAccess.open(SPECIAL_PATH)
	if not dir:
		push_warning("ObjectBuilder: Cannot open " + SPECIAL_PATH)
		return

	dir.list_dir_begin()
	var item_name = dir.get_next()
	while item_name != "":
		if item_name.begins_with("."):
			item_name = dir.get_next()
			continue

		var full_path = SPECIAL_PATH + item_name

		if dir.current_is_dir():
			# Subfolder (warp-star, locked-crate)
			var scene = build_from_folder(full_path)
			if scene:
				object_registry[item_name] = scene
				print("ObjectBuilder: Built special folder: ", item_name)
		elif item_name.ends_with(".png") and not item_name.ends_with(".import"):
			# Individual PNG file
			var obj_name = item_name.get_basename() # Remove .png
			var scene = build_single_sprite(full_path, obj_name)
			if scene:
				object_registry[obj_name] = scene
				print("ObjectBuilder: Built special single: ", obj_name)

		item_name = dir.get_next()
	dir.list_dir_end()

func build_from_folder(folder_path: String) -> PackedScene:
	var parts = parse_folder_sprites(folder_path)
	if parts.is_empty():
		return null

	var folder_name = folder_path.get_file()
	var dimensions = detect_dimensions(parts)
	var tile_size = parts[0].texture.get_size()
	var structure_type = classify_structure(dimensions)
	var script = select_script(folder_name)
	var use_per_segment_collision = is_fence(folder_name)

	# Create root node
	var root: Node2D
	if script and script.get_instance_base_type() == "Area2D":
		root = Area2D.new()
	else:
		root = StaticBody2D.new()

	root.name = folder_name
	if script:
		root.set_script(script)
	root.collision_layer = 4
	root.collision_mask = 0

	# Store tile_size for Fence script
	if use_per_segment_collision:
		root.set_meta("tile_size", tile_size)

	# Add sprites and collisions
	for part in parts:
		var sprite = Sprite2D.new()
		sprite.texture = part.texture
		sprite.name = "Sprite_R%d_C%d" % [part.row, part.col]
		sprite.centered = true
		sprite.position = calculate_position(part.row, part.col, tile_size)
		root.add_child(sprite)
		sprite.owner = root

		# Per-segment collision for fences
		if use_per_segment_collision:
			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = tile_size * 0.9
			collision.shape = shape
			collision.position = sprite.position
			collision.name = "Collision_R%d_C%d" % [part.row, part.col]
			root.add_child(collision)
			collision.owner = root

	# Single collision for non-fences
	if not use_per_segment_collision:
		var collision = generate_collision(structure_type, dimensions, tile_size)
		if collision:
			collision.name = "CollisionShape2D"
			root.add_child(collision)
			collision.owner = root

	# Pack and return
	var scene = PackedScene.new()
	if scene.pack(root) == OK:
		return scene
	return null

func build_single_sprite(file_path: String, obj_name: String) -> PackedScene:
	var texture = load(file_path)
	if not texture:
		return null

	var script = select_script(obj_name)

	var root: Node2D
	if script and script.get_instance_base_type() == "Area2D":
		root = Area2D.new()
	else:
		root = StaticBody2D.new()

	root.name = obj_name
	if script:
		root.set_script(script)
	root.collision_layer = 4
	root.collision_mask = 0

	# Add sprite
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.name = "Sprite"
	sprite.centered = true
	root.add_child(sprite)
	sprite.owner = root

	# Add collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var tex_size = texture.get_size()
	shape.size = tex_size * 0.8
	collision.shape = shape
	collision.name = "CollisionShape2D"
	root.add_child(collision)
	collision.owner = root

	# Pack and return
	var scene = PackedScene.new()
	if scene.pack(root) == OK:
		return scene
	return null

func parse_folder_sprites(path: String) -> Array:
	var parts = []
	var dir = DirAccess.open(path)
	if not dir:
		return parts

	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png") and not file.ends_with(".import"):
			var tex = load(path.path_join(file))
			if tex:
				var info = extract_grid_info(file)
				parts.append({
					"texture": tex,
					"row": info.row,
					"col": info.col,
					"name": file
				})
		file = dir.get_next()
	dir.list_dir_end()
	return parts

func extract_grid_info(filename: String) -> Dictionary:
	var regex = RegEx.new()
	regex.compile("row(\\d+)-col(\\d+)")
	var result = regex.search(filename)
	if result:
		return {"row": int(result.get_string(1)), "col": int(result.get_string(2))}
	return {"row": 1, "col": 1}

func detect_dimensions(parts: Array) -> Dictionary:
	var max_r = 0
	var max_c = 0
	for p in parts:
		if p.row > max_r: max_r = p.row
		if p.col > max_c: max_c = p.col
	return {"rows": max_r, "cols": max_c}

func classify_structure(dims: Dictionary) -> String:
	if dims.rows == 1 and dims.cols == 1:
		return "Single"
	elif dims.rows > 1 and dims.cols == 1:
		return "Vertical"
	elif dims.rows == 1 and dims.cols > 1:
		return "Horizontal"
	return "Grid"

func select_script(obj_name: String) -> Script:
	if obj_name.contains("fence"):
		return load("res://src/scripts/model/objects/Fence.gd")
	if obj_name.contains("chest"):
		return load("res://src/scripts/model/objects/Chest.gd")
	if obj_name.contains("explode") or obj_name.contains("barrel"):
		return load("res://src/scripts/model/objects/ExplodingBarrel.gd")
	if obj_name.contains("warp") and obj_name.contains("door"):
		return load("res://src/scripts/model/objects/WarpDoor.gd")
	if obj_name.contains("warp") or obj_name.contains("star"):
		return load("res://src/scripts/model/objects/WarpStarPickup.gd")
	return load("res://src/scripts/model/objects/StaticObject.gd")

func is_fence(obj_name: String) -> bool:
	return obj_name.contains("fence")

func calculate_position(row: int, col: int, size: Vector2) -> Vector2:
	var x = (col - 1) * size.x + (size.x * 0.5)
	var y = (row - 1) * size.y + (size.y * 0.5)
	return Vector2(x, y)

func generate_collision(type: String, dims: Dictionary, tile_size: Vector2) -> CollisionShape2D:
	var node = CollisionShape2D.new()
	var shape = RectangleShape2D.new()

	var total_w = dims.cols * tile_size.x
	var total_h = dims.rows * tile_size.y

	match type:
		"Vertical":
			# Collide only the bottom tile for trees/lamps
			shape.size = Vector2(tile_size.x * 0.8, tile_size.y * 0.8)
			var center_x = total_w * 0.5
			var center_y = (dims.rows - 1) * tile_size.y + (tile_size.y * 0.5)
			node.position = Vector2(center_x, center_y)
		_:
			shape.size = Vector2(total_w * 0.9, total_h * 0.9)
			node.position = Vector2(total_w * 0.5, total_h * 0.5)

	node.shape = shape
	return node
