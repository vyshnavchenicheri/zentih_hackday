extends Node2D
class_name BackgroundVisuals

@export var layer_type: String = "sky"

func _draw() -> void:
	match layer_type:
		"sky":
			# Draw wide radioactive sky gradient & moon
			var sky_rect = Rect2(-4000, -1000, 60000, 2000)
			draw_rect(sky_rect, Color(0.04, 0.08, 0.07))
			# Distant toxic smog moon
			draw_circle(Vector2(600, -200), 100.0, Color(0.9, 0.7, 0.2, 0.18))
			draw_circle(Vector2(600, -200), 75.0, Color(0.95, 0.8, 0.3, 0.25))
		"far_city":
			# Distant smokestacks & ruin silhouettes
			for x in range(-4000, 60000, 140):
				var h: float = 140.0 + fmod(abs(x * 17.0), 120.0)
				draw_rect(Rect2(x, 100 - h, 80, h + 200), Color(0.06, 0.1, 0.09))
				draw_rect(Rect2(x + 90, 60 - (h * 0.5), 18, 200), Color(0.05, 0.09, 0.08))
		"mid_overpass":
			# Ruined highway overpass deck & pillars
			for x in range(-4000, 60000, 320):
				draw_rect(Rect2(x + 40, -120, 40, 400), Color(0.1, 0.14, 0.18)) # pillar
				draw_rect(Rect2(x - 40, -140, 380, 24), Color(0.13, 0.17, 0.22)) # deck
