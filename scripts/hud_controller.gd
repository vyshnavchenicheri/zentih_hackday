extends CanvasLayer
class_name HUDController

@export var runner: RunnerController

# Top Bar References
@onready var ring_gauge: Control = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/RingGauge")
@onready var hp_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/StatusVBox/Header/HPValue")
@onready var pips_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/StatusVBox/DashHeader/PipsValue")
@onready var distance_label: Label = get_node_or_null("MarginContainer/TopBar/RightPanel/VBoxContainer/DistanceLabel")
@onready var form_label: Label = get_node_or_null("MarginContainer/TopBar/RightPanel/VBoxContainer/FormLabel")

# Title Menu Overlay ("LEONIDAS")
@onready var title_menu_overlay: Control = get_node_or_null("TitleMenuOverlay")
@onready var start_button: Button = get_node_or_null("TitleMenuOverlay/CenterContainer/VBoxContainer/StartButton")

# Game Over Overlay
@onready var game_over_overlay: Control = get_node_or_null("GameOverOverlay")
@onready var death_cause_label: Label = get_node_or_null("GameOverOverlay/CenterContainer/VBoxContainer/DeathCauseLabel")
@onready var death_stats_label: Label = get_node_or_null("GameOverOverlay/CenterContainer/VBoxContainer/StatsLabel")
@onready var restart_button: Button = get_node_or_null("GameOverOverlay/CenterContainer/VBoxContainer/HBoxContainer/RestartButton")
@onready var menu_button: Button = get_node_or_null("GameOverOverlay/CenterContainer/VBoxContainer/HBoxContainer/MenuButton")

# Abilities Bar Dock Nodes (Bound reliably using find_child)
var dash_status_label: Label = null
var dash_progress_bar: ProgressBar = null

var jump_status_label: Label = null
var jump_progress_bar: ProgressBar = null

var slide_status_label: Label = null
var slide_progress_bar: ProgressBar = null

var hound_status_label: Label = null
var hound_progress_bar: ProgressBar = null

# Retreat Warning Banner
@onready var retreat_banner: PanelContainer = get_node_or_null("MarginContainer/RetreatBanner")
@onready var retreat_label: Label = get_node_or_null("MarginContainer/RetreatBanner/RetreatLabel")

# Feedback Toast
@onready var feedback_label: Label = get_node_or_null("MarginContainer/FeedbackToast")
var feedback_timer: float = 0.0

