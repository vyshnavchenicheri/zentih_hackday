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
	var clearance_height: float = 28.0 # 28px clearance: standing player hits it, sliding player & dog fit effortlessly!
	var beam_thickness: float = 24.0
	
	func _init(w: float = 140.0, clearance: float = 28.0, thickness: float = 24.0) -> void:
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
	var outfit: int = 0 # 0: Punk, 1: Hazmat, 2: SWAT, 3: Inmate, 4: Business Suit
	var breed: String = "doberman" # "doberman", "rottweiler", "shepherd", "mastiff"
	var facing: int = -1
	var anim_time: float = 0.0
	
	func _init(type: String = "zombie", outfit_id: int = -1, dog_breed: String = "") -> void:
		enemy_type = type
		add_to_group("enemies")
		collision_layer = 2
		collision_mask = 1
		move_speed = 95.0 if enemy_type == "hound" else 55.0
		
		if outfit_id >= 0:
			outfit = outfit_id % 5
		else:
			outfit = randi() % 5
		
		if dog_breed != "":
			breed = dog_breed
		else:
			var breeds = ["doberman", "rottweiler", "shepherd", "mastiff"]
			breed = breeds[randi() % breeds.size()]
	
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
		
		# Look for approaching runner on same vertical tier to charge/aggro
		var current_speed = move_speed
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dx = player.global_position.x - global_position.x
			var dy = abs(player.global_position.y - global_position.y)
			# If player is in front (approaching from left within 360px) and on same height level
			if dx < 0.0 and dx > -380.0 and dy < 60.0:
				facing = -1 # Face incoming player
				current_speed = move_speed * (1.7 if enemy_type == "hound" else 1.25)
		
		global_position.x += facing * current_speed * delta
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
		
		# Outfit Color Schemes
		var leg_skin = Color(0.24, 0.36, 0.26)
		var leg_cloth = Color(0.2, 0.26, 0.38) # Default punk jeans
		var shoe_col = Color(0.72, 0.2, 0.2)   # Default sneaker
		var torso_cloth = Color(0.18, 0.18, 0.22)
		var accent_col = Color(0.95, 0.18, 0.55)
		
		match outfit:
			0: # Civilian Punk
				leg_cloth = Color(0.2, 0.26, 0.38) # Ripped blue jeans
				shoe_col = Color(0.72, 0.2, 0.2)   # Red punk sneaker
				torso_cloth = Color(0.18, 0.18, 0.22) # Leather jacket
				accent_col = Color(0.95, 0.18, 0.55)  # Magenta spray patch
			1: # Biohazard Hazmat
				leg_cloth = Color(0.88, 0.76, 0.12) # Hazmat yellow pants
				shoe_col = Color(0.12, 0.14, 0.12)  # Heavy acid boots
				torso_cloth = Color(0.88, 0.76, 0.12) # Hazmat suit
				accent_col = Color(0.15, 0.75, 0.25)  # Toxic sludge drip
			2: # Tactical SWAT
				leg_cloth = Color(0.24, 0.27, 0.24) # Urban camo pants
				shoe_col = Color(0.1, 0.1, 0.12)    # Combat boots
				torso_cloth = Color(0.14, 0.16, 0.18) # Kevlar vest
				accent_col = Color(0.0, 0.9, 1.0)     # Cyan NVG optic
			3: # Prison Inmate
				leg_cloth = Color(0.95, 0.44, 0.08) # Neon orange prison trousers
				shoe_col = Color(0.28, 0.2, 0.14)   # Prison work boots
				torso_cloth = Color(0.95, 0.44, 0.08) # Orange inmate jumpsuit
				accent_col = Color(0.1, 0.1, 0.1)     # Black prison stripes
			4: # Business Suit
				leg_cloth = Color(0.2, 0.22, 0.25)  # Charcoal slacks
				shoe_col = Color(0.08, 0.08, 0.1)   # Polished black dress shoe
				torso_cloth = Color(0.2, 0.22, 0.25) # Business blazer
				accent_col = Color(0.8, 0.08, 0.12)   # Blood-soaked red tie
		
		# 1. Back Shambling Leg
		var leg_b_x: float = -4.0 - limp
		draw_line(Vector2(leg_b_x, 0), Vector2(leg_b_x - 1, 14), leg_cloth, 4.0)
		draw_rect(Rect2(leg_b_x - 3, 13, 6, 4), shoe_col)
		
		# 2. Hunched Rotting Torso
		var torso_pts = PackedVector2Array([
			Vector2(-6.0 + sway, -14.0 + head_bob),
			Vector2(5.0 + sway, -12.0 + head_bob),
			Vector2(4.0, 2.0),
			Vector2(-5.0, 2.0)
		])
		draw_colored_polygon(torso_pts, torso_cloth)
		
		# Specific Torso Clothing Details
		match outfit:
			0: # Punk hoodie / ripped patches
				draw_rect(Rect2(-4.0 + sway, -10.0 + head_bob, 7, 7), Color(0.14, 0.14, 0.17))
				draw_circle(Vector2(-1.0 + sway, -7.0 + head_bob), 2.0, accent_col)
			1: # Hazmat hazard stripes & sludge
				draw_rect(Rect2(-4.0 + sway, -8.0 + head_bob, 8, 3), Color(0.12, 0.12, 0.12))
				draw_circle(Vector2(1.0 + sway, -2.0 + head_bob), 2.2, accent_col)
			2: # SWAT MOLLE ballistic plates & pouches
				draw_line(Vector2(-5.0 + sway, -10.0 + head_bob), Vector2(4.0 + sway, -10.0 + head_bob), Color(0.25, 0.28, 0.3), 2.0)
				draw_line(Vector2(-4.0 + sway, -6.0 + head_bob), Vector2(4.0 + sway, -6.0 + head_bob), Color(0.25, 0.28, 0.3), 2.0)
				draw_rect(Rect2(-2.0 + sway, -5.0 + head_bob, 4, 4), Color(0.18, 0.2, 0.22))
			3: # Prison inmate bold horizontal stencils
				draw_line(Vector2(-5.0 + sway, -11.0 + head_bob), Vector2(4.0 + sway, -11.0 + head_bob), accent_col, 2.0)
				draw_line(Vector2(-5.0 + sway, -7.0 + head_bob), Vector2(4.0 + sway, -7.0 + head_bob), accent_col, 2.0)
				draw_line(Vector2(-4.0 + sway, -3.0 + head_bob), Vector2(3.0 + sway, -3.0 + head_bob), accent_col, 2.0)
			4: # Business white shirt & long fluttering bloodied tie
				draw_colored_polygon(PackedVector2Array([
					Vector2(0.0 + sway, -12.0 + head_bob),
					Vector2(3.0 + sway, -12.0 + head_bob),
					Vector2(1.0 + sway, -4.0 + head_bob)
				]), Color(0.85, 0.85, 0.82))
				var tie_wave = sin(anim_time * 8.0) * 3.0
				draw_line(Vector2(1.5 + sway, -10.0 + head_bob), Vector2(-1.0 + sway - tie_wave, 2.0), accent_col, 2.5)
				draw_line(Vector2(-1.0 + sway - tie_wave, 2.0), Vector2(-3.0 + sway - tie_wave * 1.5, 6.0), accent_col, 2.0)
		
		# Exposed Bone Ribs
		var rib_x = 1.0 + sway
		draw_line(Vector2(rib_x, -8.0 + head_bob), Vector2(rib_x + 3.5, -8.0 + head_bob), Color(0.85, 0.82, 0.72), 1.8)
		draw_line(Vector2(rib_x, -5.0 + head_bob), Vector2(rib_x + 4.0, -5.0 + head_bob), Color(0.85, 0.82, 0.72), 1.8)
		
		# 3. Front Shambling Leg
		var leg_f_x: float = 3.0 + limp
		draw_line(Vector2(leg_f_x, 0), Vector2(leg_f_x + 2.0, 14), leg_cloth, 4.5)
		draw_rect(Rect2(leg_f_x - 1, 13, 7, 4), shoe_col)
		# Knee rip on punk
		if outfit == 0:
			draw_circle(Vector2(leg_f_x + 1.0, 7.0), 1.5, leg_skin)
		elif outfit == 2: # SWAT knee pad
			draw_rect(Rect2(leg_f_x - 1.0, 5.0, 4, 4), Color(0.1, 0.1, 0.12))
		
		# 4. Decayed Zombie Head & Jaws
		var head_pos = Vector2(3.0 + sway, -19.0 + head_bob)
		draw_rect(Rect2(head_pos.x - 5, head_pos.y - 5, 10, 9), Color(0.26, 0.42, 0.3))
		draw_rect(Rect2(head_pos.x - 4.0, head_pos.y - 6, 4, 3), Color(0.82, 0.8, 0.7))
		
		# Headgear / Hair according to outfit
		match outfit:
			0: # Punk spiky mohawk / hair tufts
				draw_line(Vector2(head_pos.x - 4, head_pos.y - 6), Vector2(head_pos.x - 5, head_pos.y - 11), Color(0.12, 0.12, 0.15), 2.5)
				draw_line(Vector2(head_pos.x - 1, head_pos.y - 6), Vector2(head_pos.x - 1, head_pos.y - 12), Color(0.12, 0.12, 0.15), 2.5)
				draw_line(Vector2(head_pos.x + 2, head_pos.y - 6), Vector2(head_pos.x + 3, head_pos.y - 10), Color(0.12, 0.12, 0.15), 2.5)
				draw_circle(Vector2(head_pos.x - 4, head_pos.y), 1.0, Color(0.9, 0.9, 0.95)) # Ear stud
			1: # Hazmat hood & chemical respirator mask
				draw_rect(Rect2(head_pos.x - 6, head_pos.y - 7, 12, 4), Color(0.88, 0.76, 0.12))
				draw_rect(Rect2(head_pos.x - 1, head_pos.y + 1, 6, 5), Color(0.3, 0.35, 0.3))
				draw_circle(Vector2(head_pos.x + 4, head_pos.y + 4), 2.2, Color(0.18, 0.95, 0.28)) # Glowing filter
			2: # SWAT tactical helmet & glowing cyan NVG optic
				draw_rect(Rect2(head_pos.x - 6, head_pos.y - 8, 12, 5), Color(0.12, 0.14, 0.16))
				draw_line(Vector2(head_pos.x - 5, head_pos.y - 4), Vector2(head_pos.x + 5, head_pos.y - 4), Color(0.08, 0.08, 0.1), 1.5)
				draw_rect(Rect2(head_pos.x + 1, head_pos.y - 4, 4, 4), Color(0.0, 0.95, 1.0)) # NVG lens
			3: # Prison inmate shaved scarred skull & barcode
				draw_line(Vector2(head_pos.x - 3, head_pos.y - 2), Vector2(head_pos.x - 1, head_pos.y - 2), Color(0.1, 0.1, 0.1), 1.5)
				draw_line(Vector2(head_pos.x - 3, head_pos.y), Vector2(head_pos.x - 1, head_pos.y), Color(0.1, 0.1, 0.1), 1.5)
			4: # Messy executive hair
				draw_line(Vector2(head_pos.x - 5, head_pos.y - 6), Vector2(head_pos.x + 4, head_pos.y - 7), Color(0.16, 0.14, 0.12), 2.5)
		
		# Gaping mouth (if not covered by hazmat mask)
		if outfit != 1:
			var mouth_x = head_pos.x + 1.0
			draw_rect(Rect2(mouth_x, head_pos.y + 1, 5, 3), Color(0.5, 0.05, 0.05))
			draw_line(Vector2(mouth_x + 1, head_pos.y + 1), Vector2(mouth_x + 2, head_pos.y + 3), Color(0.9, 0.9, 0.8), 1.0)
			draw_line(Vector2(mouth_x + 3, head_pos.y + 1), Vector2(mouth_x + 4, head_pos.y + 3), Color(0.9, 0.9, 0.8), 1.0)
		
		# Glowing Necrotic Eye (if not covered by SWAT NVG)
		if outfit != 2:
			var eye_x: float = head_pos.x + 1.0
			draw_rect(Rect2(eye_x, head_pos.y - 3, 3, 3), Color(1.0, 0.2, 0.1))
			draw_rect(Rect2(eye_x + 1, head_pos.y - 2, 1, 1), Color(1.0, 0.9, 0.2))
		
		# 5. Outstretched Reaching Zombie Arms
		var arm_shoulder = Vector2(2.0 + sway, -11.0 + head_bob)
		var reach_y = sin(anim_time * 4.0) * 2.0
		var arm_cloth_color = torso_cloth
		draw_line(arm_shoulder + Vector2(-2.0, 0), arm_shoulder + Vector2(13.0, -4.0 + reach_y), arm_cloth_color, 3.5)
		
		var arm_front_hand = arm_shoulder + Vector2(16.0, -1.0 - reach_y)
		draw_line(arm_shoulder, arm_front_hand, Color(0.28, 0.44, 0.32), 4.0)
		draw_line(arm_front_hand, arm_front_hand + Vector2(4.0, -2), Color(0.85, 0.82, 0.72), 2.0)
		draw_line(arm_front_hand, arm_front_hand + Vector2(4.0, 2), Color(0.85, 0.82, 0.72), 2.0)
		draw_circle(arm_front_hand + Vector2(3.0, 3), 1.2, Color(0.18, 0.85, 0.25))
		
		# Wrist accessories
		if outfit == 3: # Broken prisoner iron shackle & chain links
			var shackle_pos = arm_front_hand + Vector2(-3, 0)
			draw_rect(Rect2(shackle_pos.x - 2, shackle_pos.y - 2, 4, 5), Color(0.65, 0.68, 0.72))
			var chain_sway = sin(anim_time * 7.0) * 4.0
			draw_line(shackle_pos, shackle_pos + Vector2(chain_sway, 6), Color(0.65, 0.68, 0.72), 2.0)
			draw_line(shackle_pos + Vector2(chain_sway, 6), shackle_pos + Vector2(chain_sway * 1.5, 12), Color(0.55, 0.58, 0.62), 1.5)
		elif outfit == 4: # Luxury gold corporate watch
			var watch_pos = arm_front_hand + Vector2(-4, 0)
			draw_rect(Rect2(watch_pos.x - 2, watch_pos.y - 2, 3, 4), Color(0.95, 0.82, 0.2))
		elif outfit == 1: # Hazmat rubber gloves
			draw_circle(arm_front_hand + Vector2(1.0, 0.0), 3.0, Color(0.12, 0.12, 0.14))
	
	func _draw_zombie_dog() -> void:
		var gallop: float = sin(anim_time * 14.0) * 6.0
		var spine_flex: float = cos(anim_time * 14.0) * 2.5
		
		# Breed Palette & Profile
		var coat_primary = Color(0.14, 0.16, 0.18)
		var coat_accent = Color(0.55, 0.32, 0.18)
		var bone_col = Color(0.85, 0.82, 0.74)
		var eye_col = Color(1.0, 0.1, 0.1)
		
		match breed:
			"doberman":
				coat_primary = Color(0.12, 0.14, 0.16) # Sleek obsidian
				coat_accent = Color(0.55, 0.32, 0.18)  # Tan muzzle/chest
				eye_col = Color(0.0, 0.95, 1.0)       # Cyan cyber optic
			"rottweiler":
				coat_primary = Color(0.2, 0.18, 0.16)  # Dark charcoal mahogany
				coat_accent = Color(0.48, 0.28, 0.16)
				eye_col = Color(1.0, 0.65, 0.1)        # Burning amber
			"shepherd":
				coat_primary = Color(0.14, 0.14, 0.16) # Black saddle back
				coat_accent = Color(0.68, 0.52, 0.32)  # Tan wolf undercoat
				eye_col = Color(1.0, 0.2, 0.1)
			"mastiff":
				coat_primary = Color(0.22, 0.2, 0.22)  # Charred ash hellhound
				coat_accent = Color(0.65, 0.1, 0.1)    # Bloodied sinew
				eye_col = Color(1.0, 0.05, 0.05)       # Demonic blood red
		
		# 1. Back Hind Leg
		var hind_pos = Vector2(-11.0 - gallop * 0.7, 10.0)
		draw_line(Vector2(-10.0, -2.0), hind_pos, coat_primary, 3.5 if breed != "rottweiler" else 4.5)
		draw_line(hind_pos, hind_pos + Vector2(3.0, 2), coat_accent if breed != "mastiff" else bone_col, 2.0)
		
		# 2. Back Foreleg
		var fore_b_pos = Vector2(10.0 + gallop * 0.7, 10.0)
		draw_line(Vector2(9.0, -2.0), fore_b_pos, coat_primary, 3.5 if breed != "rottweiler" else 4.5)
		draw_line(fore_b_pos, fore_b_pos + Vector2(3.0, 2), coat_accent if breed != "mastiff" else bone_col, 2.0)
		
		# 3. Canine Torso & Spine
		var torso_w = 12.0 if breed == "rottweiler" else (10.0 if breed == "mastiff" else 9.0)
		var torso_pts = PackedVector2Array([
			Vector2(-13.0, -5.0 + spine_flex),
			Vector2(-4.0, -8.0),
			Vector2(8.0, -6.0 - spine_flex),
			Vector2(torso_w, 1.0),
			Vector2(-8.0, 2.0)
		])
		draw_colored_polygon(torso_pts, coat_primary)
		
		# Breed Specific Torso Accents
		match breed:
			"doberman":
				# Tan underchest & glowing cyber vertebrae
				draw_line(Vector2(-2.0, 0.0), Vector2(6.0, 0.0), coat_accent, 3.0)
				for v in range(4):
					var vx = -9.0 + v * 4.5
					draw_circle(Vector2(vx, -7.0), 1.5, Color(0.0, 0.95, 1.0))
			"rottweiler":
				# Broad muscular chest & heavy spiked collar
				draw_circle(Vector2(7.0, -2.0), 5.5, coat_primary)
				draw_line(Vector2(8.0, -8.0), Vector2(12.0, -1.0), Color(0.4, 0.44, 0.48), 3.5) # Iron collar
				draw_circle(Vector2(9.0, -7.0), 1.5, Color(0.85, 0.85, 0.9)) # Spikes
				draw_circle(Vector2(11.0, -4.0), 1.5, Color(0.85, 0.85, 0.9))
			"shepherd":
				# Tan belly & bushy wolf scruff
				draw_line(Vector2(-6.0, 1.0), Vector2(7.0, 1.0), coat_accent, 3.0)
				draw_line(Vector2(3.0, -8.0), Vector2(8.0, -4.0), Color(0.58, 0.45, 0.28), 4.0) # Wolf mane
				# Tactical chest harness
				draw_line(Vector2(5.0, -6.0), Vector2(7.0, 0.0), Color(0.18, 0.22, 0.18), 2.5)
				draw_circle(Vector2(6.0, -3.0), 1.2, Color(0.2, 0.95, 0.3)) # Green LED
			"mastiff":
				# Skeletal hellhound: protruding jagged bone spikes along back
				for v in range(5):
					var vx = -11.0 + v * 4.5
					draw_line(Vector2(vx, -5.0), Vector2(vx - 2.0, -11.0), bone_col, 2.5)
				# Exposed bloody ribs
				for r in range(4):
					var rx = -4.0 + r * 3.5
					draw_line(Vector2(rx, -5.0), Vector2(rx + 2.0, 0.0), Color(0.8, 0.2, 0.2), 2.0)
		
		# 4. Front Hind Leg
		var hind_f_pos = Vector2(-10.0 + gallop, 10.0)
		draw_line(Vector2(-9.0, -3.0), hind_f_pos + Vector2(-1, -3), coat_primary, 4.0 if breed != "rottweiler" else 5.0)
		draw_line(hind_f_pos + Vector2(-1, -3), hind_f_pos, coat_accent, 3.0)
		draw_line(hind_f_pos, hind_f_pos + Vector2(3.0, 2), Color(0.12, 0.15, 0.12), 2.0)
		
		# 5. Front Foreleg
		var fore_f_pos = Vector2(9.0 - gallop, 10.0)
		draw_line(Vector2(8.0, -4.0), fore_f_pos + Vector2(1, -3), coat_primary, 4.0 if breed != "rottweiler" else 5.0)
		draw_line(fore_f_pos + Vector2(1, -3), fore_f_pos, coat_accent, 3.0)
		draw_line(fore_f_pos, fore_f_pos + Vector2(3.0, 2), Color(0.12, 0.15, 0.12), 2.0)
		
		# 6. Canine Head, Ears & Jaws
		var head_pos = Vector2(13.0, -6.0 - spine_flex)
		var head_size = Vector2(9, 8) if breed == "rottweiler" or breed == "mastiff" else Vector2(7, 7)
		draw_rect(Rect2(head_pos.x - 3, head_pos.y - 4, head_size.x, head_size.y), coat_primary)
		draw_rect(Rect2(head_pos.x + 1.0, head_pos.y - 3, 6, 4), coat_accent if breed != "mastiff" else bone_col)
		
		# Jaws & Fangs
		var jaw_x = head_pos.x + 2.0
		var jaw_w = 7.0 if breed == "rottweiler" or breed == "mastiff" else 5.0
		draw_rect(Rect2(jaw_x, head_pos.y + 1, jaw_w, 4), Color(0.55, 0.08, 0.08))
		draw_line(Vector2(jaw_x + 1, head_pos.y + 1), Vector2(jaw_x + 1, head_pos.y + 5), Color(0.95, 0.95, 0.9), 1.8)
		draw_line(Vector2(jaw_x + 4, head_pos.y + 1), Vector2(jaw_x + 4, head_pos.y + 5), Color(0.95, 0.95, 0.9), 1.8)
		if breed == "mastiff":
			draw_circle(Vector2(jaw_x + 3, head_pos.y + 6), 1.5, Color(0.85, 0.1, 0.1)) # Dripping blood
		else:
			draw_circle(Vector2(jaw_x + 3, head_pos.y + 5), 1.2, Color(0.2, 0.95, 0.3)) # Toxic saliva
		
		# Glowing Eye
		var eye_x: float = head_pos.x
		draw_rect(Rect2(eye_x, head_pos.y - 3, 3, 2), eye_col)
		draw_rect(Rect2(eye_x + 1, head_pos.y - 3, 1, 1), Color(1.0, 1.0, 0.8))
		
		# Ears by breed
		match breed:
			"doberman": # Tall sharp pointed docked ears
				draw_line(Vector2(head_pos.x - 2, head_pos.y - 4), Vector2(head_pos.x - 5, head_pos.y - 11), coat_primary, 2.5)
				draw_line(Vector2(head_pos.x + 1, head_pos.y - 4), Vector2(head_pos.x - 1, head_pos.y - 10), coat_primary, 2.0)
			"rottweiler": # Cropped folded ears
				draw_rect(Rect2(head_pos.x - 4, head_pos.y - 5, 4, 3), coat_primary)
			"shepherd": # Large triangular upright wolf ears
				draw_line(Vector2(head_pos.x - 3, head_pos.y - 4), Vector2(head_pos.x - 5, head_pos.y - 10), coat_primary, 3.0)
				draw_line(Vector2(head_pos.x - 1, head_pos.y - 4), Vector2(head_pos.x - 2, head_pos.y - 9), coat_accent, 2.0)
			"mastiff": # Skeletal bone crests on skull
				draw_line(Vector2(head_pos.x - 3, head_pos.y - 4), Vector2(head_pos.x - 7, head_pos.y - 9), bone_col, 2.5)
		
		# 7. Tail by breed
		var tail_whip = sin(anim_time * 16.0) * 3.0
		var tail_root = Vector2(-14.0, -4.0 + spine_flex)
		match breed:
			"doberman", "rottweiler": # Short docked tail
				draw_line(tail_root, tail_root + Vector2(-3.0, -5.0 + tail_whip * 0.4), coat_primary, 3.0)
			"shepherd": # Long bushy ragged tail
				draw_line(tail_root, tail_root + Vector2(-7.0, -5.0 + tail_whip), coat_accent, 3.0)
				draw_line(tail_root + Vector2(-7.0, -5.0 + tail_whip), tail_root + Vector2(-13.0, -2.0 + tail_whip * 1.4), coat_primary, 2.5)
			"mastiff": # Barbed skeletal whip tail
				draw_line(tail_root, tail_root + Vector2(-8.0, -7.0 + tail_whip), bone_col, 2.5)
				draw_line(tail_root + Vector2(-8.0, -7.0 + tail_whip), tail_root + Vector2(-14.0, -4.0 + tail_whip * 1.5), bone_col, 2.0)
				draw_circle(tail_root + Vector2(-14.0, -4.0 + tail_whip * 1.5), 2.0, Color(0.9, 0.2, 0.2))
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			if body.is_dashing or body.slash_timer > 0.0 or body.is_sliding or (body.get("is_shapeshifted") == true):
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


