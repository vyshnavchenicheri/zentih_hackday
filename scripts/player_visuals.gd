extends Node2D
class_name PlayerVisuals

@onready var parent: RunnerController = get_parent() as RunnerController

func _draw() -> void:
	if not parent:
		return
	
	var facing: int = parent.facing
	var is_dashing: bool = parent.is_dashing
	var slashing: bool = parent.slash_timer > 0.0 or is_dashing
	var leg_bob: float = sin(parent.run_cycle) * 4.0 if abs(parent.velocity.x) > 0.0 else 0.0
	
	# 1. Scavenger billowed orange cape/scarf
	var scarf_x: float = -14.0 * facing
	var scarf_pts = PackedVector2Array([
		Vector2(0, -6),
		Vector2(scarf_x, -4 + leg_bob * 0.4),
		Vector2(scarf_x * 1.4, 4 + leg_bob * 0.6),
		Vector2(0, 4)
	])
	draw_colored_polygon(scarf_pts, Color(0.95, 0.55, 0.1))
	
	# 2. Cyber Scavenger Armor Torso
	draw_rect(Rect2(-8, -16, 16, 22), Color(0.08, 0.12, 0.18))
	
	# 3. Scavenger Visor (Glowing Neon Cyan)
	var visor_x: float = 3.0 if facing == 1 else -9.0
	draw_rect(Rect2(visor_x, -14, 7, 4), Color(0.0, 0.95, 1.0))
	
	# 4. Cybernetic Running Legs
	var leg_left_y: float = 6.0 + leg_bob
	var leg_right_y: float = 6.0 - leg_bob
	draw_rect(Rect2(-6, leg_left_y, 4, 10), Color(0.2, 0.6, 0.85))
	draw_rect(Rect2(2, leg_right_y, 4, 10), Color(0.2, 0.6, 0.85))
	
	# 5. Jet Thruster on Back
	var thruster_x: float = -8.0 if facing == 1 else 6.0
	var flame_color: Color = Color(0.0, 0.95, 1.0) if is_dashing else Color(0.95, 0.6, 0.1)
	draw_rect(Rect2(thruster_x, -8, 3, 6), Color(0.3, 0.35, 0.4))
	
	# Thruster exhaust flame
	if abs(parent.velocity.x) > 0.0 or is_dashing:
		var flame_len: float = (18.0 if is_dashing else 8.0) * -facing
		var flame_pts = PackedVector2Array([
			Vector2(thruster_x, -7),
			Vector2(thruster_x + flame_len, -5),
			Vector2(thruster_x, -3)
		])
		draw_colored_polygon(flame_pts, flame_color)
	
	# 6. Glowing Crescent Plasma Machete Blade
	if slashing:
		var blade_origin = Vector2(facing * 6.0, -4.0)
		var blade_tip = Vector2(facing * 34.0, -4.0)
		# Plasma core line
		draw_line(blade_origin, blade_tip, Color(0.0, 0.95, 1.0), 3.5)
		draw_line(blade_origin, blade_tip, Color(1.0, 1.0, 1.0), 1.5)
		
		# Crescent shockwave arc
		var arc_center = Vector2(facing * 20.0, -4.0)
		var start_angle: float = -0.35 * PI if facing == 1 else 0.65 * PI
		var end_angle: float = 0.35 * PI if facing == 1 else 1.35 * PI
		draw_arc(arc_center, 24.0, start_angle, end_angle, 12, Color(0.0, 0.95, 1.0, 0.8), 2.5)
