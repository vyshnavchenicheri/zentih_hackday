extends Node2D
class_name PlayerVisuals

@onready var parent: RunnerController = get_parent() as RunnerController

func _draw() -> void:
	if not parent:
		return
	
	var facing: float = float(parent.facing)
	var is_dashing: bool = parent.is_dashing
	var is_sliding: bool = parent.is_sliding
	var is_moving: bool = abs(parent.velocity.x) > 0.1
	var is_in_air: bool = (not parent.is_on_floor()) and not bool(parent.get("preview_idle"))
	var slashing: bool = parent.slash_timer > 0.0 or is_dashing
	var run_cycle: float = parent.run_cycle
	
	# Apply facing flip directly via CanvasItem transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	
	if parent.is_shapeshifted:
		_draw_dog(is_moving, is_in_air, is_dashing, run_cycle)
		return
	
	if is_sliding:
		_draw_slide()
		return
	
	# Leg oscillation
	var leg_swing: float = sin(run_cycle) * 7.0 if is_moving and not is_in_air else 0.0
	var torso_bob: float = abs(sin(run_cycle * 2.0)) * 2.0 if is_moving and not is_in_air else 0.0
	if is_in_air:
		torso_bob = -2.0
	
	# =========================================================
	# 1. FLOWING SCAVENGER DUSTER / SCARF (Back layer)
	# =========================================================
	var scarf_wind: float = sin(run_cycle * 1.6) * 3.0 if is_moving else sin(Time.get_ticks_msec() * 0.005) * 2.0
	var scarf_pts = PackedVector2Array([
		Vector2(-2.0, -12.0 + torso_bob),
		Vector2(-10.0, -9.0 + torso_bob + scarf_wind * 0.5),
		Vector2(-20.0, -4.0 + torso_bob + scarf_wind),
		Vector2(-14.0, 1.0 + torso_bob + scarf_wind * 0.8),
		Vector2(-1.0, -6.0 + torso_bob)
	])
	draw_colored_polygon(scarf_pts, Color(0.95, 0.52, 0.12))
	draw_polyline(scarf_pts, Color(0.8, 0.38, 0.08), 1.2)
	
	# =========================================================
	# 2. BACK THRUSTER & DUST / EXHAUST FLAME
	# =========================================================
	var thruster_pos = Vector2(-7.0, -8.0 + torso_bob)
	draw_rect(Rect2(thruster_pos.x - 2, thruster_pos.y - 4, 3, 8), Color(0.22, 0.26, 0.32))
	draw_rect(Rect2(thruster_pos.x - 3, thruster_pos.y - 2, 1, 4), Color(0.12, 0.15, 0.2))
	
	if is_moving or is_dashing or is_in_air:
		var flame_len: float = -(22.0 if is_dashing else (11.0 + abs(sin(run_cycle * 3.0)) * 4.0))
		var flame_w: float = 4.0 if is_dashing else 2.5
		var flame_pts = PackedVector2Array([
			Vector2(thruster_pos.x, thruster_pos.y - flame_w),
			Vector2(thruster_pos.x + flame_len, thruster_pos.y),
			Vector2(thruster_pos.x, thruster_pos.y + flame_w)
		])
		var flame_col = Color(0.0, 0.95, 1.0) if is_dashing else Color(0.98, 0.65, 0.15)
		draw_colored_polygon(flame_pts, flame_col)
		
		var core_pts = PackedVector2Array([
			Vector2(thruster_pos.x, thruster_pos.y - flame_w * 0.5),
			Vector2(thruster_pos.x + flame_len * 0.55, thruster_pos.y),
			Vector2(thruster_pos.x, thruster_pos.y + flame_w * 0.5)
		])
		draw_colored_polygon(core_pts, Color(1.0, 1.0, 1.0, 0.9))

	# =========================================================
	# 3. BACK LEG
	# =========================================================
	var back_leg_offset: float = -leg_swing if not is_in_air else -4.0
	var back_foot_pos = Vector2(-2.0 + back_leg_offset, 14.0)
	draw_line(Vector2(-2.0, 2.0 + torso_bob), back_foot_pos + Vector2(0, -6), Color(0.15, 0.2, 0.26), 4.0)
	draw_line(back_foot_pos + Vector2(0, -6), back_foot_pos, Color(0.12, 0.16, 0.22), 3.5)
	draw_rect(Rect2(back_foot_pos.x - 2, back_foot_pos.y - 2, 7, 4), Color(0.08, 0.1, 0.14))

	# =========================================================
	# 4. TORSO & ARMORED VEST
	# =========================================================
	var torso_pos = Vector2(0, -8.0 + torso_bob)
	draw_rect(Rect2(torso_pos.x - 6, torso_pos.y - 6, 12, 16), Color(0.14, 0.18, 0.24))
	
	var armor_pts = PackedVector2Array([
		Vector2(torso_pos.x - 5, torso_pos.y - 5),
		Vector2(torso_pos.x + 5, torso_pos.y - 5),
		Vector2(torso_pos.x + 4, torso_pos.y + 6),
		Vector2(torso_pos.x - 4, torso_pos.y + 6)
	])
	draw_colored_polygon(armor_pts, Color(0.25, 0.32, 0.4))
	
	# Glowing Cyan Fusion Core on Chest
	draw_circle(Vector2(torso_pos.x + 1.0, torso_pos.y), 2.2, Color(0.0, 0.95, 1.0))
	draw_circle(Vector2(torso_pos.x + 1.0, torso_pos.y), 1.0, Color(1.0, 1.0, 1.0))
	
	# Ammo/gear pouches on belt
	draw_rect(Rect2(torso_pos.x - 6, torso_pos.y + 7, 12, 3), Color(0.18, 0.14, 0.1))
	draw_rect(Rect2(torso_pos.x - 4, torso_pos.y + 7, 3, 3), Color(0.6, 0.45, 0.2))
	draw_rect(Rect2(torso_pos.x + 1, torso_pos.y + 7, 3, 3), Color(0.6, 0.45, 0.2))

	# =========================================================
	# 5. FRONT LEG
	# =========================================================
	var front_leg_offset: float = leg_swing if not is_in_air else 4.0
	var front_foot_pos = Vector2(2.0 + front_leg_offset, 14.0)
	draw_line(Vector2(2.0, 2.0 + torso_bob), front_foot_pos + Vector2(0, -6), Color(0.2, 0.28, 0.36), 4.5)
	draw_circle(front_foot_pos + Vector2(-1.0, -6), 2.5, Color(0.35, 0.45, 0.55))
	draw_line(front_foot_pos + Vector2(0, -6), front_foot_pos, Color(0.16, 0.22, 0.3), 4.0)
	draw_rect(Rect2(front_foot_pos.x - 2, front_foot_pos.y - 2, 8, 4), Color(0.08, 0.1, 0.14))

	# =========================================================
	# 6. HEAD, HELMET / HAIR & CYBER VISOR
	# =========================================================
	var head_pos = Vector2(1.0, -18.0 + torso_bob)
	draw_rect(Rect2(head_pos.x - 5, head_pos.y - 4, 10, 8), Color(0.16, 0.18, 0.22))
	
	draw_rect(Rect2(head_pos.x - 5, head_pos.y - 7, 9, 4), Color(0.18, 0.14, 0.12))
	var hair_spike = PackedVector2Array([
		Vector2(head_pos.x - 3, head_pos.y - 7),
		Vector2(head_pos.x - 9, head_pos.y - 5),
		Vector2(head_pos.x - 4, head_pos.y - 2)
	])
	draw_colored_polygon(hair_spike, Color(0.18, 0.14, 0.12))
	
	# Visor frame & Glowing Cyan Cyber-Optic Visor
	var visor_origin = Vector2(head_pos.x + 1.0, head_pos.y - 3)
	draw_rect(Rect2(visor_origin.x - 1, visor_origin.y - 1, 6, 4), Color(0.08, 0.1, 0.14))
	draw_rect(Rect2(visor_origin.x, visor_origin.y, 4, 2), Color(0.0, 0.95, 1.0))
	draw_line(visor_origin + Vector2(1, 1), visor_origin + Vector2(4, 1), Color(1.0, 1.0, 1.0), 1.0)

	# =========================================================
	# 7. CYBERNETIC ARM & PLASMA BLADE
	# =========================================================
	var arm_shoulder = Vector2(2.0, -9.0 + torso_bob)
	draw_circle(arm_shoulder, 3.2, Color(0.3, 0.38, 0.48))
	
	if slashing:
		var arm_hand = Vector2(arm_shoulder.x + 16.0, arm_shoulder.y + 2.0)
		draw_line(arm_shoulder, arm_hand, Color(0.2, 0.28, 0.36), 4.0)
		
		var blade_tip = Vector2(arm_hand.x + 28.0, arm_hand.y - 2.0)
		draw_line(arm_hand, blade_tip, Color(0.0, 0.9, 1.0, 0.6), 6.0)
		draw_line(arm_hand, blade_tip, Color(0.0, 0.98, 1.0), 3.0)
		draw_line(arm_hand, blade_tip, Color(1.0, 1.0, 1.0), 1.5)
		
		# Arc slash shockwave
		var arc_origin = Vector2(arm_shoulder.x + 14.0, arm_shoulder.y)
		draw_arc(arc_origin, 28.0, -0.4 * PI, 0.4 * PI, 16, Color(0.0, 0.95, 1.0, 0.85), 3.0)
		draw_arc(arc_origin, 26.0, -0.4 * PI, 0.4 * PI, 16, Color(1.0, 1.0, 1.0, 0.7), 1.5)
	else:
		var arm_swing: float = -leg_swing * 0.7 if is_moving else 0.0
		var arm_hand = Vector2(arm_shoulder.x + 6.0 + arm_swing, arm_shoulder.y + 9.0)
		draw_line(arm_shoulder, arm_hand, Color(0.2, 0.28, 0.36), 3.5)
		draw_line(arm_hand + Vector2(-3.0, -2), arm_hand + Vector2(4.0, 2), Color(0.0, 0.85, 0.95), 2.0)

