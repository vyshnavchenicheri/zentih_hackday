extends CharacterBody2D
class_name RunnerController

## Game State Machine
enum GameState {
	SKYFALL,
	TITLE_MENU,
	PLAYING,
	DEAD
}

## Signals for HUD and Game Systems
signal speed_updated(kmh: float)
signal dash_pips_changed(current: int, max_pips: int)
signal hp_changed(current_hp: float)
signal zone_tier_changed(tier_name: String)
signal jumps_changed(jumps_left: int, max_jumps: int)
signal distance_updated(meters: int)
signal shapeshift_changed(is_dog: bool)
signal area_changed(area_id: int, area_name: String)

signal game_state_changed(new_state: int)
signal dash_cooldown_updated(remaining: float, total: float)
signal slide_cooldown_updated(remaining: float, total: float)
signal double_jump_cooldown_updated(remaining: float, total: float)
signal dog_kills_updated(current: int, required: int)
signal retreat_updated(current_retreat_m: float, max_retreat_m: float)
signal player_died(cause: String, distance_m: int, dog_kills: int)
signal hero_landed()
signal action_rejected(msg: String)
signal action_unlocked(msg: String)

@export_group("Game State")
@export var game_state: GameState = GameState.SKYFALL
var is_dead: bool = false
var cause_of_death: String = ""
var landing_crouch_timer: float = 0.0

@export_group("Snappy Movement (No Momentum Drift)")
@export var run_speed: float = 400.0          # Fixed, crisp running speed
@export var jump_force: float = -620.0        # First jump impulse
@export var double_jump_force: float = -560.0 # Double jump impulse to easily reach top platforms
@export var gravity: float = 1600.0
@export var max_jumps: int = 2 # Double jump enabled

@export_group("Mechanic Cooldowns")
@export var dash_cooldown: float = 1.0        # 1.0s cooldown
var dash_cooldown_timer: float = 0.0
@export var slide_cooldown: float = 1.0       # 1.0s cooldown
var slide_cooldown_timer: float = 0.0
@export var double_jump_cooldown: float = 3.0 # 3.0s cooldown
var double_jump_cooldown_timer: float = 0.0

@export_group("Momentary Thruster Dash")
@export var dash_speed: float = 1200.0        # High burst speed during dash
@export var dash_duration: float = 0.18       # Momentary burst duration (NOT infinite)
@export var max_dash_pips: int = 3
@export var dash_pip_cooldown: float = 1.2    # Time to recharge 1 pip

@export_group("Slide Mechanics")
@export var slide_speed: float = 650.0        # Initial high-speed slide
@export var slide_duration: float = 0.44      # Slide duration
var is_sliding: bool = false
var slide_timer: float = 0.0

@export_group("Wall Jump & Wall Slide")
@export var wall_slide_max_speed: float = 160.0 # Slow controlled descent against wall
@export var wall_jump_force_y: float = -640.0    # Vertical kick impulse
@export var wall_jump_force_x: float = 460.0    # Horizontal push impulse away from wall
var is_wall_sliding: bool = false
var last_wall_normal: Vector2 = Vector2.ZERO
var wall_coyote_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0

@export_group("Shapeshifting & Dog Hunt Unlock")
var is_shapeshifted: bool = false             # Cyber Hound Form
var dogs_killed: int = 0
const DOGS_REQUIRED_FOR_SHAPESHIFT: int = 10

@export_group("Retreat Boundary Tracker")
var max_forward_x: float = 160.0
var retreat_distance_meters: float = 0.0
const MAX_RETREAT_METERS: float = 1000.0

# Camera Cinematic Zoom & Impact Shake
var target_zoom: Vector2 = Vector2(1.85, 1.85) # Up close for dramatic skyfall & landing
var trauma: float = 0.0

# Player State
var facing: int = 1
var jumps_left: int = 2
var preview_idle: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var slash_timer: float = 0.0
var pip_recharge_timer: float = 0.0
var current_hp: float = 100.0
var dash_pips: int = 3
var run_cycle: float = 0.0
var invulnerable_timer: float = 0.0
var current_area_id: int = -1

const AREA_NAMES = [
	"AREA 1: NEO-CYBER HIGHWAY",
	"AREA 2: TWILIGHT VIOLET FOREST",
	"AREA 3: CRIMSON BLOODWOODS",
	"AREA 4: AMBER EMBER FOREST",
	"AREA 5: GOLDEN SYLVAN SANCTUARY",
	"AREA 6: MEGASTRUCTURE CORE RUINS"
]

