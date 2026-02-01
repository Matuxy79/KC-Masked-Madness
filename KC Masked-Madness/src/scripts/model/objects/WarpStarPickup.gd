extends Area2D
class_name WarpStarPickup

func _ready():
	add_to_group("pickups")
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		# Give player warp star
		if body.has_method("pickup_warp_star"):
			body.pickup_warp_star()
		
		EventBus.item_picked_up.emit("warp_star", global_position)
		queue_free()
