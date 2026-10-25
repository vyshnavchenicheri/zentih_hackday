extends Control
class_name CyberRingGauge

## Cybernetic Circular Health & Energy HUD Gauge
## Matches the circular neon HUD design with:
## - Outer Ring: Neon Green Health (Hull Integrity) with top notch & bottom gap
## - Inner Ring: 3 Segmented Neon Cyan Energy Blocks for the 3 Dash Pips

@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var max_pips: int = 3
@export var current_pips: int = 3
@export var recharge_ratio: float = 0.0 # 0.0 to 1.0 for currently recharging pip

var display_hp: float = 100.0
var hurt_flash_timer: float = 0.0
var anim_pulse: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(130, 130)

func _process(delta: float) -> void:
	anim_pulse += delta * 4.0
	
	# Smooth health interpolation
	display_hp = move_toward(display_hp, current_hp, delta * 85.0)
	
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta
	
	queue_redraw()

func set_hp(new_hp: float) -> void:
	if new_hp < current_hp:
		hurt_flash_timer = 0.35 # Flash warning on damage
	current_hp = clampf(new_hp, 0.0, max_hp)

func set_pips(current: int, max_val: int) -> void:
	current_pips = current
	max_pips = max_val

func _draw() -> void:
	var center = size / 2.0
	var base_radius = minf(size.x, size.y) / 2.0 - 4.0
	
	# Radii Definitions
	var r_outer_glow = base_radius
	var r_health_out = base_radius - 2.0
	var r_health_in  = base_radius - 13.0
	
	var r_gap = base_radius - 16.0
	var r_energy_out = base_radius - 18.0
	var r_energy_in  = base_radius - 29.0
	var r_center_core = r_energy_in - 3.0
	
	# ---------------------------------------------------------------------
	# 0. DARK BACKGROUND VIGNETTE
	# ---------------------------------------------------------------------
	draw_circle(center, r_health_out + 2.0, Color(0.02, 0.04, 0.05, 0.95))
	
	# ---------------------------------------------------------------------
	# 1. OUTER RING: HEALTH / HULL INTEGRITY (NEON GREEN)
	# ---------------------------------------------------------------------
	var hp_pct = clampf(display_hp / max_hp, 0.0, 1.0)
	
	# Color determination: Green -> Amber -> Critical Crimson
	var hp_color = Color(0.18, 1.0, 0.45) # Radiant electric green
	var hp_highlight = Color(0.55, 1.0, 0.72)
	var hp_glow = Color(0.1, 0.95, 0.4, 0.35)
	
	if hurt_flash_timer > 0.0:
		hp_color = Color(1.0, 0.25, 0.2)
		hp_highlight = Color(1.0, 0.7, 0.6)
		hp_glow = Color(1.0, 0.2, 0.2, 0.5)
	elif hp_pct <= 0.25:
		# Critical low HP pulse
		var pulse = 0.5 + 0.5 * sin(anim_pulse * 3.0)
		hp_color = Color(1.0, 0.2, 0.2).lerp(Color(0.8, 0.05, 0.05), pulse)
		hp_highlight = Color(1.0, 0.6, 0.6)
		hp_glow = Color(1.0, 0.15, 0.15, 0.45)
	elif hp_pct <= 0.45:
		hp_color = Color(1.0, 0.75, 0.15) # Caution amber
		hp_highlight = Color(1.0, 0.9, 0.5)
		hp_glow = Color(1.0, 0.7, 0.1, 0.35)
	
	# Background track (dark empty groove)
	_draw_annular_ring(center, r_health_in, r_health_out, Color(0.04, 0.1, 0.06, 0.8), Color(0.08, 0.22, 0.14, 0.85))
	
	# Outer soft neon glow halo
	if hp_pct > 0.01:
		draw_arc(center, r_health_out + 1.5, -PI / 2.0, -PI / 2.0 + TAU * hp_pct, 48, hp_glow, 3.0, true)
	
	# Active Health Arc (Left and Right halves with Top notch & Bottom gap)
	_draw_health_arc(center, r_health_in, r_health_out, hp_pct, hp_color, hp_highlight)
	
	# Top Notch Indicator (12 o'clock)
	_draw_notch(center, r_health_in - 1.0, r_health_out + 1.0, -PI / 2.0, Color(0.05, 0.1, 0.08), hp_highlight)
	# Bottom Gap Indicator (6 o'clock)
	_draw_notch(center, r_health_in - 1.0, r_health_out + 1.0, PI / 2.0, Color(0.02, 0.04, 0.05), Color(0.08, 0.2, 0.15))
	
	# ---------------------------------------------------------------------
	# 2. INNER RING: ENERGY / 3 DASH PIPS (NEON CYAN SEGMENTS)
	# ---------------------------------------------------------------------
	# Separator gap size: 14 degrees
	var gap_deg: float = 14.0
	var seg_span_deg: float = (360.0 - (3.0 * gap_deg)) / 3.0 # ~106 degrees per segment
	
	# 3 Symmetrical Segments:
	# Segment 0: Top segment (centered at 270° / -90°) -> 270 - span/2 to 270 + span/2
	# Segment 1: Bottom-Right segment (centered at 30°)
	# Segment 2: Bottom-Left segment (centered at 150°)
	var seg_centers = [deg_to_rad(270.0), deg_to_rad(30.0), deg_to_rad(150.0)]
	var half_span = deg_to_rad(seg_span_deg / 2.0)
	
	for i in range(3):
		var start_a = seg_centers[i] - half_span
		var end_a   = seg_centers[i] + half_span
		var is_active = (i < current_pips)
		
		# Draw pip segment
		_draw_energy_segment(center, r_energy_in, r_energy_out, start_a, end_a, is_active)
	
	# ---------------------------------------------------------------------
	# 3. CENTER HUB READOUT
	# ---------------------------------------------------------------------
	# Dark inner hub core
	draw_circle(center, r_center_core, Color(0.03, 0.06, 0.08, 0.95))
	draw_arc(center, r_center_core, 0, TAU, 32, Color(0.0, 0.5, 0.65, 0.4), 1.5, true)
	
	# Draw centered HP % and Dash pip indicator
	var font = ThemeDB.fallback_font
	var hp_text = "%d%%" % int(display_hp)
	var hp_text_size = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	draw_string(font, center + Vector2(-hp_text_size.x / 2.0, 2.0), hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, hp_color)
	
	var pip_text = "%d/3 NRG" % current_pips
	var pip_text_size = font.get_string_size(pip_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
	draw_string(font, center + Vector2(-pip_text_size.x / 2.0, 14.0), pip_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.0, 0.85, 1.0, 0.85))

