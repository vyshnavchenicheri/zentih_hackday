extends Node
class_name InteractiveObjects

# Utility classes for spawning world interactive elements in Godot 4

class JumpPad extends Area2D:
	var pad_width: float = 50.0
	var pad_height: float = 12.0
	
	func _init(w: float = 50.0, h: float = 12.0) -> void:
		pad_width = w
		pad_height = h
		add_to_group("jump_pads")
		collision_layer = 4
		collision_mask = 1
	
	func _ready() -> void:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(pad_width, pad_height)
		col.shape = shape
		col.position = Vector2(pad_width / 2.0, pad_height / 2.0)
		add_child(col)
		
		body_entered.connect(_on_body_entered)
	
	func _draw() -> void:
		# Draw glowing spring pad
		draw_rect(Rect2(0, 0, pad_width, pad_height), Color(0.2, 1.0, 0.2))
		draw_rect(Rect2(2, 2, pad_width - 4, pad_height - 4), Color(0.1, 0.4, 0.15))
		# Arrow pointers
		for i in range(3):
			var ax: float = 10.0 + i * 14.0
			draw_line(Vector2(ax, 8), Vector2(ax + 5, 3), Color(0.2, 1.0, 0.2), 2.0)
			draw_line(Vector2(ax + 5, 3), Vector2(ax + 10, 8), Color(0.2, 1.0, 0.2), 2.0)
	
	func _on_body_entered(body: Node2D) -> void:
		if body is CharacterBody2D:
			body.velocity.y = -860.0 # High vertical launch to Tier 1 Catwalk
			if "jumps_left" in body:
				body.jumps_left = body.max_jumps
			spawn_spring_effect()
	
	func spawn_spring_effect() -> void:
		var emitter = CPUParticles2D.new()
		emitter.emitting = true
		emitter.one_shot = true
		emitter.lifetime = 0.3
		emitter.amount = 12
		emitter.direction = Vector2(0, -1)
		emitter.spread = 45.0
		emitter.initial_velocity_min = 90.0
		emitter.initial_velocity_max = 180.0
		emitter.color = Color(0.2, 1.0, 0.2)
		get_parent().add_child(emitter)
		emitter.global_position = global_position + Vector2(pad_width / 2.0, 0)
		emitter.finished.connect(emitter.queue_free)


class Barricade extends StaticBody2D:
	var bar_width: float = 24.0
	var bar_height: float = 48.0
	
	func _init(w: float = 24.0, h: float = 48.0) -> void:
		bar_width = w
		bar_height = h
		add_to_group("barricades")
		collision_layer = 1
		collision_mask = 1
	
	func _ready() -> void:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(bar_width, bar_height)
		col.shape = shape
		col.position = Vector2(bar_width / 2.0, bar_height / 2.0)
		add_child(col)
		
		# Hitbox area for detection
		var hit_area = Area2D.new()
		hit_area.name = "BarricadeSensor"
		hit_area.add_to_group("barricades")
		var sensor_col = CollisionShape2D.new()
		var sensor_shape = RectangleShape2D.new()
		sensor_shape.size = Vector2(bar_width + 8.0, bar_height + 4.0)
		sensor_col.shape = sensor_shape
		sensor_col.position = col.position
		hit_area.add_child(sensor_col)
		add_child(hit_area)
	
	func _draw() -> void:
		draw_rect(Rect2(0, 0, bar_width, bar_height), Color(0.95, 0.55, 0.1)) # Hazard amber
		# Slanted hazard warning stripes
		for s in range(4):
			var sy: float = s * 12.0 + 2.0
			draw_rect(Rect2(2, sy, bar_width - 4, 4), Color(0.1, 0.1, 0.1))
		# Warning red light at top
		draw_rect(Rect2(bar_width / 2.0 - 3, -5, 6, 5), Color(1.0, 0.2, 0.2))
	
	func shatter() -> void:
		var emitter = CPUParticles2D.new()
		emitter.emitting = true
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.lifetime = 0.4
		emitter.amount = 16
		emitter.direction = Vector2(1, -0.4)
		emitter.spread = 70.0
		emitter.initial_velocity_min = 80.0
		emitter.initial_velocity_max = 220.0
		emitter.color = Color(0.95, 0.55, 0.1)
		get_parent().add_child(emitter)
		emitter.global_position = global_position + Vector2(bar_width / 2.0, bar_height / 2.0)
		emitter.finished.connect(emitter.queue_free)
		queue_free()