class CyberShard extends Area2D:
	var bob_time: float = 0.0
	var base_y: float = 0.0
	
	func _init() -> void:
		add_to_group("shards")
		collision_layer = 4
		collision_mask = 1
	
	func _ready() -> void:
		base_y = position.y
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 12.0
		col.shape = shape
		add_child(col)
		body_entered.connect(_on_body_entered)
	
	func _process(delta: float) -> void:
		bob_time += delta
		position.y = base_y + sin(bob_time * 6.0) * 4.0
		queue_redraw()
	
	func _draw() -> void:
		# Glowing Cyber Shard diamond
		var pts = PackedVector2Array([
			Vector2(0, -9),
			Vector2(7, 0),
			Vector2(0, 9),
			Vector2(-7, 0)
		])
		draw_colored_polygon(pts, Color(0.0, 0.95, 1.0, 0.85))
		draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95), 1.5)
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 0.5))
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			if body.has_method("refund_dash_pip"):
				body.refund_dash_pip()
			# Spawn collection burst
			var emitter = CPUParticles2D.new()
			emitter.emitting = true
			emitter.one_shot = true
			emitter.explosiveness = 0.95
			emitter.lifetime = 0.35
			emitter.amount = 14
			emitter.direction = Vector2(0, -1)
			emitter.spread = 180.0
			emitter.initial_velocity_min = 60.0
			emitter.initial_velocity_max = 160.0
			emitter.color = Color(0.1, 0.95, 1.0)
			get_parent().add_child(emitter)
			emitter.global_position = global_position
			emitter.finished.connect(emitter.queue_free)
			queue_free()