# Node References
@onready var visuals: Node2D = $Visuals if has_node("Visuals") else null
@onready var slash_area: Area2D = $SlashArea if has_node("SlashArea") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null

func _ready() -> void:
	# Configure snappy slope handling on CharacterBody2D
	floor_constant_speed = true
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(45.0)
	
	if camera:
		camera.zoom = Vector2(1.85, 1.85) # Start up-close for skyfall
	
	max_forward_x = global_position.x
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)
	emit_signal("hp_changed", current_hp)
	emit_signal("jumps_changed", jumps_left, max_jumps)
	emit_signal("shapeshift_changed", is_shapeshifted)
	emit_signal("dog_kills_updated", dogs_killed, DOGS_REQUIRED_FOR_SHAPESHIFT)
	emit_signal("dash_cooldown_updated", dash_cooldown_timer, dash_cooldown)
	emit_signal("slide_cooldown_updated", slide_cooldown_timer, slide_cooldown)
	emit_signal("double_jump_cooldown_updated", double_jump_cooldown_timer, double_jump_cooldown)
	emit_signal("game_state_changed", game_state)
	check_area_transition()
	
	if col_shape and col_shape.shape:
		col_shape.shape = col_shape.shape.duplicate()
	
	if slash_area:
		slash_area.monitoring = false
		if not slash_area.area_entered.is_connected(_on_slash_area_entered):
			slash_area.area_entered.connect(_on_slash_area_entered)
		if not slash_area.body_entered.is_connected(_on_slash_body_entered):
			slash_area.body_entered.connect(_on_slash_body_entered)

func _process(delta: float) -> void:
	# Smooth camera zoom transition
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, delta * 3.5)
		
		# Screen shake decay
		if trauma > 0.0:
			trauma = max(0.0, trauma - delta * 2.2)
			var shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * trauma * 16.0
			camera.offset = shake_offset
		elif camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	match game_state:
		GameState.SKYFALL:
			_process_skyfall(delta)
			return
		GameState.TITLE_MENU:
			_process_title_menu(delta)
			return
		GameState.DEAD:
			_process_dead(delta)
			return
		GameState.PLAYING:
			_process_playing(delta)

func _process_skyfall(delta: float) -> void:
	velocity.x = 0.0
	velocity.y += gravity * delta
	move_and_slide()
	
	if is_on_floor():
		# Skyfall Hero Landing Impact!
		velocity = Vector2.ZERO
		game_state = GameState.TITLE_MENU
		landing_crouch_timer = 0.65
		trauma = 0.85 # Strong screen shake on impact
		spawn_hero_landing_particles()
		emit_signal("hero_landed")
		emit_signal("game_state_changed", game_state)
	
	if visuals:
		visuals.queue_redraw()

func _process_title_menu(delta: float) -> void:
	velocity = Vector2.ZERO
	if landing_crouch_timer > 0.0:
		landing_crouch_timer -= delta
	if visuals:
		visuals.queue_redraw()

