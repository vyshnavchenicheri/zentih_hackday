extends CharacterBody2D
class_name RunnerController

## Signals for HUD and Game Systems
signal speed_updated(kmh: float)
signal dash_pips_changed(current: int, max_pips: int)
signal hp_changed(current_hp: float)
signal zone_tier_changed(tier_name: String)
signal jumps_changed(jumps_left: int, max_jumps: int)
signal distance_updated(meters: int)

@export_group("Snappy Movement (No Momentum Drift)")
@export var run_speed: float = 400.0          # Fixed, crisp running speed
@export var jump_force: float = -620.0        # First jump impulse
@export var double_jump_force: float = -560.0 # Double jump impulse to easily reach top platforms
@export var gravity: float = 1600.0
@export var max_jumps: int = 2 # Double jump enabled

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

# Player State
var facing: int = 1
var jumps_left: int = 2
var is_dashing: bool = false
var dash_timer: float = 0.0
var slash_timer: float = 0.0
var pip_recharge_timer: float = 0.0
var current_hp: float = 100.0
var dash_pips: int = 3
var run_cycle: float = 0.0
var invulnerable_timer: float = 0.0

# Node References
@onready var visuals: Node2D = $Visuals if has_node("Visuals") else null
@onready var slash_area: Area2D = $SlashArea if has_node("SlashArea") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)
	emit_signal("hp_changed", current_hp)
	emit_signal("jumps_changed", jumps_left, max_jumps)
	
	if col_shape and col_shape.shape:
		col_shape.shape = col_shape.shape.duplicate()
	
	if slash_area:
		slash_area.monitoring = false
		if not slash_area.area_entered.is_connected(_on_slash_area_entered):
			slash_area.area_entered.connect(_on_slash_area_entered)
		if not slash_area.body_entered.is_connected(_on_slash_body_entered):
			slash_area.body_entered.connect(_on_slash_body_entered)

func _physics_process(delta: float) -> void:
	recharge_dash_pips(delta)
	handle_invulnerability(delta)
	
	if is_dashing:
		# In momentary dash
		dash_timer -= delta
		velocity.x = facing * dash_speed
		velocity.y = 0.0 # Lock vertical drop during dash
		
		if dash_timer <= 0.0:
			is_dashing = false
			if slash_area:
				slash_area.monitoring = false
			var input_x: float = get_horizontal_input()
			velocity.x = input_x * run_speed
	elif is_sliding:
		# In cyber slide
		slide_timer -= delta
		velocity.x = facing * lerpf(run_speed, slide_speed, slide_timer / slide_duration)
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			if velocity.y >= 0.0:
				jumps_left = max_jumps
		
		if slide_timer <= 0.0:
			end_slide()
	else:
		# Snappy fixed-speed running: immediate response, immediate stop
		var input_x: float = get_horizontal_input()
		if input_x != 0.0:
			facing = 1 if input_x > 0 else -1
			velocity.x = input_x * run_speed
		else:
			velocity.x = 0.0 # Immediate crisp stop (no slippery inertia)
		
		# Normal gravity
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			# Only reset jump when falling downward or settled on floor
			if velocity.y >= 0.0:
				jumps_left = max_jumps
				emit_signal("jumps_changed", jumps_left, max_jumps)
	
	if slash_timer > 0.0:
		slash_timer -= delta
	
	move_and_slide()
	
	# Update animation cycle
	if abs(velocity.x) > 0.0 and not is_sliding:
		run_cycle += delta * 14.0
	
	if visuals:
		visuals.queue_redraw()
	
	update_hud_signals()
	check_zone_tier()

func get_horizontal_input() -> float:
	var x: float = Input.get_axis("move_left", "move_right")
	if x != 0.0:
		return sign(x)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1.0
	return clampf(x, -1.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not event.is_echo():
		trigger_jump()
	elif event.is_action_pressed("dash") and not event.is_echo():
		trigger_momentary_dash()
	elif (event.is_action_pressed("move_down") or (event is InputEventKey and event.pressed and not event.is_echo() and (event.keycode == KEY_S or event.keycode == KEY_DOWN))):
		trigger_slide()
	elif event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func trigger_jump() -> void:
	if is_sliding:
		end_slide()
	
	if is_on_floor():
		# 1st Jump (from ground)
		velocity.y = jump_force
		jumps_left = max_jumps - 1
		emit_signal("jumps_changed", jumps_left, max_jumps)
		spawn_jump_particles()
	elif jumps_left > 0:
		# 2nd Jump (Mid-Air Double Jump booster!)
		velocity.y = double_jump_force
		jumps_left -= 1
		emit_signal("jumps_changed", jumps_left, max_jumps)
		spawn_jump_particles()

func trigger_slide() -> void:
	if not is_on_floor() or is_dashing or is_sliding:
		return
	
	is_sliding = true
	slide_timer = slide_duration
	velocity.x = facing * slide_speed
	set_crouch_collision(true)
	spawn_slide_sparks()

func end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_timer = 0.0
	set_crouch_collision(false)

func set_crouch_collision(crouching: bool) -> void:
	if not col_shape:
		col_shape = $CollisionShape2D if has_node("CollisionShape2D") else null
	if col_shape and col_shape.shape is RectangleShape2D:
		if crouching:
			# Drop height from 36px to 16px to slide smoothly under low overhead beams
			col_shape.shape.size = Vector2(28, 16)
			col_shape.position = Vector2(0, 10)
		else:
			col_shape.shape.size = Vector2(20, 36)
			col_shape.position = Vector2(0, 0)

func trigger_momentary_dash() -> void:
	if is_dashing or dash_pips <= 0:
		return
	if is_sliding:
		end_slide()
	
	dash_pips -= 1
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)
	
	is_dashing = true
	dash_timer = dash_duration
	slash_timer = dash_duration + 0.06
	velocity.x = facing * dash_speed
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
	if invulnerable_timer > 0.0 or is_dashing or is_sliding:
		return
	
	current_hp = max(0.0, current_hp - amount)
	invulnerable_timer = 0.8
	velocity.x = (knockback_dir if knockback_dir != 0.0 else -facing) * 300.0
	velocity.y = -260.0
	emit_signal("hp_changed", current_hp)

func refund_dash_pip() -> void:
	dash_pips = min(max_dash_pips, dash_pips + 1)
	emit_signal("dash_pips_changed", dash_pips, max_dash_pips)

func update_hud_signals() -> void:
	var kmh: float = 450.0 if is_dashing else (180.0 if abs(velocity.x) > 0.0 else 0.0)
	emit_signal("speed_updated", kmh)
	emit_signal("distance_updated", int(global_position.x / 10.0))

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

func spawn_dash_particles() -> void:
	# Burst sparks
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
