## WeaponPickup - Dropped weapon that player can walk over to collect
extends Area2D
class_name WeaponPickup

var weapon_name: String = "pistol"
var _is_collected: bool = false
var float_tween: Tween

func _ready():
	add_to_group("weapon_pickups")
	body_entered.connect(_on_body_entered)

func setup(w_name: String):
	weapon_name = w_name
	_is_collected = false
	visible = true

	# Load sprite from weapons.json
	var weapon_data = BalanceDB.get_weapon_data(weapon_name)
	var sprite = get_node_or_null("Sprite2D")
	if sprite and weapon_data.has("sprite_path"):
		var tex = load(weapon_data.get("sprite_path"))
		if tex:
			sprite.texture = tex

	# Add float animation like Chest pickups
	start_float_animation()

func _on_body_entered(body: Node2D):
	if _is_collected:
		return
	if body.is_in_group("player"):
		collect(body)

func collect(player: Node2D):
	_is_collected = true
	stop_float_animation()

	# Replace player's weapon (single weapon system)
	if player.weapon_manager:
		var new_weapons: Array[String] = [weapon_name]
		player.weapon_manager.weapons = new_weapons
		player.weapon_manager.current_weapon_index = 0
		player.weapon_manager.setup_weapons()
		player.weapon_manager.update_weapon_data(weapon_name)
		print("[WeaponPickup] Player picked up: ", weapon_name)

	EventBus.item_picked_up.emit(weapon_name, global_position)
	Pools.return_weapon_pickup(self)

func reset():
	_is_collected = false
	visible = true
	weapon_name = "pistol"
	stop_float_animation()

func is_collected() -> bool:
	return _is_collected

func start_float_animation():
	stop_float_animation()
	var base_y = position.y
	float_tween = create_tween().set_loops()
	float_tween.tween_property(self, "position:y", base_y - 4, 0.5).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(self, "position:y", base_y + 4, 0.5).set_trans(Tween.TRANS_SINE)

func stop_float_animation():
	if float_tween and float_tween.is_valid():
		float_tween.kill()
		float_tween = null