# -------------------------------------------------------------------------
# DRAWING HELPERS
# -------------------------------------------------------------------------

func _draw_annular_ring(c: Vector2, r_in: float, r_out: float, bg_col: Color, border_col: Color) -> void:
	var steps = 48
	var pts_out = PackedVector2Array()
	var pts_in = PackedVector2Array()
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		pts_out.append(c + Vector2(cos(a), sin(a)) * r_out)
		pts_in.append(c + Vector2(cos(a), sin(a)) * r_in)
	
	# Draw background polygon strip
	for i in range(steps):
		var quad = PackedVector2Array([pts_out[i], pts_out[i+1], pts_in[i+1], pts_in[i]])
		draw_colored_polygon(quad, bg_col)
	
	draw_polyline(pts_out, border_col, 1.2, true)
	draw_polyline(pts_in, border_col, 1.2, true)

func _draw_health_arc(c: Vector2, r_in: float, r_out: float, pct: float, fill_col: Color, core_col: Color) -> void:
	if pct <= 0.005:
		return
	
	var start_angle = -PI / 2.0 # 12 o'clock
	var total_sweep = TAU * pct
	var steps = int(max(6, pct * 48.0))
	
	var pts = PackedVector2Array()
	# Outer rim
	for i in range(steps + 1):
		var a = start_angle + (float(i) / float(steps)) * total_sweep
		pts.append(c + Vector2(cos(a), sin(a)) * r_out)
	# Inner rim
	for i in range(steps, -1, -1):
		var a = start_angle + (float(i) / float(steps)) * total_sweep
		pts.append(c + Vector2(cos(a), sin(a)) * r_in)
	
	draw_colored_polygon(pts, fill_col)
	
	# Beveled bright core line along the center of the arc
	var r_mid = (r_in + r_out) / 2.0
	draw_arc(c, r_mid, start_angle, start_angle + total_sweep, steps, core_col, 2.5, true)
	
	# Sharp beveled inner and outer outline
	draw_arc(c, r_out, start_angle, start_angle + total_sweep, steps, Color(0.04, 0.15, 0.08), 1.2, true)
	draw_arc(c, r_in, start_angle, start_angle + total_sweep, steps, Color(0.04, 0.15, 0.08), 1.2, true)

func _draw_energy_segment(c: Vector2, r_in: float, r_out: float, start_a: float, end_a: float, active: bool) -> void:
	var steps = 18
	var pts = PackedVector2Array()
	
	# Outer curve
	for i in range(steps + 1):
		var a = lerpf(start_a, end_a, float(i) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * r_out)
	# Inner curve
	for i in range(steps, -1, -1):
		var a = lerpf(start_a, end_a, float(i) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * r_in)
	
	if active:
		# Radiant Glowing Neon Cyan
		var cyan_fill = Color(0.0, 0.85, 1.0)
		var cyan_highlight = Color(0.55, 0.95, 1.0)
		var cyan_border = Color(0.02, 0.12, 0.22)
		var cyan_glow = Color(0.0, 0.85, 1.0, 0.35)
		
		# Glow halo
		var r_mid = (r_in + r_out) / 2.0
		draw_arc(c, r_mid, start_a, end_a, steps, cyan_glow, 6.0, true)
		
		# Solid segment body
		draw_colored_polygon(pts, cyan_fill)
		
		# Luminous central highlight streak
		draw_arc(c, r_mid, start_a + 0.04, end_a - 0.04, steps, cyan_highlight, 2.2, true)
		
		# Beveled border
		draw_polyline(pts, cyan_border, 1.5, true)
	else:
		# Depleted / inactive state: Dark cyber glass
		var dim_fill = Color(0.03, 0.08, 0.14, 0.65)
		var dim_border = Color(0.0, 0.4, 0.55, 0.3)
		draw_colored_polygon(pts, dim_fill)
		draw_polyline(pts, dim_border, 1.2, true)

func _draw_notch(c: Vector2, r_in: float, r_out: float, angle: float, bg_col: Color, border_col: Color) -> void:
	var half_w = 0.06 # ~3.5 degrees
	var p1 = c + Vector2(cos(angle - half_w), sin(angle - half_w)) * r_out
	var p2 = c + Vector2(cos(angle + half_w), sin(angle + half_w)) * r_out
	var p3 = c + Vector2(cos(angle + half_w), sin(angle + half_w)) * r_in
	var p4 = c + Vector2(cos(angle - half_w), sin(angle - half_w)) * r_in
	draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), bg_col)
	draw_line(p1, p4, border_col, 1.5)
	draw_line(p2, p3, border_col, 1.5)