func _draw_slide() -> void:
	# Low clearance slide posture (fits easily under 24px overhead beams)
	# 1. Scarf streaming straight back
	var scarf_pts = PackedVector2Array([
		Vector2(-4.0, 2.0),
		Vector2(-16.0, 0.0),
		Vector2(-24.0, 4.0),
		Vector2(-14.0, 7.0),
		Vector2(-3.0, 5.0)
	])
	draw_colored_polygon(scarf_pts, Color(0.95, 0.52, 0.12))
	
	# 2. Back Thruster puffing horizontal sparks
	draw_rect(Rect2(-10, 2, 4, 6), Color(0.22, 0.26, 0.32))
	var flame_pts = PackedVector2Array([
		Vector2(-10, 3),
		Vector2(-22, 5),
		Vector2(-10, 7)
	])
	draw_colored_polygon(flame_pts, Color(0.0, 0.95, 1.0))
	
	# 3. Bent Back Leg skimming ground
	draw_line(Vector2(-3.0, 6.0), Vector2(-11.0, 14.0), Color(0.16, 0.22, 0.3), 4.0)
	draw_rect(Rect2(-14, 12, 6, 4), Color(0.08, 0.1, 0.14))
	
	# 4. Low Angled Torso & Armored Vest
	var torso_pts = PackedVector2Array([
		Vector2(-6.0, 1.0),
		Vector2(5.0, 0.0),
		Vector2(7.0, 10.0),
		Vector2(-4.0, 11.0)
	])
	draw_colored_polygon(torso_pts, Color(0.25, 0.32, 0.4))
	# Glowing chest core
	draw_circle(Vector2(2.0, 5.0), 1.8, Color(0.0, 0.95, 1.0))
	
	# 5. Outstretched Front Leg grinding on floor
	draw_line(Vector2(4.0, 7.0), Vector2(17.0, 14.0), Color(0.2, 0.28, 0.36), 4.5)
	# Metal boot heel grinding
	draw_rect(Rect2(15, 12, 8, 4), Color(0.08, 0.1, 0.14))
	# Metal knee plate
	draw_circle(Vector2(10.0, 10.0), 2.2, Color(0.35, 0.45, 0.55))
	
	# 6. Low Head & Cyber Visor (tucked low)
	draw_rect(Rect2(1, -5, 8, 7), Color(0.16, 0.18, 0.22))
	draw_rect(Rect2(1, -7, 7, 3), Color(0.18, 0.14, 0.12))
	# Visor line
	draw_rect(Rect2(5, -4, 5, 2), Color(0.0, 0.95, 1.0))
	
	# 7. Ground Bracing Arm
	draw_line(Vector2(0.0, 4.0), Vector2(-6.0, 14.0), Color(0.22, 0.28, 0.35), 3.0)
	# Friction spark highlight under boot heel
	draw_line(Vector2(14, 16), Vector2(22, 16), Color(1.0, 0.8, 0.2), 2.0)

