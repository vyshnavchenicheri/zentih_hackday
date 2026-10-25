extends SceneTree

func _init() -> void:
	print("--- RUNNING UPDATED LEONIDAS SYSTEMS VERIFICATION ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
	
	# Give scene a frame to initialize
	await process_frame
	
	var player = root_node.get_node_or_null("Player") as RunnerController
	var hud = root_node.get_node_or_null("HUD") as HUDController
	var gen = root_node.get_node_or_null("LevelGenerator") as ProceduralLevelGenerator
	var bgm = root_node.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	
	assert(player != null, "Player must exist")
	assert(hud != null, "HUD must exist")
	assert(gen != null, "LevelGenerator must exist")
	assert(bgm != null, "BGMPlayer must exist")
	assert(bgm.stream != null, "BGMPlayer stream must be loaded")
	print("  PASS: BGMPlayer loaded with audio stream: %s" % bgm.stream.resource_path)
	
	print("[CHECK 1] Skyfall Initial State & Close-up Camera Zoom")
	assert(player.game_state == RunnerController.GameState.SKYFALL, "Player should start in SKYFALL")
	assert(player.camera != null, "Player must have Camera2D")
	assert(player.camera.zoom.x >= 1.8, "Camera zoom must be zoomed in close-up (>= 1.8)")
	print("  PASS: Skyfall zoom is close up = %s" % str(player.camera.zoom))
	
	print("[CHECK 2] Invulnerability during Skyfall & Title Menu")
	player.take_damage(50.0)
	assert(player.current_hp == 100.0, "Player must take ZERO damage during skyfall")
	print("  PASS: Player is completely invulnerable during Skyfall")
	
	print("[CHECK 3] Skyfall Drop & Landing Impact Effect")
	var frames = 0
	while player.game_state == RunnerController.GameState.SKYFALL and frames < 120:
		await physics_frame
		frames += 1
	
	assert(player.game_state == RunnerController.GameState.TITLE_MENU, "Player should land into TITLE_MENU")
	assert(player.landing_crouch_timer > 0.0, "Landing crouch timer should be active")
	assert(player.trauma > 0.5, "Landing impact screen shake trauma must be triggered")
	print("  PASS: Landed on floor. Trauma = %f, State = TITLE_MENU" % player.trauma)
	
	# Still invulnerable during Title Menu
	player.take_damage(50.0)
	assert(player.current_hp == 100.0, "Player must take ZERO damage during Title Menu")
	print("  PASS: Player is completely invulnerable during Title Menu")
	
	print("[CHECK 4] Polished Title Menu Screen & Hound Counter on Bottom HUD")
	assert(hud.title_menu_overlay.visible == true, "Title menu overlay must be visible")
	var title_lbl = hud.title_menu_overlay.find_child("TitleLabel", true, false) as Label
	assert(title_lbl != null and title_lbl.text == "LEONIDAS", "Title must say LEONIDAS")
	
	# Verify hound counter on bottom HUD
	assert(hud.hound_status_label != null, "Hound status label must NOT be null")
	assert(hud.hound_progress_bar != null, "Hound progress bar must NOT be null")
	assert("0/10" in hud.hound_status_label.text, "Hound status label must show 0/10 DOGS, got: %s" % hud.hound_status_label.text)
	print("  PASS: Bottom hound counter is WORKING properly! Label = '%s'" % hud.hound_status_label.text)
	
	print("[CHECK 5] Start Game & Camera Zoom Out")
	player.start_game()
	await process_frame
	assert(player.game_state == RunnerController.GameState.PLAYING, "State should be PLAYING")
	assert(player.target_zoom.x <= 1.2, "Camera target zoom should zoom out to <= 1.2")
	print("  PASS: Game started, target zoom set to wide view: %s" % str(player.target_zoom))
	
	print("[CHECK 6] Dash 1.0s Cooldown Verification")
	assert(player.dash_cooldown == 1.0, "Dash cooldown should be 1.0s")
	player.trigger_momentary_dash()
	assert(player.dash_cooldown_timer > 0.8 and player.dash_cooldown_timer <= 1.0, "Dash cooldown timer should be ~1.0s")
	player.is_dashing = false
	player.dash_timer = 0.0
	print("  PASS: Dash strictly enforces 1.0s cooldown")
	
	print("[CHECK 7] Slide 1.0s Cooldown Verification")
	assert(player.slide_cooldown == 1.0, "Slide cooldown should be 1.0s")
	player.velocity.x = 400.0
	player.trigger_slide()
	assert(player.is_sliding == true, "Player should be sliding")
	assert(player.slide_cooldown_timer > 0.8 and player.slide_cooldown_timer <= 1.0, "Slide cooldown timer should be ~1.0s")
	# Try sliding again immediately
	player.is_sliding = false
	player.slide_timer = 0.0
	player.trigger_slide()
	assert(player.is_sliding == false, "Slide must be BLOCKED by 1.0s cooldown")
	print("  PASS: Slide strictly enforces 1.0s cooldown")
	
	print("[CHECK 8] Double Jump 3.0s Cooldown Verification")
	player.velocity.y = 0.0
	player.jumps_left = 2
	player.trigger_jump() # Ground jump
	assert(player.double_jump_cooldown_timer == 0.0, "Ground jump has no cooldown")
	await physics_frame
	await physics_frame
	player.trigger_jump() # Double jump in air
	assert(player.double_jump_cooldown_timer > 2.8 and player.double_jump_cooldown_timer <= 3.0, "Double jump cooldown should be 3.0s")
	print("  PASS: Double jump strictly enforces 3.0s cooldown")
	
	print("[CHECK 9] Hound Kill Counter & Shapeshift Unlock")
	player.register_dog_kill()
	await process_frame
	assert(player.dogs_killed == 1, "Dogs killed should be 1")
	assert("1/10" in hud.hound_status_label.text, "HUD hound label must show 1/10 DOGS, got: %s" % hud.hound_status_label.text)
	assert(hud.hound_progress_bar.value == 1.0, "HUD hound progress bar must show 1.0")
	print("  PASS: Dog kill updated HUD properly: %s" % hud.hound_status_label.text)
	
	# Kill 9 more dogs
	for i in range(9):
		player.register_dog_kill()
	await process_frame
	assert(player.dogs_killed == 10, "Dogs killed should be 10")
	assert("READY" in hud.hound_status_label.text, "HUD hound label should now be READY, got: %s" % hud.hound_status_label.text)
	player.toggle_shapeshift()
	assert(player.is_shapeshifted == true, "Shapeshift should succeed after 10 dogs killed")
	print("  PASS: 10 dogs unlock Shapeshifting! HUD status: '%s'" % hud.hound_status_label.text)
	player.toggle_shapeshift()
	
	print("[CHECK 10] Physical Zombie Horde at 1000M Backward")
	var runway = gen.get_node_or_null("BackwardRunway_1000M")
	assert(runway != null, "BackwardRunway_1000M must exist")
	# Count enemies spawned on the backward runway
	var horde_count = 0
	for child in runway.get_children():
		if child.is_in_group("enemies"):
			horde_count += 1
	assert(horde_count >= 20, "Should have a real physical horde of >= 20 zombies/hounds at backward runway, got: %d" % horde_count)
	print("  PASS: Physical horde exists on backward runway! Count = %d real zombies and hounds" % horde_count)
	
	print("\n>>> ALL CHECKS COMPLETED WITH 100% SUCCESS! <<<")
	quit(0)
