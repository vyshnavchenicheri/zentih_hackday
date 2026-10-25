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


class LowOverpass extends StaticBody2D:
	var span_width: float = 140.0
	var clearance_height: float = 24.0 # 24px gap from road: standing player hits it, sliding player fits underneath!
	var beam_thickness: float = 24.0
	
	func _init(w: float = 140.0, clearance: float = 24.0, thickness: float = 24.0) -> void:
		span_width = w
		clearance_height = clearance
		beam_thickness = thickness
		add_to_group("low_overpass")
		collision_layer = 1
		collision_mask = 1
	
	func _ready() -> void:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(span_width, beam_thickness)
		col.shape = shape
		# Centered vertically in the overhead girder above clearance
		col.position = Vector2(span_width / 2.0, -clearance_height - beam_thickness / 2.0)
		add_child(col)
	
	func _draw() -> void:
		var top_y: float = -clearance_height - beam_thickness
		# Heavy steel overhead beam
		draw_rect(Rect2(0, top_y, span_width, beam_thickness), Color(0.2, 0.25, 0.32))
		draw_rect(Rect2(2, top_y + 2, span_width - 4, beam_thickness - 4), Color(0.12, 0.16, 0.22))
		
		# Amber warning strip along bottom edge
		draw_rect(Rect2(0, -clearance_height - 3, span_width, 3), Color(0.95, 0.6, 0.1))
		
		# Downward neon warning chevrons [SLIDE ▾]
		var step = 32.0
		var count = int(span_width / step)
		for i in range(count):
			var cx = 16.0 + i * step
			draw_line(Vector2(cx - 5, top_y + 6), Vector2(cx, top_y + 12), Color(0.95, 0.85, 0.2), 2.0)
			draw_line(Vector2(cx, top_y + 12), Vector2(cx + 5, top_y + 6), Color(0.95, 0.85, 0.2), 2.0)


