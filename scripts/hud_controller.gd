extends CanvasLayer
class_name HUDController

@export var runner: RunnerController

@onready var ring_gauge: Control = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/RingGauge")
@onready var hp_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/StatusVBox/Header/HPValue")
@onready var pips_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/HBoxContainer/StatusVBox/DashHeader/PipsValue")
@onready var distance_label: Label = get_node_or_null("MarginContainer/TopBar/RightPanel/VBoxContainer/DistanceLabel")
@onready var form_label: Label = get_node_or_null("MarginContainer/TopBar/RightPanel/VBoxContainer/FormLabel")

func _ready() -> void:
	if not runner:
		# Auto-find runner if not set
		runner = get_tree().get_first_node_in_group("player") as RunnerController
	
	if runner:
		runner.dash_pips_changed.connect(_on_dash_pips_changed)
		runner.hp_changed.connect(_on_hp_changed)
		runner.distance_updated.connect(_on_distance_updated)
		runner.shapeshift_changed.connect(_on_shapeshift_changed)
		
		# Initial populate
		_on_dash_pips_changed(runner.dash_pips, runner.max_dash_pips)
		_on_hp_changed(runner.current_hp)
		_on_shapeshift_changed(runner.is_shapeshifted)

func _on_shapeshift_changed(is_dog: bool) -> void:
	if form_label:
		if is_dog:
			form_label.text = "[CYBER HOUND] +50% SPD/JUMP"
			form_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		else:
			form_label.text = "[HUMAN] (Q / SHIFT)"
			form_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.15))

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