func _process_dead(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	if visuals:
		visuals.queue_redraw()

func _process_playing(delta: float) -> void:
	recharge_dash_pips(delta)
	handle_invulnerability(delta)
	
	# Update cooldown timers
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
		emit_signal("dash_cooldown_updated", dash_cooldown_timer, dash_cooldown)
	
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer = max(0.0, slide_cooldown_timer - delta)
		emit_signal("slide_cooldown_updated", slide_cooldown_timer, slide_cooldown)
	
	if double_jump_cooldown_timer > 0.0:
		double_jump_cooldown_timer = max(0.0, double_jump_cooldown_timer - delta)
		emit_signal("double_jump_cooldown_updated", double_jump_cooldown_timer, double_jump_cooldown)
	
	# Backwards retreat tracking (physical horde awaits at 1000M)
	if global_position.x > max_forward_x:
		max_forward_x = global_position.x
	retreat_distance_meters = max(0.0, (max_forward_x - global_position.x) / 10.0)
	emit_signal("retreat_updated", retreat_distance_meters, MAX_RETREAT_METERS)
	
	var active_run_speed: float = run_speed * (1.5 if is_shapeshifted else 1.0)
	var active_slide_speed: float = slide_speed * (1.5 if is_shapeshifted else 1.0)
	
	if is_dashing:
		# In momentary dash
		dash_timer -= delta
		velocity.x = facing * dash_speed
		velocity.y = 0.0 # Lock vertical drop during dash
		
		if dash_timer <= 0.0:
			is_dashing = false
			if slash_area and not is_shapeshifted:
				slash_area.monitoring = false
			var input_x: float = get_horizontal_input()
			velocity.x = input_x * active_run_speed
	elif is_sliding:
		# In cyber slide
		slide_timer -= delta
		velocity.x = facing * lerpf(active_run_speed, active_slide_speed, max(0.0, slide_timer) / slide_duration)
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			if velocity.y >= 0.0:
				jumps_left = max_jumps
		
		# If slide timer ran out:
		if slide_timer <= 0.0:
			if has_ceiling_above():
				# Under low obstacle: DO NOT STAND UP! Coast through in crouch at run speed
				velocity.x = facing * active_run_speed
				set_crouch_collision(true)
			else:
				end_slide()
	else:
		# Wall slide & Normal gravity
		if not is_on_floor():
			if is_on_wall() and velocity.y > 0.0:
				# Wall slide friction: slide down at gentle controlled speed
				is_wall_sliding = true
				velocity.y = min(velocity.y + gravity * delta * 0.35, wall_slide_max_speed)
				if randf() > 0.65:
					spawn_wall_sparks(last_wall_normal)
			else:
				is_wall_sliding = false
				velocity.y += gravity * delta
		else:
			is_wall_sliding = false
			wall_coyote_timer = 0.0
			# Only reset jump when falling downward or settled on floor
			if velocity.y >= 0.0:
				jumps_left = 0 if is_shapeshifted else max_jumps
				emit_signal("jumps_changed", jumps_left, max_jumps)
		
		# Running Input (with wall kick steering lock)
		if wall_jump_lock_timer > 0.0:
			wall_jump_lock_timer -= delta
			var input_x: float = get_horizontal_input()
			if input_x != 0.0 and sign(input_x) == sign(velocity.x):
				velocity.x = sign(velocity.x) * max(abs(velocity.x), active_run_speed)
		else:
			var input_x: float = get_horizontal_input()
			if input_x != 0.0:
				facing = 1 if input_x > 0 else -1
				velocity.x = input_x * active_run_speed
			else:
				velocity.x = 0.0 # Immediate crisp stop (no slippery inertia)
	
	if slash_timer > 0.0:
		slash_timer -= delta
	
	# Continuous Shredder aura in Dog Form: destroys any zombie touched
	if is_shapeshifted:
		if slash_area:
			slash_area.monitoring = true
			slash_area.position = Vector2(facing * 8.0, 6.0)
			for area in slash_area.get_overlapping_areas():
				if area.is_in_group("enemies"):
					if area.has_method("die_cleaved"):
						area.die_cleaved()
					else:
						area.queue_free()
				elif area.is_in_group("barricades"):
					if area.has_method("shatter"):
						area.shatter()
					elif area.get_parent() and area.get_parent().has_method("shatter"):
						area.get_parent().shatter()
	
	# Failsafe: Never get wedged or stuck under low overhead obstacles!
	if has_ceiling_above() and is_on_floor():
		if not is_sliding and not is_shapeshifted:
			is_sliding = true
			slide_timer = slide_duration
			set_crouch_collision(true)
		if abs(velocity.x) < 50.0:
			velocity.x = facing * active_run_speed
	
	move_and_slide()
	
	# Wall contact memory for coyote wall jumping
	if is_on_wall() and not is_on_floor():
		last_wall_normal = get_wall_normal()
		wall_coyote_timer = 0.16
	elif wall_coyote_timer > 0.0:
		wall_coyote_timer -= delta
	
	# Check direct collisions when moving in dog form to instantly cleave enemies or barricades
	if is_shapeshifted:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var collider = col.get_collider()
			if collider:
				if collider.is_in_group("enemies"):
					if collider.has_method("die_cleaved"):
						collider.die_cleaved()
					else:
						collider.queue_free()
				elif collider.is_in_group("barricades"):
					if collider.has_method("shatter"):
						collider.shatter()
					else:
						collider.queue_free()
	
	# Update animation cycle
	if abs(velocity.x) > 0.0 and not is_sliding:
		run_cycle += delta * (20.0 if is_shapeshifted else 14.0)
	
	if visuals:
		visuals.queue_redraw()
	
	update_hud_signals()
	check_zone_tier()

func get_horizontal_input() -> float:
	if game_state != GameState.PLAYING:
		return 0.0
	var x: float = Input.get_axis("move_left", "move_right")
	if x != 0.0:
		return sign(x)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1.0
	return clampf(x, -1.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.TITLE_MENU:
		if (event is InputEventKey and event.pressed and not event.is_echo()) or (event is InputEventMouseButton and event.pressed):
			start_game()
		return
	
	if game_state == GameState.DEAD:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_R:
				restart_game()
			elif event.keycode == KEY_M or event.keycode == KEY_ESCAPE:
				return_to_main_menu()
		return
	
	if game_state != GameState.PLAYING:
		return
	
	if event.is_action_pressed("jump") and not event.is_echo():
		trigger_jump()
	elif event.is_action_pressed("dash") and not event.is_echo():
		trigger_momentary_dash()
	elif (event.is_action_pressed("move_down") or (event is InputEventKey and event.pressed and not event.is_echo() and (event.keycode == KEY_S or event.keycode == KEY_DOWN))):
		trigger_slide()
	elif event.is_action_pressed("shapeshift") or (event is InputEventKey and event.pressed and not event.is_echo() and (event.keycode == KEY_Q or event.keycode == KEY_E or event.keycode == KEY_C or event.keycode == KEY_SHIFT)):
		toggle_shapeshift()
	elif event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		restart_game()

func start_game() -> void:
	if game_state == GameState.PLAYING:
		return
	game_state = GameState.PLAYING
	target_zoom = Vector2(1.15, 1.15) # Smoothly zoom out to standard gameplay view!
	emit_signal("game_state_changed", game_state)
	emit_signal("dash_cooldown_updated", dash_cooldown_timer, dash_cooldown)
	emit_signal("slide_cooldown_updated", slide_cooldown_timer, slide_cooldown)
	emit_signal("double_jump_cooldown_updated", double_jump_cooldown_timer, double_jump_cooldown)
	emit_signal("dog_kills_updated", dogs_killed, DOGS_REQUIRED_FOR_SHAPESHIFT)

func restart_game() -> void:
	get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	get_tree().reload_current_scene()

func register_dog_kill() -> void:
	dogs_killed += 1
	emit_signal("dog_kills_updated", dogs_killed, DOGS_REQUIRED_FOR_SHAPESHIFT)
	if dogs_killed == DOGS_REQUIRED_FOR_SHAPESHIFT:
		emit_signal("action_unlocked", "HOUND FORM UNLOCKED! PRESS [Q]")

func can_shapeshift() -> bool:
	return dogs_killed >= DOGS_REQUIRED_FOR_SHAPESHIFT

func toggle_shapeshift() -> void:
	if game_state != GameState.PLAYING:
		return
	if is_sliding and has_ceiling_above():
		return
	
	if not is_shapeshifted and not can_shapeshift():
		emit_signal("action_rejected", "HOUND FORM LOCKED: HUNT %d/%d HOUNDS" % [dogs_killed, DOGS_REQUIRED_FOR_SHAPESHIFT])
		return
	
	is_shapeshifted = not is_shapeshifted
	if is_sliding:
		end_slide()
	if is_shapeshifted:
		jumps_left = 0
	else:
		if is_on_floor():
			jumps_left = max_jumps
	set_crouch_collision(is_sliding)
	spawn_transform_particles()
	emit_signal("shapeshift_changed", is_shapeshifted)
	emit_signal("jumps_changed", jumps_left, max_jumps)
	if visuals:
		visuals.queue_redraw()

func can_wall_jump() -> bool:
	return (is_on_wall() or wall_coyote_timer > 0.0) and not is_on_floor()

func perform_wall_jump() -> void:
	var push_norm_x: float = last_wall_normal.x
	if push_norm_x == 0.0:
		push_norm_x = -float(facing)
	
	var push_dir: float = sign(push_norm_x)
	var jump_mult: float = sqrt(1.5) if is_shapeshifted else 1.0
	
	velocity.x = push_dir * wall_jump_force_x * (1.15 if is_shapeshifted else 1.0)
	velocity.y = wall_jump_force_y * jump_mult
	facing = int(push_dir)
	wall_coyote_timer = 0.0
	wall_jump_lock_timer = 0.18
	is_wall_sliding = false
	
	jumps_left = 0 if is_shapeshifted else max_jumps - 1
	emit_signal("jumps_changed", jumps_left, max_jumps)
	
	spawn_wall_jump_particles(last_wall_normal)
	if visuals:
		visuals.queue_redraw()

func has_ceiling_above() -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	var offsets = [-9.0, 0.0, 9.0]
	for ox in offsets:
		var from_pos = global_position + Vector2(ox, 2.0)
		var to_pos = global_position + Vector2(ox, -26.0)
		var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1) # Environment
		query.exclude = [get_rid()]
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			return true
	return false

func trigger_jump() -> void:
	if game_state != GameState.PLAYING:
		return
	if is_sliding:
		if has_ceiling_above():
			return
		end_slide()
	
	if can_wall_jump():
		perform_wall_jump()
		return
	
	var jump_mult: float = sqrt(1.5) if is_shapeshifted else 1.0
	
	if is_on_floor():
		velocity.y = jump_force * jump_mult
		jumps_left = 0 if is_shapeshifted else max_jumps - 1
		emit_signal("jumps_changed", jumps_left, max_jumps)
		spawn_jump_particles()
	elif jumps_left > 0 and not is_shapeshifted:
		if double_jump_cooldown_timer > 0.0:
			emit_signal("action_rejected", "AIR JUMP COOLDOWN: %.1fs" % double_jump_cooldown_timer)
			return
		
		velocity.y = double_jump_force
		jumps_left -= 1
		double_jump_cooldown_timer = double_jump_cooldown # 3.0s cooldown
		emit_signal("double_jump_cooldown_updated", double_jump_cooldown_timer, double_jump_cooldown)
		emit_signal("jumps_changed", jumps_left, max_jumps)
		spawn_double_jump_particles()

func trigger_slide() -> void:
	if game_state != GameState.PLAYING:
		return
	if not is_on_floor() or is_dashing or is_sliding or is_shapeshifted:
		return
	# 1.0s slide cooldown
	if slide_cooldown_timer > 0.0:
		emit_signal("action_rejected", "SLIDE COOLDOWN: %.1fs" % slide_cooldown_timer)
		return
	
	slide_cooldown_timer = slide_cooldown
	emit_signal("slide_cooldown_updated", slide_cooldown_timer, slide_cooldown)
	
	is_sliding = true
	slide_timer = slide_duration
	velocity.x = facing * slide_speed
	set_crouch_collision(true)
	spawn_slide_sparks()

func end_slide() -> void:
	if not is_sliding:
		return
	if has_ceiling_above():
		return
	is_sliding = false
	slide_timer = 0.0
	set_crouch_collision(false)

func set_crouch_collision(crouching: bool) -> void:
	if not col_shape:
		col_shape = $CollisionShape2D if has_node("CollisionShape2D") else null
	if col_shape and col_shape.shape is RectangleShape2D:
		if is_shapeshifted:
			if crouching:
				col_shape.shape.size = Vector2(30, 14)
				col_shape.position = Vector2(0, 11)
			else:
				col_shape.shape.size = Vector2(32, 20)
				col_shape.position = Vector2(0, 8)
		else:
			if crouching:
				col_shape.shape.size = Vector2(28, 16)
				col_shape.position = Vector2(0, 10)
			else:
				col_shape.shape.size = Vector2(20, 36)
				col_shape.position = Vector2(0, 0)

func trigger_momentary_dash() -> void:
	if game_state != GameState.PLAYING:
		return
	# 1.0s dash cooldown
	if dash_cooldown_timer > 0.0:
		emit_signal("action_rejected", "DASH COOLDOWN: %.1fs" % dash_cooldown_timer)
		return
	if is_dashing or dash_pips <= 0:
		return
	if is_sliding:
		if has_ceiling_above():
			return
		end_slide()
	
	dash_pips -= 1
	dash_cooldown_timer = dash_cooldown # 1.0s cooldown
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)
	emit_signal("dash_cooldown_updated", dash_cooldown_timer, dash_cooldown)
	
	is_dashing = true
	dash_timer = dash_duration
	slash_timer = dash_duration + 0.06
	velocity.x = facing * dash_speed * (1.2 if is_shapeshifted else 1.0)
	velocity.y = 0.0
	
	if slash_area:
		slash_area.monitoring = true
		slash_area.position.x = facing * 25.0
	
	spawn_dash_particles()

