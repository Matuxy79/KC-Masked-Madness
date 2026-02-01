## Projectile script. does game stuff in a simple way.
extends Area2D
class_name Projectile

# Projectile - Individual projectile with damage and movement
# Handles collision detection and damage dealing

@export var damage: int = 10
@export var speed: float = 300.0
@export var max_range: float = 200.0
@export var pierce_count: int = 0
@export var base_radius: float = 4.0
@export var target_group: String = "enemies"

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var current_pierce: int = 0
var radius_multiplier: float = 1.0
var explosive_radius: float = 0.0
var knockback_force: float = 0.0

func _ready():
	# Ensure bullets render above everything (Ground=-10, Objects=-5, Enemies=-8, Player=0)
	z_index = 100
	
	# Use the CollisionShape2D defined in the scene and ensure collisions are enabled.
	var collision_shape: CollisionShape2D = $CollisionShape2D
	if collision_shape == null:
		push_error("Projectile is missing CollisionShape2D child")
	
	# Detect everything
	collision_layer = 0
	collision_mask = 0xFFFF # Detect everything for simple logic
	
	# Connect signals once.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Move projectile
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()
	
	# Check if projectile has traveled max range
	if distance_traveled >= max_range:
		destroy()

func setup(projectile_damage: int, projectile_speed: float, projectile_direction: Vector2, projectile_range: float, explosion_rad: float = 0.0, knockback_val: float = 0.0):
	damage = projectile_damage
	speed = projectile_speed
	direction = projectile_direction.normalized()
	max_range = projectile_range
	explosive_radius = explosion_rad
	knockback_force = knockback_val
	distance_traveled = 0.0
	current_pierce = 0
	radius_multiplier = 1.0 
	_update_hitbox_size()

func _update_hitbox_size():
	# Scale collision shape radius
	var collision_shape: CollisionShape2D = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius = base_radius * radius_multiplier
	
	# Scale sprite to be proportional to guns (approx 0.5 of 16x16)
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		# Assuming base 16x16 sprite, 0.5 makes it 8x8 which is a good bullet size
		var base_scale = 0.5
		# Rockets/explosives get bigger
		if explosive_radius > 0:
			base_scale = 1.0 
		
		sprite.scale = Vector2.ONE * base_scale * radius_multiplier

func _on_body_entered(body: Node2D):
	# Ignore if body is not in target group and not an obstacle
	if body.is_in_group(target_group):
		if explosive_radius > 0:
			explode()
		else:
			hit_target(body)
		return
	
	# If hit something solid that is not the shooter
	if body is StaticBody2D or (body is CharacterBody2D and not body.is_in_group("enemies") and not body.is_in_group("player")):
		if explosive_radius > 0:
			explode()
		else:
			hit_obstacle(body)

func explode():
	# Deal damage in radius to members of target_group
	var targets = get_tree().get_nodes_in_group(target_group)
	for target in targets:
		if target and is_instance_valid(target):
			var dist = global_position.distance_to(target.global_position)
			if dist <= explosive_radius:
				if target.has_method("take_damage"):
					target.take_damage(damage)
				
				if target.has_method("apply_knockback") and knockback_force > 0:
					var knock_dir = (target.global_position - global_position).normalized()
					target.apply_knockback(knock_dir * knockback_force * 1.5)
				
				EventBus.projectile_hit.emit(target, damage)
	
	destroy()

func hit_target(target: Node2D):
	# Deal damage to target
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	if target.has_method("apply_knockback") and knockback_force > 0:
		target.apply_knockback(direction * knockback_force)
	
	# Emit hit event
	EventBus.projectile_hit.emit(target, damage)
	
	# Check pierce
	if current_pierce < pierce_count:
		current_pierce += 1
	else:
		destroy()


func hit_obstacle(obstacle: Node2D):
	# Damage destructible objects (chests, barrels, etc.)
	if obstacle.is_in_group("destructible"):
		if obstacle.has_method("take_damage"):
			obstacle.take_damage(damage)
	destroy()

func destroy():
	# Return to pool
	Pools.return_projectile(self)

func get_damage() -> int:
	return damage

func get_direction() -> Vector2:
	return direction