class CyberEnemy extends Area2D:
	var move_speed: float = 60.0
	var patrol_range: float = 120.0
	var start_x: float = 0.0
	var enemy_type: String = "zombie"
	var facing: int = -1
	
	func _init(type: String = "zombie") -> void:
		enemy_type = type
		add_to_group("enemies")
		collision_layer = 2
		collision_mask = 1
	
	func _ready() -> void:
		start_x = global_position.x
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(24, 36) if enemy_type == "zombie" else Vector2(36, 24)
		col.shape = shape
		col.position = Vector2(0, 0)
		add_child(col)
		
		body_entered.connect(_on_body_entered)
	
	func _physics_process(delta: float) -> void:
		global_position.x += facing * move_speed * delta
		if abs(global_position.x - start_x) > patrol_range:
			facing = -facing
		queue_redraw()
	
	func _draw() -> void:
		if enemy_type == "hound":
			# Mutant Hound
			draw_rect(Rect2(-18, -12, 36, 24), Color(0.28, 0.32, 0.38))
			# Red optic
			var eye_x: float = 10.0 if facing == 1 else -14.0
			draw_rect(Rect2(eye_x, -8, 4, 4), Color(1.0, 0.2, 0.2))
		else:
			# Cyber-Zombie
			draw_rect(Rect2(-10, -18, 20, 36), Color(0.2, 0.25, 0.32))
			draw_rect(Rect2(-8, -26, 16, 12), Color(0.38, 0.44, 0.52))
			# Toxic green optic
			var eye_x: float = 2.0 if facing == 1 else -6.0
			draw_rect(Rect2(eye_x, -22, 4, 4), Color(0.2, 1.0, 0.2))
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			if body.is_dashing or body.slash_timer > 0.0:
				die_cleaved()
				body.refund_dash_pip()
			else:
				body.take_damage(10.0, -facing)
	
	func die_cleaved() -> void:
		var emitter = CPUParticles2D.new()
		emitter.emitting = true
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.lifetime = 0.45
		emitter.amount = 24
		emitter.direction = Vector2(-facing, -0.3)
		emitter.spread = 70.0
		emitter.initial_velocity_min = 90.0
		emitter.initial_velocity_max = 240.0
		emitter.color = Color(0.2, 1.0, 0.2) if randf() > 0.4 else Color(0.0, 0.95, 1.0)
		get_parent().add_child(emitter)
		emitter.global_position = global_position
		emitter.finished.connect(emitter.queue_free)
		queue_free()


class SludgeHazard extends Area2D:
	var width: float = 140.0
	var height: float = 30.0
	
	func _init(w: float = 140.0, h: float = 30.0) -> void:
		width = w
		height = h
		add_to_group("sludge")
		collision_layer = 4
		collision_mask = 1
	
	func _ready() -> void:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(width, height)
		col.shape = shape
		col.position = Vector2(width / 2.0, height / 2.0)
		add_child(col)
		body_entered.connect(_on_body_entered)
	
	func _draw() -> void:
		# Acidic bubbling green sludge
		draw_rect(Rect2(0, 0, width, height), Color(0.12, 0.8, 0.25))
		draw_rect(Rect2(0, 4, width, height - 4), Color(0.08, 0.45, 0.15))
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			body.take_damage(10.0, 0.0)
			body.velocity.y = -550.0 # Bounce out of toxic pool
			body.jumps_left = body.max_jumps
