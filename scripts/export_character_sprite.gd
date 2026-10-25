extends Node

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(512, 512)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub_viewport)
	
	var camera = Camera2D.new()
	camera.position = Vector2(-4.0, -2.5) # Perfectly centered on character
	camera.zoom = Vector2(8.5, 8.5)       # Crisp high-res zoom
	sub_viewport.add_child(camera)
	
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate() as RunnerController
	sub_viewport.add_child(player)
	player.position = Vector2.ZERO
	player.facing = 1
	player.preview_idle = true # Grounded idle pose (no jump flame, neutral stance)
	player.set_physics_process(false)
	player.set_process(false)
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").enabled = false
	
	player.get_node("Visuals").queue_redraw()
	
	for i in range(12):
		await get_tree().process_frame
	
	# Capture clean character sprite
	var tex = sub_viewport.get_texture()
	var img = tex.get_image()
	if img:
		img.save_png("res://player_character.png")
		img.save_png("res://player_character_exact.png")
		print("Character sprite saved to res://player_character.png")
	
	get_tree().quit()