func _draw_dog(is_moving: bool, is_in_air: bool, is_dashing: bool, run_cycle: float) -> void:
	var gallop: float = sin(run_cycle) * 7.0 if is_moving and not is_in_air else 0.0
	var spine_bob: float = abs(sin(run_cycle * 2.0)) * 2.0 if is_moving and not is_in_air else 0.0
	if is_in_air:
		gallop = 4.0
		spine_bob = -2.0
	
	# 1. HAZARD-ORANGE COLLAR SCARF (Flowing behind Cyber Hound)
	var scarf_wind: float = sin(run_cycle * 1.8) * 4.0 if is_moving else sin(Time.get_ticks_msec() * 0.005) * 2.5
	var scarf_pts = PackedVector2Array([
		Vector2(-4.0, 3.0 + spine_bob),
		Vector2(-14.0, 1.0 + spine_bob + scarf_wind * 0.5),
		Vector2(-24.0, 4.0 + spine_bob + scarf_wind),
		Vector2(-16.0, 9.0 + spine_bob + scarf_wind * 0.8),
		Vector2(-3.0, 7.0 + spine_bob)
	])
	draw_colored_polygon(scarf_pts, Color(0.95, 0.52, 0.12))
	draw_polyline(scarf_pts, Color(0.8, 0.38, 0.08), 1.2)
	
	# 2. BACK MOUNTED THRUSTER & JET FLAME
	var thruster_pos = Vector2(-12.0, 3.0 + spine_bob)
	draw_rect(Rect2(thruster_pos.x - 2, thruster_pos.y - 3, 4, 6), Color(0.22, 0.26, 0.32))
	draw_rect(Rect2(thruster_pos.x - 3, thruster_pos.y - 2, 1, 4), Color(0.12, 0.15, 0.2))
	
	if is_moving or is_dashing or is_in_air:
		var flame_len: float = -(24.0 if is_dashing else (12.0 + abs(sin(run_cycle * 3.0)) * 5.0))
		var flame_w: float = 4.5 if is_dashing else 2.5
		var flame_pts = PackedVector2Array([
			Vector2(thruster_pos.x, thruster_pos.y - flame_w),
			Vector2(thruster_pos.x + flame_len, thruster_pos.y),
			Vector2(thruster_pos.x, thruster_pos.y + flame_w)
		])
		draw_colored_polygon(flame_pts, Color(0.0, 0.95, 1.0))
		var inner_pts = PackedVector2Array([
			Vector2(thruster_pos.x, thruster_pos.y - flame_w * 0.5),
			Vector2(thruster_pos.x + flame_len * 0.5, thruster_pos.y),
			Vector2(thruster_pos.x, thruster_pos.y + flame_w * 0.5)
		])
		draw_colored_polygon(inner_pts, Color(1.0, 1.0, 1.0, 0.9))
	
	# 3. BACK HIND LEG & PAW (Deep layer)
	var hind_b_foot = Vector2(-11.0 - gallop * 0.7, 16.0)
	draw_line(Vector2(-9.0, 6.0 + spine_bob), hind_b_foot + Vector2(0, -5), Color(0.16, 0.22, 0.28), 3.5)
	draw_line(hind_b_foot + Vector2(0, -5), hind_b_foot, Color(0.12, 0.16, 0.22), 3.0)
	draw_rect(Rect2(hind_b_foot.x - 3, hind_b_foot.y - 2, 6, 4), Color(0.08, 0.1, 0.14))
	
	# 4. BACK FORELEG & PAW (Deep layer)
	var fore_b_foot = Vector2(10.0 + gallop * 0.7, 16.0)
	draw_line(Vector2(8.0, 6.0 + spine_bob), fore_b_foot + Vector2(0, -5), Color(0.16, 0.22, 0.28), 3.5)
	draw_line(fore_b_foot + Vector2(0, -5), fore_b_foot, Color(0.12, 0.16, 0.22), 3.0)
	draw_rect(Rect2(fore_b_foot.x - 2, fore_b_foot.y - 2, 6, 4), Color(0.08, 0.1, 0.14))
	
	# 5. SLEEK ARMORED CANINE TORSO (Matching Leon's armor)
	var torso_pts = PackedVector2Array([
		Vector2(-12.0, 4.0 + spine_bob),
		Vector2(1.0, 1.0 + spine_bob),
		Vector2(11.0, 4.0 + spine_bob),
		Vector2(9.0, 11.0 + spine_bob),
		Vector2(-9.0, 11.0 + spine_bob)
	])
	draw_colored_polygon(torso_pts, Color(0.25, 0.32, 0.4))
	draw_polyline(torso_pts, Color(0.14, 0.18, 0.24), 1.5)
	
	# Glowing Cyan Fusion Core on Chest Harness
	draw_circle(Vector2(2.0, 7.0 + spine_bob), 2.4, Color(0.0, 0.95, 1.0))
	draw_circle(Vector2(2.0, 7.0 + spine_bob), 1.2, Color(1.0, 1.0, 1.0))
	
	# Tactical belt detail
	draw_rect(Rect2(-8, 9.0 + spine_bob, 5, 2), Color(0.6, 0.45, 0.2))
	
	# 6. FRONT HIND LEG & PAW (Foreground layer)
	var hind_f_foot = Vector2(-9.0 + gallop, 16.0)
	draw_line(Vector2(-8.0, 6.0 + spine_bob), hind_f_foot + Vector2(-1, -5), Color(0.2, 0.28, 0.36), 4.5)
	draw_circle(hind_f_foot + Vector2(-1, -5), 2.2, Color(0.35, 0.45, 0.55)) # Cyber joint
	draw_line(hind_f_foot + Vector2(-1, -5), hind_f_foot, Color(0.16, 0.22, 0.3), 3.5)
	draw_rect(Rect2(hind_f_foot.x - 3, hind_f_foot.y - 2, 7, 4), Color(0.08, 0.1, 0.14))
	
	# 7. FRONT FORELEG & PAW (Foreground layer)
	var fore_f_foot = Vector2(10.0 - gallop, 16.0)
	draw_line(Vector2(9.0, 6.0 + spine_bob), fore_f_foot + Vector2(1, -5), Color(0.2, 0.28, 0.36), 4.5)
	draw_circle(fore_f_foot + Vector2(1, -5), 2.2, Color(0.35, 0.45, 0.55)) # Cyber joint
	draw_line(fore_f_foot + Vector2(1, -5), fore_f_foot, Color(0.16, 0.22, 0.3), 3.5)
	draw_rect(Rect2(fore_f_foot.x - 2, fore_f_foot.y - 2, 7, 4), Color(0.08, 0.1, 0.14))
	
	# 8. CYBER HOUND HEAD, EARS, AND GLOWING VISOR
	var head_pos = Vector2(12.0, 2.0 + spine_bob)
	# Cranium & Muzzle
	draw_rect(Rect2(head_pos.x - 3, head_pos.y - 5, 8, 8), Color(0.16, 0.18, 0.22))
	draw_rect(Rect2(head_pos.x + 5, head_pos.y - 2, 7, 5), Color(0.22, 0.28, 0.35))
	
	# Spiky cyber hair / crest
	draw_rect(Rect2(head_pos.x - 4, head_pos.y - 8, 7, 4), Color(0.18, 0.14, 0.12))
	var crest = PackedVector2Array([
		Vector2(head_pos.x - 2, head_pos.y - 8),
		Vector2(head_pos.x - 8, head_pos.y - 6),
		Vector2(head_pos.x - 3, head_pos.y - 3)
	])
	draw_colored_polygon(crest, Color(0.18, 0.14, 0.12))
	
	# Alert Cyber Ear
	var ear_pts = PackedVector2Array([
		Vector2(head_pos.x - 1, head_pos.y - 5),
		Vector2(head_pos.x + 2, head_pos.y - 10),
		Vector2(head_pos.x + 4, head_pos.y - 5)
	])
	draw_colored_polygon(ear_pts, Color(0.25, 0.32, 0.4))
	draw_line(Vector2(head_pos.x + 2, head_pos.y - 10), Vector2(head_pos.x + 2, head_pos.y - 5), Color(0.0, 0.95, 1.0), 1.0)
	
	# Glowing Cyan Cyber Visor (Matching Leon)
	var visor_origin = Vector2(head_pos.x + 3.0, head_pos.y - 4)
	draw_rect(Rect2(visor_origin.x - 1, visor_origin.y - 1, 7, 4), Color(0.08, 0.1, 0.14))
	draw_rect(Rect2(visor_origin.x, visor_origin.y, 5, 2), Color(0.0, 0.95, 1.0))
	draw_line(visor_origin + Vector2(1, 1), visor_origin + Vector2(5, 1), Color(1.0, 1.0, 1.0), 1.0)
	
	# 9. ENERGIZED RAZOR FANGS & ZOMBIE SHREDDER JAWS
	var jaw_y = head_pos.y + 3.0
	draw_rect(Rect2(head_pos.x + 6, jaw_y, 6, 2), Color(0.12, 0.15, 0.2))
	# Glowing cyan energy fangs
	draw_line(Vector2(head_pos.x + 8, jaw_y), Vector2(head_pos.x + 9, jaw_y + 3), Color(0.0, 0.95, 1.0), 1.5)
	draw_line(Vector2(head_pos.x + 11, jaw_y), Vector2(head_pos.x + 12, jaw_y + 3), Color(0.0, 0.95, 1.0), 1.5)
	
	# 10. CYBER SHRED ENERGY AURA (Active in dog form)
	if is_moving or is_dashing:
		var aura_time = Time.get_ticks_msec() * 0.015
		for k in range(3):
			var ax = head_pos.x + 7.0 + k * 4.0
			var ay = jaw_y + sin(aura_time + k) * 3.0
			draw_line(Vector2(ax, ay), Vector2(ax + 3, ay - 2), Color(0.0, 0.95, 1.0, 0.8), 1.5)

