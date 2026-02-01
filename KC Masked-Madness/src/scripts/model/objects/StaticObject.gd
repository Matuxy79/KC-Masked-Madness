extends StaticBody2D
class_name StaticObject

# Basic static object that might just block movement
# or have simple interactions

func _ready():
	add_to_group("objects")