func _ready() -> void:
	# Robust node resolution for Ability Cards
	var dash_card = find_child("DashCard", true, false)
	if dash_card:
		dash_status_label = dash_card.find_child("StatusLabel", true, false) as Label
		dash_progress_bar = dash_card.find_child("ProgressBar", true, false) as ProgressBar
	
	var jump_card = find_child("JumpCard", true, false)
	if jump_card:
		jump_status_label = jump_card.find_child("StatusLabel", true, false) as Label
		jump_progress_bar = jump_card.find_child("ProgressBar", true, false) as ProgressBar
	
	var slide_card = find_child("SlideCard", true, false)
	if slide_card:
		slide_status_label = slide_card.find_child("StatusLabel", true, false) as Label
		slide_progress_bar = slide_card.find_child("ProgressBar", true, false) as ProgressBar
	
	var hound_card = find_child("HoundCard", true, false)
	if hound_card:
		hound_status_label = hound_card.find_child("StatusLabel", true, false) as Label
		hound_progress_bar = hound_card.find_child("ProgressBar", true, false) as ProgressBar
	
	if not runner:
		runner = get_tree().get_first_node_in_group("player") as RunnerController
	
	if runner:
		runner.dash_pips_changed.connect(_on_dash_pips_changed)
		runner.hp_changed.connect(_on_hp_changed)
		runner.distance_updated.connect(_on_distance_updated)
		runner.shapeshift_changed.connect(_on_shapeshift_changed)
		
		if runner.has_signal("game_state_changed"):
			runner.game_state_changed.connect(_on_game_state_changed)
		if runner.has_signal("dash_cooldown_updated"):
			runner.dash_cooldown_updated.connect(_on_dash_cooldown_updated)
		if runner.has_signal("slide_cooldown_updated"):
			runner.slide_cooldown_updated.connect(_on_slide_cooldown_updated)
		if runner.has_signal("double_jump_cooldown_updated"):
			runner.double_jump_cooldown_updated.connect(_on_double_jump_cooldown_updated)
		if runner.has_signal("dog_kills_updated"):
			runner.dog_kills_updated.connect(_on_dog_kills_updated)
		if runner.has_signal("retreat_updated"):
			runner.retreat_updated.connect(_on_retreat_updated)
		if runner.has_signal("player_died"):
			runner.player_died.connect(_on_player_died)
		if runner.has_signal("action_rejected"):
			runner.action_rejected.connect(show_feedback)
		if runner.has_signal("action_unlocked"):
			runner.action_unlocked.connect(show_feedback)
		
		# Initial populate
		_on_dash_pips_changed(runner.dash_pips, runner.max_dash_pips)
		_on_hp_changed(runner.current_hp)
		_on_shapeshift_changed(runner.is_shapeshifted)
		_on_dash_cooldown_updated(runner.dash_cooldown_timer, runner.dash_cooldown)
		_on_slide_cooldown_updated(runner.slide_cooldown_timer, runner.slide_cooldown)
		_on_double_jump_cooldown_updated(runner.double_jump_cooldown_timer, runner.double_jump_cooldown)
		_on_dog_kills_updated(runner.dogs_killed, runner.DOGS_REQUIRED_FOR_SHAPESHIFT)
		_on_game_state_changed(runner.game_state)
	
	# Connect buttons
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	
	if retreat_banner:
		retreat_banner.visible = false
	if feedback_label:
		feedback_label.visible = false

func _process(delta: float) -> void:
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0 and feedback_label:
			feedback_label.visible = false

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		RunnerController.GameState.SKYFALL:
			if title_menu_overlay:
				title_menu_overlay.visible = false
			if game_over_overlay:
				game_over_overlay.visible = false
		RunnerController.GameState.TITLE_MENU:
			if title_menu_overlay:
				title_menu_overlay.visible = true
			if game_over_overlay:
				game_over_overlay.visible = false
		RunnerController.GameState.PLAYING:
			if title_menu_overlay:
				title_menu_overlay.visible = false
			if game_over_overlay:
				game_over_overlay.visible = false
		RunnerController.GameState.DEAD:
			if title_menu_overlay:
				title_menu_overlay.visible = false
			if game_over_overlay:
				game_over_overlay.visible = true

func _on_dash_cooldown_updated(remaining: float, total: float) -> void:
	if not dash_status_label:
		return
	if remaining > 0.0:
		dash_status_label.text = "%.1fs" % remaining
		dash_status_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
		if dash_progress_bar:
			dash_progress_bar.max_value = total
			dash_progress_bar.value = total - remaining
	else:
		dash_status_label.text = "READY"
		dash_status_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		if dash_progress_bar:
			dash_progress_bar.max_value = 1.0
			dash_progress_bar.value = 1.0

func _on_slide_cooldown_updated(remaining: float, total: float) -> void:
	if not slide_status_label:
		return
	if runner and runner.is_shapeshifted:
		slide_status_label.text = "DISABLED"
		slide_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if slide_progress_bar:
			slide_progress_bar.value = 0.0
		return
	
	if remaining > 0.0:
		slide_status_label.text = "%.1fs" % remaining
		slide_status_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
		if slide_progress_bar:
			slide_progress_bar.max_value = total
			slide_progress_bar.value = total - remaining
	elif runner and runner.is_sliding:
		slide_status_label.text = "SLIDING"
		slide_status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		if slide_progress_bar:
			slide_progress_bar.max_value = 1.0
			slide_progress_bar.value = 1.0
	else:
		slide_status_label.text = "READY"
		slide_status_label.add_theme_color_override("font_color", Color(0.18, 1.0, 0.45))
		if slide_progress_bar:
			slide_progress_bar.max_value = 1.0
			slide_progress_bar.value = 1.0

