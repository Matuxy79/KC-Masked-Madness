extends StaticBody2D
class_name WarpDoor

var is_open = false

func _ready():
	add_to_group("warp_doors")
	EventBus.warp_star_used.connect(_on_warp_star_used)

func _on_warp_star_used(target_door: Node):
	if target_door == self:
		open_door()

func open_door():
	is_open = true
	var open_tex = get_meta("open_texture", null)
	if open_tex:
		for child in get_children():
			if child is Sprite2D:
				child.texture = open_tex
				break
	
	print("Door opened!")
	
	# Close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	close_door()

func close_door():
	is_open = false
	var closed_tex = get_meta("closed_texture", null)
	if closed_tex:
		for child in get_children():
			if child is Sprite2D:
				child.texture = closed_tex
				break
	print("Door closed.")

func teleport_player_here(player: Node2D):
	player.global_position = global_position + Vector2(8, 8)  # Center on door