class NeonBooster extends Area2D:
	var boost_width: float = 90.0
	var boost_height: float = 10.0
	var anim_pulse: float = 0.0
	
	func _init(w: float = 90.0) -> void:
		boost_width = w
		add_to_group("boosters")
		collision_layer = 4
		collision_mask = 1
	
	func _ready() -> void:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(boost_width, boost_height)
		col.shape = shape
		col.position = Vector2(boost_width / 2.0, boost_height / 2.0)
		add_child(col)
		body_entered.connect(_on_body_entered)
	
	func _process(delta: float) -> void:
		anim_pulse += delta * 8.0
		queue_redraw()
	
	func _draw() -> void:
		# Glowing cyan boost pad recessed into floor
		draw_rect(Rect2(0, 0, boost_width, boost_height), Color(0.0, 0.45, 0.65, 0.7))
		draw_rect(Rect2(2, 2, boost_width - 4, boost_height - 4), Color(0.06, 0.12, 0.18))
		# Animated speed chevrons >>>
		var step = 20.0
		var count = int(boost_width / step)
		for i in range(count):
			var cx = 8.0 + i * step + fmod(anim_pulse * 4.0, step)
			if cx < boost_width - 8.0:
				draw_line(Vector2(cx, 2), Vector2(cx + 6, boost_height / 2.0), Color(0.0, 0.95, 1.0, 0.95), 2.5)
				draw_line(Vector2(cx + 6, boost_height / 2.0), Vector2(cx, boost_height - 2), Color(0.0, 0.95, 1.0, 0.95), 2.5)
	
	func _on_body_entered(body: Node2D) -> void:
		if body is RunnerController:
			body.velocity.x += body.facing * 240.0
			var emitter = CPUParticles2D.new()
			emitter.emitting = true
			emitter.one_shot = true
			emitter.explosiveness = 0.9
			emitter.lifetime = 0.35
			emitter.amount = 16
			emitter.direction = Vector2(body.facing, -0.2)
			emitter.spread = 30.0
			emitter.initial_velocity_min = 140.0
			emitter.initial_velocity_max = 300.0
			emitter.color = Color(0.0, 0.95, 1.0)
			get_parent().add_child(emitter)
			emitter.global_position = global_position + Vector2(boost_width / 2.0, 0)
			emitter.finished.connect(emitter.queue_free)