func _on_double_jump_cooldown_updated(remaining: float, total: float) -> void:
	if not jump_status_label:
		return
	if runner and runner.is_shapeshifted:
		jump_status_label.text = "DISABLED"
		jump_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if jump_progress_bar:
			jump_progress_bar.value = 0.0
		return
	
	if remaining > 0.0:
		jump_status_label.text = "%.1fs" % remaining
		jump_status_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
		if jump_progress_bar:
			jump_progress_bar.max_value = total
			jump_progress_bar.value = total - remaining
	else:
		jump_status_label.text = "READY"
		jump_status_label.add_theme_color_override("font_color", Color(0.18, 1.0, 0.45))
		if jump_progress_bar:
			jump_progress_bar.max_value = 1.0
			jump_progress_bar.value = 1.0

func _on_dog_kills_updated(current: int, required: int) -> void:
	if hound_progress_bar:
		hound_progress_bar.max_value = float(required)
		hound_progress_bar.value = float(current)
	
	if not hound_status_label:
		return
	
	if current < required:
		hound_status_label.text = "%d/%d DOGS" % [current, required]
		hound_status_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.2))
	else:
		if runner and runner.is_shapeshifted:
			hound_status_label.text = "ACTIVE"
			hound_status_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		else:
			hound_status_label.text = "READY [Q]"
			hound_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func _on_retreat_updated(current_retreat_m: float, max_retreat_m: float) -> void:
	if not retreat_banner or not retreat_label:
		return
	if current_retreat_m > 40.0:
		retreat_banner.visible = true
		if current_retreat_m >= 900.0:
			retreat_label.text = "🚨 HORDE ENGAGED! RETREAT: %dM / %dM 🚨" % [int(current_retreat_m), int(max_retreat_m)]
			retreat_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			retreat_label.text = "⚠️ RETREAT DISTANCE: %dM / %dM (HORDE PATROL ZONE) ⚠️" % [int(current_retreat_m), int(max_retreat_m)]
			retreat_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	else:
		retreat_banner.visible = false

func _on_player_died(cause: String, distance_m: int, dog_kills: int) -> void:
	if death_cause_label:
		death_cause_label.text = "CAUSE: %s" % cause
	if death_stats_label:
		death_stats_label.text = "DISTANCE REACHED: %d M  |  HOUNDS KILLED: %d / 10" % [distance_m, dog_kills]
	if game_over_overlay:
		game_over_overlay.visible = true

func _on_shapeshift_changed(is_dog: bool) -> void:
	if form_label:
		if is_dog:
			form_label.text = "[CYBER HOUND] +50% SPD/JUMP"
			form_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		else:
			form_label.text = "[HUMAN] (Q / SHIFT)"
			form_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.15))
	if runner:
		_on_dog_kills_updated(runner.dogs_killed, runner.DOGS_REQUIRED_FOR_SHAPESHIFT)
		_on_double_jump_cooldown_updated(runner.double_jump_cooldown_timer, runner.double_jump_cooldown)
		_on_slide_cooldown_updated(runner.slide_cooldown_timer, runner.slide_cooldown)

func _on_dash_pips_changed(current: int, max_pips: int) -> void:
	if ring_gauge and ring_gauge.has_method("set_pips"):
		ring_gauge.set_pips(current, max_pips)
	if pips_label:
		pips_label.text = "%d/%d" % [current, max_pips]

func _on_hp_changed(current_hp: float) -> void:
	if ring_gauge and ring_gauge.has_method("set_hp"):
		ring_gauge.set_hp(current_hp)
	if hp_label:
		hp_label.text = "%d%%" % int(current_hp)

func _on_distance_updated(meters: int) -> void:
	if distance_label:
		distance_label.text = "PROGRESS: %d M" % meters

func show_feedback(msg: String) -> void:
	if feedback_label:
		feedback_label.text = msg
		feedback_label.visible = true
		feedback_timer = 2.2

func _on_start_button_pressed() -> void:
	if runner:
		runner.start_game()

func _on_restart_button_pressed() -> void:
	if runner:
		runner.restart_game()

func _on_menu_button_pressed() -> void:
	if runner:
		runner.return_to_main_menu()
