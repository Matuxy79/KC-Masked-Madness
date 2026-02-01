## Pools script. does game stuff in a simple way.
extends Node

# Pools of stuff so we don't spam new nodes.

var projectile_pool: Array[Node2D] = []
var enemy_pool: Array[Node2D] = []
var xp_gem_pool: Array[Node2D] = []
var weapon_pickup_pool: Array[Node2D] = []

var max_pool_size: int = 50

func _ready():
	print("Pools initialized")

# Projectile pooling
func get_projectile() -> Node2D:
	while projectile_pool.size() > 0:
		var projectile = projectile_pool.pop_back()
		if projectile == null or not is_instance_valid(projectile):
			continue
		projectile.visible = true
		projectile.process_mode = Node.PROCESS_MODE_INHERIT
		return projectile
	# Create new projectile if pool is empty
	return create_new_projectile()

func return_projectile(projectile: Node2D):
	if projectile_pool.size() < max_pool_size:
		detach_from_parent(projectile)
		projectile.visible = false
		projectile.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		projectile_pool.append(projectile)
	else:
		projectile.queue_free()

func create_new_projectile() -> Node2D:
	# This will be implemented when we create the Projectile scene
	var projectile = preload("res://src/scenes/Projectile.tscn").instantiate()
	return projectile

# Enemy pooling
func get_enemy() -> Node2D:
	while enemy_pool.size() > 0:
		var enemy = enemy_pool.pop_back()
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("prepare_for_spawn"):
			enemy.prepare_for_spawn()
		else:
			enemy.visible = true
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			enemy.set_process(true)
			enemy.set_physics_process(true)
		return enemy
	return create_new_enemy()

func return_enemy(enemy: Node2D):
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy_pool.size() < max_pool_size:
		if enemy.has_method("prepare_for_pool"):
			enemy.prepare_for_pool()
		else:
			enemy.visible = false
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		detach_from_parent(enemy)
		enemy_pool.append(enemy)
	else:
		enemy.queue_free()

func create_new_enemy() -> Node2D:
	var enemy = preload("res://src/scenes/Enemy.tscn").instantiate()
	return enemy

# XP Gem pooling
func get_xp_gem() -> Node2D:
	while xp_gem_pool.size() > 0:
		var gem = xp_gem_pool.pop_back()
		if gem == null or not is_instance_valid(gem):
			continue
		if gem.has_method("reset"):
			gem.reset()  # Ensure gem is reset when retrieved
		gem.visible = true
		gem.process_mode = Node.PROCESS_MODE_INHERIT
		return gem
	return create_new_xp_gem()

func return_xp_gem(gem: Node2D):
	if gem == null or not is_instance_valid(gem):
		return
	if xp_gem_pool.size() < max_pool_size:
		detach_from_parent(gem)
		if gem.has_method("reset"):
			gem.reset()  # Reset is_collected flag
		gem.visible = false
		gem.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		xp_gem_pool.append(gem)
	else:
		gem.queue_free()

func create_new_xp_gem() -> Node2D:
	var gem = preload("res://src/scenes/XPGem.tscn").instantiate()
	return gem

# Weapon pickup pooling
func get_weapon_pickup() -> Node2D:
	while weapon_pickup_pool.size() > 0:
		var pickup = weapon_pickup_pool.pop_back()
		if pickup == null or not is_instance_valid(pickup):
			continue
		if pickup.has_method("reset"):
			pickup.reset()
		pickup.visible = true
		pickup.process_mode = Node.PROCESS_MODE_INHERIT
		return pickup
	return create_new_weapon_pickup()

func return_weapon_pickup(pickup: Node2D):
	if pickup == null or not is_instance_valid(pickup):
		return
	if weapon_pickup_pool.size() < max_pool_size:
		detach_from_parent(pickup)
		if pickup.has_method("reset"):
			pickup.reset()
		pickup.visible = false
		pickup.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		weapon_pickup_pool.append(pickup)
	else:
		pickup.queue_free()

func create_new_weapon_pickup() -> Node2D:
	var pickup = preload("res://src/scenes/WeaponPickup.tscn").instantiate()
	return pickup

# Pool management
func clear_all_pools():
	for projectile in projectile_pool:
		projectile.queue_free()
	for enemy in enemy_pool:
		enemy.queue_free()
	for gem in xp_gem_pool:
		gem.queue_free()
	for pickup in weapon_pickup_pool:
		pickup.queue_free()

	projectile_pool.clear()
	enemy_pool.clear()
	xp_gem_pool.clear()
	weapon_pickup_pool.clear()

func detach_from_parent(node: Node):
	var parent = node.get_parent()
	if parent and is_instance_valid(parent) and is_instance_valid(node):
		parent.call_deferred("remove_child", node)
