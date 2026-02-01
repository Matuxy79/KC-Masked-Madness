## Minimap - Shows map overview with player and enemies
extends Control
class_name Minimap

# Minimap size and position
@export var map_size: Vector2 = Vector2(150, 150)
@export var margin: Vector2 = Vector2(10, 10)
@export var border_width: float = 2.0

# Colors
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.7)
@export var border_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var player_color: Color = Color(0.0, 0.8, 0.0, 1.0)
@export var enemy_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var map_bounds_color: Color = Color(0.2, 0.2, 0.2, 0.5)

# References
var player: Node2D
var world_map: Node2D

# Map view settings
var map_view_size: float = 1000.0  # How much of the world to show (in pixels)
var zoom_scale: float = 1.0

func _ready():
	# Position in top right corner
	position = Vector2(
		get_viewport().get_visible_rect().size.x - map_size.x - margin.x,
		margin.y
	)
	custom_minimum_size = map_size
	size = map_size
	
	# Setup references
	call_deferred("_setup_references")

func _setup_references():
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Find world map
	world_map = get_tree().get_first_node_in_group("world_map")
	
	if not player:
		push_warning("Minimap: Player not found!")
	if not world_map:
		push_warning("Minimap: WorldMap not found!")

func _process(_delta):
	queue_redraw()

func _draw():
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)
	
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, map_size), border_color, false, border_width)
	
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Calculate zoom scale based on view size
	zoom_scale = map_size.x / map_view_size
	
	# Draw visible area bounds (grid)
	_draw_grid(player_pos)
	
	# Draw enemies
	_draw_enemies(player_pos)
	
	# Draw player (always in center)
	var center = map_size / 2.0
	draw_circle(center, 4.0, player_color)
	
	# Draw player direction indicator
	var player_rotation = player.rotation if player else 0.0
	var direction = Vector2.RIGHT.rotated(player_rotation) * 6.0
	draw_line(center, center + direction, player_color, 2.0)

func _draw_grid(player_pos: Vector2):
	# Draw a subtle grid to show map structure
	var grid_size = 256.0  # Room size
	var grid_scale = grid_size * zoom_scale
	
	# Calculate how many grid lines to draw
	var grid_count = int(map_size.x / grid_scale) + 2
	
	# Offset based on player position
	var offset = Vector2(
		fmod(player_pos.x * zoom_scale, grid_scale),
		fmod(player_pos.y * zoom_scale, grid_scale)
	)
	
	var center = map_size / 2.0
	
	# Draw vertical lines
	for i in range(-grid_count, grid_count + 1):
		var x = center.x + (i * grid_scale) - offset.x
		if x >= 0 and x <= map_size.x:
			draw_line(Vector2(x, 0), Vector2(x, map_size.y), map_bounds_color, 1.0)
	
	# Draw horizontal lines
	for i in range(-grid_count, grid_count + 1):
		var y = center.y + (i * grid_scale) - offset.y
		if y >= 0 and y <= map_size.y:
			draw_line(Vector2(0, y), Vector2(map_size.x, y), map_bounds_color, 1.0)

func _draw_enemies(player_pos: Vector2):
	# Get all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	var center = map_size / 2.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Calculate relative position
		var relative_pos = enemy.global_position - player_pos
		
		# Scale to minimap
		var minimap_pos = center + (relative_pos * zoom_scale)
		
		# Only draw if within minimap bounds (with some margin)
		if minimap_pos.x >= -5 and minimap_pos.x <= map_size.x + 5 and \
		   minimap_pos.y >= -5 and minimap_pos.y <= map_size.y + 5:
			# Draw enemy dot
			draw_circle(minimap_pos, 3.0, enemy_color)

func set_zoom(new_view_size: float):
	map_view_size = new_view_size
