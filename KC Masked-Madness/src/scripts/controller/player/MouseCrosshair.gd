extends Sprite2D
class_name MouseCrosshair

# Crosshair that follows the mouse position
# Must be a child of a CanvasLayer to stay on screen

func _ready():
	# Hide default cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	z_index = 200  # Always on top

func _process(_delta):
	# Follow mouse position (in viewport coordinates for CanvasLayer)
	global_position = get_global_mouse_position()

func _exit_tree():
	# Restore default cursor when removed
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
