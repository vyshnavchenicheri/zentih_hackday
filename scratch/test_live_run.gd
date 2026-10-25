extends SceneTree

func _init() -> void:
	print("--- TESTING MAIN SCENE IN LIVE RUNTIME (60 FRAMES) ---")
	var main_scene = load("res://scenes/main.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
	
	for f in range(60):
		await process_frame
	
	print("60 frames completed with ZERO crashes!")
	quit(0)