func recharge_dash_pips(delta: float) -> void:
	if dash_pips < max_dash_pips:
		pip_recharge_timer += delta
		if pip_recharge_timer >= dash_pip_cooldown:
			dash_pips += 1
			pip_recharge_timer = 0.0
			emit_signal("dash_pips_changed", dash_pips, max_dash_pips)

func handle_invulnerability(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if visuals:
			visuals.modulate.a = 0.4 if int(invulnerable_timer * 20.0) % 2 == 0 else 1.0
	else:
		if visuals:
			visuals.modulate.a = 1.0

func take_damage(amount: float, knockback_dir: float = 0.0) -> void:
	# No damage during SKYFALL or TITLE_MENU!
	if game_state != GameState.PLAYING:
		return
	if is_dead or invulnerable_timer > 0.0 or is_dashing or is_sliding or is_shapeshifted:
		return
	
	current_hp = max(0.0, current_hp - amount)
	invulnerable_timer = 0.8
	velocity.x = (knockback_dir if knockback_dir != 0.0 else -facing) * 300.0
	velocity.y = -260.0
	emit_signal("hp_changed", current_hp)
	
	if current_hp <= 0.0:
		die("HULL INTEGRITY COMPROMISED")

func die(reason: String = "CRITICAL DAMAGE") -> void:
	if is_dead:
		return
	is_dead = true
	game_state = GameState.DEAD
	cause_of_death = reason
	velocity.x = -facing * 220.0
	velocity.y = -340.0
	emit_signal("player_died", cause_of_death, int(global_position.x / 10.0), dogs_killed)
	emit_signal("game_state_changed", game_state)
	spawn_death_particles()
	if visuals:
		visuals.queue_redraw()

func refund_dash_pip() -> void:
	dash_pips = min(max_dash_pips, dash_pips + 1)
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)

