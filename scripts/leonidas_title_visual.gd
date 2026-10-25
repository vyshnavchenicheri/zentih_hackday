extends Control
class_name LeonidasTitleVisual

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var time: float = Time.get_ticks_msec() * 0.003
	
	# Cyber outer border with chamfered corners
	var col_neon = Color(0.0, 0.95, 1.0)
	var col_amber = Color(0.95, 0.65, 0.15)
	
	# Top and bottom framing lines
	draw_line(Vector2(20, 4), Vector2(w - 20, 4), col_neon, 2.0)
	draw_line(Vector2(30, 8), Vector2(w - 30, 8), Color(col_neon.r, col_neon.g, col_neon.b, 0.35), 1.0)
	draw_line(Vector2(20, h - 4), Vector2(w - 20, h - 4), col_neon, 2.0)
	draw_line(Vector2(30, h - 8), Vector2(w - 30, h - 8), Color(col_neon.r, col_neon.g, col_neon.b, 0.35), 1.0)
	
	# Left & right cyber corner brackets
	# Top-left bracket
	draw_line(Vector2(4, 20), Vector2(4, 8), col_neon, 2.5)
	draw_line(Vector2(4, 8), Vector2(16, 4), col_neon, 2.5)
	# Top-right bracket
	draw_line(Vector2(w - 4, 20), Vector2(w - 4, 8), col_neon, 2.5)
	draw_line(Vector2(w - 4, 8), Vector2(w - 16, 4), col_neon, 2.5)
	# Bottom-left bracket
	draw_line(Vector2(4, h - 20), Vector2(4, h - 8), col_neon, 2.5)
	draw_line(Vector2(4, h - 8), Vector2(16, h - 4), col_neon, 2.5)
	# Bottom-right bracket
	draw_line(Vector2(w - 4, h - 20), Vector2(w - 4, h - 8), col_neon, 2.5)
	draw_line(Vector2(w - 4, h - 8), Vector2(w - 16, h - 4), col_neon, 2.5)
	
	# Tactical tick marks on sides
	for i in range(3):
		var ty = h / 2.0 - 12.0 + i * 12.0
		draw_line(Vector2(8, ty), Vector2(14, ty), col_amber, 1.5)
		draw_line(Vector2(w - 14, ty), Vector2(w - 8, ty), col_amber, 1.5)
	
	# Pulsing scanline laser sweep
	var scan_y = fmod(time * 35.0, max(1.0, h - 16.0)) + 8.0
	draw_line(Vector2(12, scan_y), Vector2(w - 12, scan_y), Color(col_neon.r, col_neon.g, col_neon.b, 0.22), 1.5)