class CyberEnemy extends Area2D:
	var move_speed: float = 55.0
	var patrol_range: float = 120.0
	var start_x: float = 0.0
	var enemy_type: String = "zombie"
	var facing: int = -1
	var anim_time: float = 0.0
	
	func _init(type: String = "zombie") -> void:
		enemy_type = type
		add_to_group("enemies")
		collision_layer = 2
		collision_mask = 1
		move_speed = 95.0 if enemy_type == "hound" else 55.0
	
	func _ready() -> void:
		start_x = global_position.x
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(28, 38) if enemy_type == "zombie" else Vector2(38, 22)
		col.shape = shape
		col.position = Vector2(0, 0)
		add_child(col)
		
		body_entered.connect(_on_body_entered)
	
	func _physics_process(delta: float) -> void:
		anim_time += delta
		global_position.x += facing * move_speed * delta
		if abs(global_position.x - start_x) > patrol_range:
			facing = -facing
		queue_redraw()
	
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0))
		if enemy_type == "hound":
			_draw_zombie_dog()
		else:
			_draw_zombie()
	
	func _draw_zombie() -> void:
		var limp: float = sin(anim_time * 5.0) * 3.0
		var head_bob: float = abs(sin(anim_time * 5.0)) * 2.0
		var sway: float = cos(anim_time * 2.5) * 2.0
		
		# 1. Back Shambling Leg
		var leg_b_x: float = -4.0 - limp
		draw_line(Vector2(leg_b_x, 0), Vector2(leg_b_x - 1, 14), Color(0.18, 0.28, 0.2), 4.0)
		draw_rect(Rect2(leg_b_x - 3, 13, 6, 4), Color(0.12, 0.16, 0.12))
		
		# 2. Hunched Rotting Torso
		var torso_pts = PackedVector2Array([
			Vector2(-6.0 + sway, -14.0 + head_bob),
			Vector2(5.0 + sway, -12.0 + head_bob),
			Vector2(4.0, 2.0),
			Vector2(-5.0, 2.0)
		])
		draw_colored_polygon(torso_pts, Color(0.24, 0.38, 0.28))
		
		# Shredded biohazard rags
		draw_rect(Rect2(-5.0 + sway, -8.0 + head_bob, 9, 8), Color(0.38, 0.3, 0.18, 0.85))
		
		# Exposed Bone Ribs
		var rib_x = 1.0 + sway
		draw_line(Vector2(rib_x, -8.0 + head_bob), Vector2(rib_x + 4.0, -8.0 + head_bob), Color(0.85, 0.82, 0.72), 2.0)
		draw_line(Vector2(rib_x, -5.0 + head_bob), Vector2(rib_x + 5.0, -5.0 + head_bob), Color(0.85, 0.82, 0.72), 2.0)
		draw_line(Vector2(rib_x, -2.0 + head_bob), Vector2(rib_x + 4.0, -2.0 + head_bob), Color(0.85, 0.82, 0.72), 2.0)
		
		# 3. Front Shambling Leg
		var leg_f_x: float = 3.0 + limp
		draw_line(Vector2(leg_f_x, 0), Vector2(leg_f_x + 2.0, 14), Color(0.26, 0.38, 0.28), 4.5)
		draw_rect(Rect2(leg_f_x - 1, 13, 7, 4), Color(0.15, 0.2, 0.14))
		
		# 4. Decayed Zombie Head & Jaws
		var head_pos = Vector2(3.0 + sway, -19.0 + head_bob)
		draw_rect(Rect2(head_pos.x - 5, head_pos.y - 5, 10, 9), Color(0.26, 0.42, 0.3))
		draw_rect(Rect2(head_pos.x - 4.0, head_pos.y - 6, 4, 3), Color(0.82, 0.8, 0.7))
		
		# Gaping mouth
		var mouth_x = head_pos.x + 1.0
		draw_rect(Rect2(mouth_x, head_pos.y + 1, 5, 3), Color(0.5, 0.05, 0.05))
		draw_line(Vector2(mouth_x + 1, head_pos.y + 1), Vector2(mouth_x + 2, head_pos.y + 3), Color(0.9, 0.9, 0.8), 1.0)
		draw_line(Vector2(mouth_x + 3, head_pos.y + 1), Vector2(mouth_x + 4, head_pos.y + 3), Color(0.9, 0.9, 0.8), 1.0)
		
		# Glowing Necrotic Eye
		var eye_x: float = head_pos.x + 1.0
		draw_rect(Rect2(eye_x, head_pos.y - 3, 3, 3), Color(1.0, 0.2, 0.1))
		draw_rect(Rect2(eye_x + 1, head_pos.y - 2, 1, 1), Color(1.0, 0.9, 0.2))
		
		# 5. Outstretched Reaching Zombie Arms
		var arm_shoulder = Vector2(2.0 + sway, -11.0 + head_bob)
		var reach_y = sin(anim_time * 4.0) * 2.0
		draw_line(arm_shoulder + Vector2(-2.0, 0), arm_shoulder + Vector2(13.0, -4.0 + reach_y), Color(0.22, 0.32, 0.24), 3.5)
		var arm_front_hand = arm_shoulder + Vector2(16.0, -1.0 - reach_y)
		draw_line(arm_shoulder, arm_front_hand, Color(0.28, 0.44, 0.32), 4.0)
		draw_line(arm_front_hand, arm_front_hand + Vector2(4.0, -2), Color(0.85, 0.82, 0.72), 2.0)
		draw_line(arm_front_hand, arm_front_hand + Vector2(4.0, 2), Color(0.85, 0.82, 0.72), 2.0)
		draw_circle(arm_front_hand + Vector2(3.0, 3), 1.2, Color(0.18, 0.85, 0.25))
	
	func _draw_zombie_dog() -> void:
		var gallop: float = sin(anim_time * 14.0) * 6.0
		var spine_flex: float = cos(anim_time * 14.0) * 2.5
		
		# 1. Back Hind Leg
		var hind_pos = Vector2(-11.0 - gallop * 0.7, 10.0)
		draw_line(Vector2(-10.0, -2.0), hind_pos, Color(0.24, 0.3, 0.22), 3.5)
		draw_line(hind_pos, hind_pos + Vector2(3.0, 2), Color(0.7, 0.65, 0.58), 2.0)
		
		# 2. Back Foreleg
		var fore_b_pos = Vector2(10.0 + gallop * 0.7, 10.0)
		draw_line(Vector2(9.0, -2.0), fore_b_pos, Color(0.24, 0.3, 0.22), 3.5)
		draw_line(fore_b_pos, fore_b_pos + Vector2(3.0, 2), Color(0.7, 0.65, 0.58), 2.0)
		
		# 3. Emaciated Rotting Canine Torso & Spine
		var torso_pts = PackedVector2Array([
			Vector2(-13.0, -5.0 + spine_flex),
			Vector2(-4.0, -8.0),
			Vector2(8.0, -6.0 - spine_flex),
			Vector2(11.0, 0.0),
			Vector2(-8.0, 1.0)
		])
		draw_colored_polygon(torso_pts, Color(0.3, 0.38, 0.28))
		
		# Exposed Spine Spikes
		for v in range(4):
			var vx: float = -10.0 + v * 5.0
			draw_line(Vector2(vx, -6.0), Vector2(vx, -9.0), Color(0.88, 0.85, 0.78), 2.0)
		
		# Exposed Rib Bones
		for r in range(3):
			var rx: float = -3.0 + r * 4.0
			draw_line(Vector2(rx, -5.0), Vector2(rx + 2.0, -1.0), Color(0.85, 0.82, 0.72), 1.8)
		
		# 4. Front Hind Leg
		var hind_f_pos = Vector2(-10.0 + gallop, 10.0)
		draw_line(Vector2(-9.0, -3.0), hind_f_pos + Vector2(-1, -3), Color(0.34, 0.44, 0.3), 4.0)
		draw_line(hind_f_pos + Vector2(-1, -3), hind_f_pos, Color(0.28, 0.36, 0.25), 3.0)
		draw_line(hind_f_pos, hind_f_pos + Vector2(3.0, 2), Color(0.12, 0.15, 0.12), 2.0)
		
		# 5. Front Foreleg
		var fore_f_pos = Vector2(9.0 - gallop, 10.0)
		draw_line(Vector2(8.0, -4.0), fore_f_pos + Vector2(1, -3), Color(0.34, 0.44, 0.3), 4.0)
		draw_line(fore_f_pos + Vector2(1, -3), fore_f_pos, Color(0.28, 0.36, 0.25), 3.0)
		draw_line(fore_f_pos, fore_f_pos + Vector2(3.0, 2), Color(0.12, 0.15, 0.12), 2.0)
		
		# 6. Snapping Rabid Head & Fangs
		var head_pos = Vector2(13.0, -6.0 - spine_flex)
		draw_rect(Rect2(head_pos.x - 3, head_pos.y - 4, 7, 7), Color(0.32, 0.42, 0.3))
		draw_rect(Rect2(head_pos.x + 1.0, head_pos.y - 3, 6, 4), Color(0.82, 0.8, 0.72))
		
		var jaw_x = head_pos.x + 2.0
		draw_rect(Rect2(jaw_x, head_pos.y + 1, 6, 4), Color(0.55, 0.08, 0.08))
		draw_line(Vector2(jaw_x + 1, head_pos.y + 1), Vector2(jaw_x + 1, head_pos.y + 4), Color(0.95, 0.95, 0.9), 1.5)
		draw_line(Vector2(jaw_x + 4, head_pos.y + 1), Vector2(jaw_x + 4, head_pos.y + 4), Color(0.95, 0.95, 0.9), 1.5)
		draw_circle(Vector2(jaw_x + 3, head_pos.y + 5), 1.2, Color(0.2, 0.95, 0.3))
		
		# Glowing Red Eye
		var eye_x: float = head_pos.x
		draw_rect(Rect2(eye_x, head_pos.y - 3, 3, 2), Color(1.0, 0.1, 0.1))
		draw_rect(Rect2(eye_x + 1, head_pos.y - 3, 1, 1), Color(1.0, 0.8, 0.2))
		
		draw_line(Vector2(head_pos.x - 2, head_pos.y - 4), Vector2(head_pos.x - 5, head_pos.y - 9), Color(0.26, 0.32, 0.24), 2.5)
		
		# 7. Whipping Tail
		var tail_whip = sin(anim_time * 16.0) * 3.0
		var tail_root = Vector2(-14.0, -4.0 + spine_flex)
		draw_line(tail_root, tail_root + Vector2(-6.0, -6.0 + tail_whip), Color(0.75, 0.72, 0.65), 2.0)
		draw_line(tail_root + Vector2(-6.0, -6.0 + tail_whip), tail_root + Vector2(-11.0, -4.0 + tail_whip * 1.5), Color(0.75, 0.72, 0.65), 1.5)
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			if body.is_dashing or body.slash_timer > 0.0 or body.is_sliding:
				die_cleaved()
				if body.is_dashing:
					body.refund_dash_pip()
			else:
				var dmg = 8.0 if enemy_type == "hound" else 12.0
				body.take_damage(dmg, -facing)
	
	func die_cleaved() -> void:
		var emitter = CPUParticles2D.new()
		emitter.emitting = true
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.lifetime = 0.45
		emitter.amount = 26
		emitter.direction = Vector2(-facing, -0.4)
		emitter.spread = 75.0
		emitter.initial_velocity_min = 100.0
		emitter.initial_velocity_max = 260.0
		# Gory zombie decay and blood splatters
		emitter.color = Color(0.2, 0.85, 0.25) if randf() > 0.45 else Color(0.75, 0.12, 0.12)
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