func update_hud_signals() -> void:
	var kmh: float = 450.0 if is_dashing else (180.0 if abs(velocity.x) > 0.0 else 0.0)
	emit_signal("speed_updated", kmh)
	emit_signal("distance_updated", int(global_position.x / 10.0))
	check_area_transition()

func check_area_transition() -> void:
	var raw_idx: int = int(floor(global_position.x / 3600.0)) % 6
	if raw_idx < 0:
		raw_idx += 6
	if raw_idx != current_area_id:
		current_area_id = raw_idx
		emit_signal("area_changed", current_area_id, AREA_NAMES[current_area_id])

func check_zone_tier() -> void:
	if global_position.y < -70.0:
		emit_signal("zone_tier_changed", "TIER 1: HIGH CATWALK")
	elif global_position.y < 100.0:
		emit_signal("zone_tier_changed", "TIER 2: HIGHWAY DECK")
	else:
		emit_signal("zone_tier_changed", "TIER 3: TOXIC CANALS")

func _on_slash_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("die_cleaved"):
			area.die_cleaved()
		else:
			area.queue_free()
		refund_dash_pip()
	elif area.is_in_group("barricades"):
		if area.has_method("shatter"):
			area.shatter()
		else:
			area.get_parent().queue_free()

func _on_slash_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("die_cleaved"):
			body.die_cleaved()
		else:
			body.queue_free()
		refund_dash_pip()
	elif body.is_in_group("barricades"):
		if body.has_method("shatter"):
			body.shatter()
		else:
			body.queue_free()

