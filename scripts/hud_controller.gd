extends CanvasLayer
class_name HUDController

@export var runner: RunnerController

@onready var hp_bar: ProgressBar = $MarginContainer/TopBar/LeftPanel/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/TopBar/LeftPanel/VBoxContainer/Header/HPValue
@onready var pips_container: HBoxContainer = $MarginContainer/TopBar/LeftPanel/VBoxContainer/PipsContainer
@onready var pips_label: Label = $MarginContainer/TopBar/LeftPanel/VBoxContainer/DashHeader/PipsValue

@onready var speed_value: Label = $MarginContainer/TopBar/CenterPanel/VBoxContainer/SpeedValue
@onready var status_badge: Label = $MarginContainer/TopBar/CenterPanel/VBoxContainer/StatusBadge
@onready var jump_status: Label = $MarginContainer/TopBar/CenterPanel/VBoxContainer/JumpStatus

@onready var zone_label: Label = $MarginContainer/TopBar/RightPanel/VBoxContainer/ZoneLabel
@onready var distance_label: Label = $MarginContainer/TopBar/RightPanel/VBoxContainer/DistanceLabel

func _ready() -> void:
	if not runner:
		# Auto-find runner if not set
		runner = get_tree().get_first_node_in_group("player") as RunnerController
	
	if runner:
		runner.speed_updated.connect(_on_speed_updated)
		runner.dash_pips_changed.connect(_on_dash_pips_changed)
		runner.hp_changed.connect(_on_hp_changed)
		runner.zone_tier_changed.connect(_on_zone_tier_changed)
		runner.jumps_changed.connect(_on_jumps_changed)
		runner.distance_updated.connect(_on_distance_updated)
		
		# Initial populate
		_on_dash_pips_changed(runner.dash_pips, runner.max_dash_pips)
		_on_hp_changed(runner.current_hp)
		_on_jumps_changed(runner.jumps_left, runner.max_jumps)

func _on_speed_updated(kmh: float) -> void:
	if speed_value:
		speed_value.text = "%d" % int(kmh)
	
	if status_badge:
		if kmh >= 400.0:
			status_badge.text = "DASH BURST"
			status_badge.modulate = Color(0.0, 0.95, 1.0)
		elif kmh > 0.0:
			status_badge.text = "RUNNING"
			status_badge.modulate = Color(0.2, 1.0, 0.4)
		else:
			status_badge.text = "IDLE"
			status_badge.modulate = Color(0.7, 0.7, 0.7)

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

func _on_jumps_changed(jumps_left: int, _max_jumps: int) -> void:
	if jump_status:
		if jumps_left == 2:
			jump_status.text = "JUMP: READY (2/2)"
			jump_status.modulate = Color(0.95, 0.8, 0.2)
		elif jumps_left == 1:
			jump_status.text = "JUMP: DOUBLE (1/2)"
			jump_status.modulate = Color(0.2, 0.8, 1.0)
		else:
			jump_status.text = "JUMP: IN AIR (0/2)"
			jump_status.modulate = Color(0.6, 0.6, 0.6)

func _on_zone_tier_changed(tier_name: String) -> void:
	if zone_label:
		zone_label.text = tier_name

func _on_distance_updated(meters: int) -> void:
	if distance_label:
		distance_label.text = "PROGRESS: %d M" % meters
