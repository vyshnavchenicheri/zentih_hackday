extends CanvasLayer
class_name HUDController

@export var runner: RunnerController

@onready var hp_bar: ProgressBar = get_node_or_null("MarginContainer/TopBar/LeftPanel/VBoxContainer/HPBar")
@onready var hp_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/VBoxContainer/Header/HPValue")
@onready var pips_container: HBoxContainer = get_node_or_null("MarginContainer/TopBar/LeftPanel/VBoxContainer/PipsContainer")
@onready var pips_label: Label = get_node_or_null("MarginContainer/TopBar/LeftPanel/VBoxContainer/DashHeader/PipsValue")
@onready var distance_label: Label = get_node_or_null("MarginContainer/TopBar/RightPanel/VBoxContainer/DistanceLabel")

func _ready() -> void:
	if not runner:
		# Auto-find runner if not set
		runner = get_tree().get_first_node_in_group("player") as RunnerController
	
	if runner:
		runner.dash_pips_changed.connect(_on_dash_pips_changed)
		runner.hp_changed.connect(_on_hp_changed)
		runner.distance_updated.connect(_on_distance_updated)
		
		# Initial populate
		_on_dash_pips_changed(runner.dash_pips, runner.max_dash_pips)
		_on_hp_changed(runner.current_hp)

func _on_dash_pips_changed(current: int, max_pips: int) -> void:
	if pips_label:
		pips_label.text = "%d/%d" % [current, max_pips]
	
	if pips_container:
		var children = pips_container.get_children()
		for i in range(children.size()):
			if children[i] is ColorRect:
				if i < current:
					children[i].color = Color(0.95, 0.6, 0.1) # Glowing amber
				else:
					children[i].color = Color(0.15, 0.2, 0.25, 0.4) # Dim inactive

func _on_hp_changed(current_hp: float) -> void:
	if hp_bar:
		hp_bar.value = current_hp
	if hp_label:
		hp_label.text = "%d%%" % int(current_hp)

func _on_distance_updated(meters: int) -> void:
	if distance_label:
		distance_label.text = "PROGRESS: %d M" % meters