func spawn_hero_landing_particles() -> void:
	# Heavy ground impact shockwave & sparks
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.lifetime = 0.65
	emitter.amount = 40
	emitter.explosiveness = 0.98
	emitter.direction = Vector2(0, -1)
	emitter.spread = 85.0
	emitter.initial_velocity_min = 160.0
	emitter.initial_velocity_max = 340.0
	emitter.color = Color(0.0, 0.95, 1.0)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(0, 16)
	emitter.finished.connect(emitter.queue_free)
	
	# Horizontal dirt/metal blast along floor left and right
	for dir_x in [-1.0, 1.0]:
		var side_emit = CPUParticles2D.new()
		side_emit.emitting = true
		side_emit.one_shot = true
		side_emit.lifetime = 0.45
		side_emit.amount = 16
		side_emit.explosiveness = 0.95
		side_emit.direction = Vector2(dir_x, -0.2)
		side_emit.spread = 30.0
		side_emit.initial_velocity_min = 120.0
		side_emit.initial_velocity_max = 240.0
		side_emit.color = Color(1.0, 0.75, 0.2)
		get_parent().add_child(side_emit)
		side_emit.global_position = global_position + Vector2(0, 16)
		side_emit.finished.connect(side_emit.queue_free)

func spawn_double_jump_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.lifetime = 0.35
	emitter.amount = 20
	emitter.direction = Vector2(0, 1)
	emitter.spread = 80.0
	emitter.initial_velocity_min = 80.0
	emitter.initial_velocity_max = 200.0
	emitter.color = Color(0.0, 1.0, 0.8)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(0, 18)
	emitter.finished.connect(emitter.queue_free)

func spawn_death_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.lifetime = 0.7
	emitter.amount = 40
	emitter.direction = Vector2(0, -1)
	emitter.spread = 180.0
	emitter.initial_velocity_min = 90.0
	emitter.initial_velocity_max = 300.0
	emitter.color = Color(1.0, 0.2, 0.2)
	get_parent().add_child(emitter)
	emitter.global_position = global_position
	emitter.finished.connect(emitter.queue_free)

func spawn_dash_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.lifetime = 0.35
	emitter.amount = 16
	emitter.direction = Vector2(-facing, 0)
	emitter.spread = 45.0
	emitter.initial_velocity_min = 120.0
	emitter.initial_velocity_max = 280.0
	emitter.color = Color(0.0, 0.94, 1.0)
	get_parent().add_child(emitter)
	emitter.global_position = global_position
	emitter.finished.connect(emitter.queue_free)

func spawn_jump_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.lifetime = 0.25
	emitter.amount = 8
	emitter.direction = Vector2(0, 1)
	emitter.spread = 60.0
	emitter.initial_velocity_min = 40.0
	emitter.initial_velocity_max = 90.0
	emitter.color = Color(0.2, 0.8, 1.0)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(0, 18)
	emitter.finished.connect(emitter.queue_free)

func spawn_slide_sparks() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.85
	emitter.lifetime = 0.35
	emitter.amount = 12
	emitter.direction = Vector2(-facing, -0.4)
	emitter.spread = 45.0
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 160.0
	emitter.color = Color(1.0, 0.72, 0.2)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(0, 16)
	emitter.finished.connect(emitter.queue_free)

func spawn_wall_sparks(norm: Vector2) -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.lifetime = 0.2
	emitter.amount = 5
	var norm_x = norm.x if norm.x != 0.0 else -float(facing)
	emitter.direction = Vector2(norm_x, -0.6).normalized()
	emitter.spread = 35.0
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 120.0
	emitter.color = Color(1.0, 0.8, 0.2)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(-norm_x * 8.0, 4.0)
	emitter.finished.connect(emitter.queue_free)

func spawn_wall_jump_particles(norm: Vector2) -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.lifetime = 0.35
	emitter.amount = 16
	var norm_x = norm.x if norm.x != 0.0 else -float(facing)
	emitter.direction = Vector2(norm_x, -0.7).normalized()
	emitter.spread = 45.0
	emitter.initial_velocity_min = 120.0
	emitter.initial_velocity_max = 240.0
	emitter.color = Color(0.0, 0.95, 1.0) if is_shapeshifted else Color(0.95, 0.6, 0.1)
	get_parent().add_child(emitter)
	emitter.global_position = global_position + Vector2(-norm_x * 10.0, 0.0)
	emitter.finished.connect(emitter.queue_free)

func spawn_transform_particles() -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = true
	emitter.one_shot = true
	emitter.lifetime = 0.4
	emitter.amount = 32
	emitter.explosiveness = 0.95
	emitter.spread = 180.0
	emitter.initial_velocity_min = 140.0
	emitter.initial_velocity_max = 260.0
	emitter.color = Color(0.0, 0.95, 1.0) if is_shapeshifted else Color(0.95, 0.6, 0.1)
	get_parent().add_child(emitter)
	emitter.global_position = global_position
	emitter.finished.connect(emitter.queue_free)
