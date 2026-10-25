extends Node2D
class_name ProceduralLevelGenerator

@export var player_node: Node2D
@export var chunk_width: float = 1200.0
@export var render_distance_chunks: int = 4
@export var cull_distance_chunks: int = 2

# Accessible Tier Elevations
const TIER1_CATWALK_Y: float = -140.0
const TIER2_HIGHWAY_Y: float = 0.0
const TIER3_CANAL_Y: float = 160.0

# Minimum chunks between vertical wall chutes (walls generated every once in a while)
const MIN_CHUNKS_BETWEEN_WALLS: int = 4

var next_chunk_x: float = 0.0
var active_chunks: Array[Node2D] = []
var current_chunk_platforms: Array[Rect2] = []

# Procedural elevation & chunk tracking
var current_elevation: float = TIER2_HIGHWAY_Y
var chunks_since_wall_chute: int = 0
var chunks_at_top: int = 0
var recent_highway_patterns: Array[int] = []

func _ready() -> void:
	build_backward_runway()
	for i in range(render_distance_chunks):
		spawn_next_chunk()

func build_backward_runway() -> void:
	var runway_root = Node2D.new()
	runway_root.name = "BackwardRunway_1000M"
	runway_root.position.x = 0.0
	add_child(runway_root)
	
	var plat_col = get_district_platform_color()
	# Platforms span from X = -12000.0 to 0.0 (1200 meters backwards)
	# High deck at TIER2_HIGHWAY_Y (0.0)
	create_platform(runway_root, Vector2(-12000.0, TIER2_HIGHWAY_Y), Vector2(12000.0, 32.0), plat_col)
	# Lower canal bed at TIER3_CANAL_Y (160.0)
	create_platform(runway_root, Vector2(-12000.0, TIER3_CANAL_Y), Vector2(12000.0, 50.0), Color(0.08, 0.14, 0.12))
	
	# Milestone markers every 200M backwards (2000 units)
	for m in range(200, 1201, 200):
		var marker_x = -float(m) * 10.0
		var marker = MilestoneSign.new(m)
		marker.position = Vector2(marker_x, TIER2_HIGHWAY_Y - 26.0)
		runway_root.add_child(marker)
	
	# Warning barricades marking entry into the quarantined Horde Territory (-850M to -950M)
	spawn_barricade(runway_root, Vector2(-8600.0, TIER2_HIGHWAY_Y - 44.0))
	spawn_barricade(runway_root, Vector2(-9200.0, TIER2_HIGHWAY_Y - 44.0))
	spawn_hound(runway_root, Vector2(-9400.0, TIER2_HIGHWAY_Y - 11.0), 140.0)
	
	# THE UNDEAD HORDE at 1000M+ backwards (X = -9800 to -12000):
	# Dense swarm of aggressive zombies & feral hounds charging the player in real combat!
	var horde_starts = [-9800.0, -10000.0, -10200.0, -10400.0, -10600.0, -10800.0, -11000.0, -11200.0, -11400.0, -11600.0, -11800.0]
	for hx in horde_starts:
		spawn_zombie(runway_root, Vector2(hx - 25.0, TIER2_HIGHWAY_Y - 18.0), 100.0)
		spawn_zombie(runway_root, Vector2(hx + 35.0, TIER2_HIGHWAY_Y - 18.0), 100.0)
		spawn_hound(runway_root, Vector2(hx, TIER2_HIGHWAY_Y - 11.0), 180.0, "mastiff")

func cull_old_chunks() -> void:
	if not player_node:
		return
	# Strictly preserve platforms for 1000M backwards: only cull if more than 12,000 units behind player
	var cull_x: float = min(player_node.global_position.x - 12000.0, -13000.0)
	for i in range(active_chunks.size() - 1, -1, -1):
		var chunk = active_chunks[i]
		if is_instance_valid(chunk) and chunk.position.x < cull_x:
			chunk.queue_free()
			active_chunks.remove_at(i)

func _process(_delta: float) -> void:
	if not player_node:
		return
	
	var lookahead_x: float = player_node.global_position.x + (chunk_width * 2.0)
	if lookahead_x > next_chunk_x:
		spawn_next_chunk()
	
	cull_old_chunks()

func get_area_index(x_pos: float = -1.0) -> int:
	var pos_x = next_chunk_x if x_pos < 0.0 else x_pos
	var area_idx = int(floor(pos_x / 3600.0)) % 6
	if area_idx < 0:
		area_idx += 6
	return area_idx

func get_platform_color_for_area(area_idx: int) -> Color:
	match area_idx:
		0: return Color(0.18, 0.24, 0.32) # Neo-Downtown Cyan Steel
		1: return Color(0.24, 0.18, 0.30) # Twilight Violet Ancient Timber
		2: return Color(0.32, 0.16, 0.18) # Crimson Bloodwood & Dark Iron
		3: return Color(0.32, 0.22, 0.14) # Amber Ember Timber & Scorched Rock
		4: return Color(0.26, 0.26, 0.14) # Golden Sylvan Cedar & Moss
		5: return Color(0.18, 0.14, 0.28) # Megastructure Astral Obsidian
		_: return Color(0.18, 0.24, 0.32)

func get_district_platform_color() -> Color:
	return get_platform_color_for_area(get_area_index())

func spawn_next_chunk() -> void:
	var chunk_root = Node2D.new()
	chunk_root.name = "Chunk_%d" % int(next_chunk_x)
	chunk_root.position.x = next_chunk_x
	add_child(chunk_root)
	active_chunks.append(chunk_root)
	
	current_chunk_platforms.clear()
	
	if next_chunk_x == 0.0:
		# First chunk: balanced introductory speedway with active starter zombies & shards
		build_intro_chunk(chunk_root)
		chunks_since_wall_chute = 1
	elif current_elevation == TIER2_HIGHWAY_Y:
		# Runner is on the lower highway floor
		if chunks_since_wall_chute >= MIN_CHUNKS_BETWEEN_WALLS and (chunks_since_wall_chute >= 6 or randf() > 0.35):
			# Occasional Wall Chute challenge!
			build_wall_chute_chunk(chunk_root)
			chunks_since_wall_chute = 0
			current_elevation = TIER1_CATWALK_Y
			chunks_at_top = 0
		else:
			chunks_since_wall_chute += 1
			# Choose among 7 distinct highway archetypes without repeating recent patterns
			var available: Array[int] = []
			for p in range(7):
				if not (p in recent_highway_patterns):
					available.append(p)
			if available.is_empty():
				available = [0, 1, 2, 3, 4, 5, 6]
			
			var pat: int = available[randi() % available.size()]
			recent_highway_patterns.append(pat)
			if recent_highway_patterns.size() > 3:
				recent_highway_patterns.pop_front()
			
			match pat:
				0: build_highway_swarm_chunk(chunk_root)
				1: build_highway_pipeline_chunk(chunk_root)
				2: build_highway_multilevel_chunk(chunk_root)
				3: build_highway_canal_crossing_chunk(chunk_root)
				4: build_highway_checkpoint_chunk(chunk_root)
				5: build_highway_stepped_chunk(chunk_root)
				6: build_highway_speed_gauntlet_chunk(chunk_root)
	else:
		# Runner is on the top catwalk (TIER1_CATWALK_Y)
		chunks_at_top += 1
		if chunks_at_top >= 3 and (chunks_at_top >= 5 or randf() > 0.35):
			# Scenic descent ramp returning to highway
			build_catwalk_descent_chunk(chunk_root)
			current_elevation = TIER2_HIGHWAY_Y
			chunks_at_top = 0
			chunks_since_wall_chute = 0
		else:
			# High catwalk varied layouts (with active enemies on ground floor below too!)
			if randf() > 0.5:
				build_catwalk_speedway_chunk(chunk_root)
			else:
				build_catwalk_assault_chunk(chunk_root)
	
	next_chunk_x += chunk_width

# =========================================================================
# ENEMY & INTERACTIVE OBJECT SPAWN HELPERS
# =========================================================================

func spawn_zombie(parent: Node2D, pos: Vector2, patrol_dist: float = 75.0, outfit_id: int = -1) -> InteractiveObjects.CyberEnemy:
	var zombie = InteractiveObjects.CyberEnemy.new("zombie", outfit_id)
	zombie.position = pos
	zombie.patrol_range = patrol_dist
	parent.add_child(zombie)
	return zombie

func spawn_hound(parent: Node2D, pos: Vector2, patrol_dist: float = 130.0, dog_breed: String = "") -> InteractiveObjects.CyberEnemy:
	var hound = InteractiveObjects.CyberEnemy.new("hound", -1, dog_breed)
	hound.position = pos
	hound.patrol_range = patrol_dist
	parent.add_child(hound)
	return hound

func spawn_barricade(parent: Node2D, pos: Vector2, width: float = 24.0, height: float = 44.0) -> InteractiveObjects.Barricade:
	var bar = InteractiveObjects.Barricade.new(width, height)
	bar.position = pos
	parent.add_child(bar)
	current_chunk_platforms.append(Rect2(pos, Vector2(width, height)))
	return bar

func spawn_shard(parent: Node2D, pos: Vector2) -> InteractiveObjects.CyberShard:
	var shard = InteractiveObjects.CyberShard.new()
	shard.position = pos
	parent.add_child(shard)
	return shard

func spawn_shard_row(parent: Node2D, start_x: float, y: float, count: int = 3, spacing: float = 38.0) -> void:
	for i in range(count):
		spawn_shard(parent, Vector2(start_x + i * spacing, y))

func spawn_shard_arc(parent: Node2D, start_x: float, end_x: float, base_y: float, peak_offset: float = -65.0, count: int = 5) -> void:
	for i in range(count):
		var t = float(i) / float(max(1, count - 1))
		var sx = lerpf(start_x, end_x, t)
		var sy = base_y + 4.0 * peak_offset * (t - t * t)
		spawn_shard(parent, Vector2(sx, sy))

func spawn_booster(parent: Node2D, pos: Vector2, width: float = 90.0) -> InteractiveObjects.NeonBooster:
	var booster = InteractiveObjects.NeonBooster.new(width)
	booster.position = pos
	parent.add_child(booster)
	return booster

func spawn_enemy_squad(parent: Node2D, center_x: float, y: float, squad_type: String = "duo") -> void:
	match squad_type:
		"duo":
			spawn_zombie(parent, Vector2(center_x - 20.0, y - 18.0), 60.0)
			spawn_zombie(parent, Vector2(center_x + 20.0, y - 18.0), 60.0)
		"trio":
			spawn_zombie(parent, Vector2(center_x - 38.0, y - 18.0), 50.0)
			spawn_zombie(parent, Vector2(center_x, y - 18.0), 65.0)
			spawn_zombie(parent, Vector2(center_x + 38.0, y - 18.0), 50.0)
		"hound_pack":
			spawn_hound(parent, Vector2(center_x - 26.0, y - 11.0), 120.0)
			spawn_hound(parent, Vector2(center_x + 26.0, y - 11.0), 140.0)
		"mixed":
			spawn_hound(parent, Vector2(center_x - 34.0, y - 11.0), 150.0)
			spawn_zombie(parent, Vector2(center_x + 22.0, y - 18.0), 70.0)
			spawn_zombie(parent, Vector2(center_x + 65.0, y - 18.0), 70.0)
		"ambush":
			if randf() > 0.5:
				spawn_hound(parent, Vector2(center_x, y - 11.0), 160.0)
			else:
				spawn_zombie(parent, Vector2(center_x, y - 18.0), 85.0)
		_:
			spawn_zombie(parent, Vector2(center_x, y - 18.0))

func can_spawn_jump_pad_at(pos: Vector2, pad_width: float = 50.0) -> bool:
	for rect in current_chunk_platforms:
		if rect.position.y < pos.y - 15.0:
			var plat_left: float = rect.position.x - 25.0
			var plat_right: float = rect.position.x + rect.size.x + 25.0
			var pad_left: float = pos.x
			var pad_right: float = pos.x + pad_width
			if pad_right > plat_left and pad_left < plat_right:
				return false
	return true

func try_spawn_jump_pad(parent: Node2D, pos: Vector2, pad_width: float = 50.0) -> bool:
	if can_spawn_jump_pad_at(pos, pad_width):
		var pad = InteractiveObjects.JumpPad.new(pad_width, 12.0)
		pad.position = pos
		parent.add_child(pad)
		return true
	return false

func create_low_overpass(parent: Node2D, pos: Vector2, span_width: float = 140.0, clearance: float = 28.0, thickness: float = 24.0) -> InteractiveObjects.LowOverpass:
	var overpass = InteractiveObjects.LowOverpass.new(span_width, clearance, thickness)
	overpass.position = pos
	parent.add_child(overpass)
	current_chunk_platforms.append(Rect2(pos.x, pos.y - clearance - thickness, span_width, thickness))
	return overpass

func create_wall(parent: Node2D, pos: Vector2, height: float, width: float = 24.0, color: Color = Color(0.2, 0.25, 0.32)) -> StaticBody2D:
	current_chunk_platforms.append(Rect2(pos, Vector2(width, height)))
	
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	col.shape = shape
	col.position = Vector2(width / 2.0, height / 2.0)
	body.add_child(col)
	
	var visual = WallVisual.new(width, height, color)
	body.add_child(visual)
	
	parent.add_child(body)
	return body

## Creates vertical wall chute with 56px bottom entrance gap on left wall
func create_wall_chute_with_entrance(parent: Node2D, x_left: float, top_y: float, bottom_y: float, entrance_height: float = 56.0, shaft_width: float = 96.0, wall_w: float = 24.0) -> void:
	var left_top_y: float = top_y - 25.0
	var left_bot_y: float = bottom_y - entrance_height
	var left_height: float = left_bot_y - left_top_y
	if left_height > 10.0:
		create_wall(parent, Vector2(x_left, left_top_y), left_height, wall_w, Color(0.2, 0.26, 0.34))
		var lintel = DoorwayLintelVisual.new(wall_w + 12.0, 10.0)
		lintel.position = Vector2(x_left - 6.0, left_bot_y - 10.0)
		parent.add_child(lintel)
	
	var right_x: float = x_left + wall_w + shaft_width
	var right_height: float = bottom_y - top_y
	create_wall(parent, Vector2(right_x, top_y), right_height, wall_w, Color(0.2, 0.26, 0.34))

# Compatibility helper
func build_accessible_chunk(parent: Node2D, pattern: int) -> void:
	match pattern:
		0: build_intro_chunk(parent)
		1: build_highway_swarm_chunk(parent)
		2: build_highway_pipeline_chunk(parent)
		3: build_wall_chute_chunk(parent)
		4: build_catwalk_speedway_chunk(parent)
		5: build_catwalk_descent_chunk(parent)
		_: build_highway_swarm_chunk(parent)

# =========================================================================
# RICH HIGHWAY CHUNK ARCHETYPES (DENSE FLOOR COMBAT & DIVERSE LAYOUTS)
# =========================================================================

## Intro Starter Chunk (Chunk 0): Smooth runway with active starter encounters
func build_intro_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	# Safe Starting Landing Area: Clear space from X=0 to 320 for dramatic skyfall impact
	spawn_shard_row(parent, 340, TIER2_HIGHWAY_Y - 24, 3)
	spawn_zombie(parent, Vector2(520, TIER2_HIGHWAY_Y - 18), 60.0)
	spawn_enemy_squad(parent, 720, TIER2_HIGHWAY_Y, "duo")
	
	create_low_overpass(parent, Vector2(880, TIER2_HIGHWAY_Y), 130.0, 28.0)
	spawn_hound(parent, Vector2(1060, TIER2_HIGHWAY_Y - 11), 120.0)

## Archetype 1: "The Undead Swarm Highway" (High-density horde combat)
func build_highway_swarm_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	spawn_enemy_squad(parent, 190 + randf_range(-20, 20), TIER2_HIGHWAY_Y, "duo")
	spawn_shard_row(parent, 300, TIER2_HIGHWAY_Y - 24, 3)
	
	spawn_barricade(parent, Vector2(430 + randf_range(-15, 15), TIER2_HIGHWAY_Y - 44))
	spawn_hound(parent, Vector2(500, TIER2_HIGHWAY_Y - 11), 100.0)
	
	spawn_enemy_squad(parent, 720 + randf_range(-20, 20), TIER2_HIGHWAY_Y, "trio")
	spawn_shard_row(parent, 840, TIER2_HIGHWAY_Y - 24, 3)
	
	spawn_enemy_squad(parent, 1020 + randf_range(-20, 20), TIER2_HIGHWAY_Y, "hound_pack")

## Archetype 2: "Industrial Pipeline Expressway" (Slide gauntlet & ambushes with 28px clearance)
func build_highway_pipeline_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	# Pipeline 1 with 28px clearance
	create_low_overpass(parent, Vector2(180, TIER2_HIGHWAY_Y), 130.0, 28.0)
	spawn_zombie(parent, Vector2(360, TIER2_HIGHWAY_Y - 18), 80.0)
	
	spawn_barricade(parent, Vector2(520, TIER2_HIGHWAY_Y - 44))
	spawn_enemy_squad(parent, 620, TIER2_HIGHWAY_Y, "duo")
	
	# Pipeline 2
	create_low_overpass(parent, Vector2(740, TIER2_HIGHWAY_Y), 140.0, 28.0)
	spawn_hound(parent, Vector2(940, TIER2_HIGHWAY_Y - 11), 140.0)
	spawn_zombie(parent, Vector2(1080, TIER2_HIGHWAY_Y - 18), 70.0)

## Archetype 3: "Multi-Tier Split Expressway" (Ground horde vs elevated skybridge)
func build_highway_multilevel_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	try_spawn_jump_pad(parent, Vector2(160, TIER2_HIGHWAY_Y - 12))
	spawn_shard_arc(parent, 180, 360, TIER2_HIGHWAY_Y, -85.0, 5)
	
	# Upper Catwalk Shelf (Elevation y = -100)
	create_platform(parent, Vector2(300, -100), Vector2(580, 24), Color(0.18, 0.32, 0.42))
	create_low_overpass(parent, Vector2(460, -100), 120.0, 28.0)
	spawn_zombie(parent, Vector2(720, -118), 80.0)
	spawn_shard_row(parent, 600, -125, 3)
	
	# Lower floor combat
	spawn_enemy_squad(parent, 360, TIER2_HIGHWAY_Y, "duo")
	spawn_barricade(parent, Vector2(540, TIER2_HIGHWAY_Y - 44))
	spawn_hound(parent, Vector2(660, TIER2_HIGHWAY_Y - 11), 120.0)
	spawn_enemy_squad(parent, 940, TIER2_HIGHWAY_Y, "mixed")

## Archetype 4: "Toxic Canal Crossings" (Canal leaps & waiting predators)
func build_highway_canal_crossing_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	var sludge = InteractiveObjects.SludgeHazard.new(340.0, 30.0)
	sludge.position = Vector2(350, TIER3_CANAL_Y + 12)
	parent.add_child(sludge)
	
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(360, 32), plat_col)
	spawn_enemy_squad(parent, 180, TIER2_HIGHWAY_Y, "duo")
	
	try_spawn_jump_pad(parent, Vector2(280, TIER2_HIGHWAY_Y - 12))
	spawn_shard_arc(parent, 300, 600, TIER2_HIGHWAY_Y, -90.0, 6)
	
	create_platform(parent, Vector2(580, TIER2_HIGHWAY_Y), Vector2(chunk_width - 580, 32), plat_col)
	spawn_hound(parent, Vector2(640, TIER2_HIGHWAY_Y - 11), 110.0)
	spawn_barricade(parent, Vector2(800, TIER2_HIGHWAY_Y - 44))
	spawn_enemy_squad(parent, 960, TIER2_HIGHWAY_Y, "trio")

## Archetype 5: "Military Checkpoint Breach" (Heavily fortified highway roadblock)
func build_highway_checkpoint_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	spawn_barricade(parent, Vector2(220, TIER2_HIGHWAY_Y - 44))
	spawn_zombie(parent, Vector2(280, TIER2_HIGHWAY_Y - 18), 70.0)
	spawn_shard_row(parent, 360, TIER2_HIGHWAY_Y - 24, 3)
	
	spawn_hound(parent, Vector2(520, TIER2_HIGHWAY_Y - 11), 150.0)
	
	spawn_barricade(parent, Vector2(720, TIER2_HIGHWAY_Y - 44))
	spawn_enemy_squad(parent, 820, TIER2_HIGHWAY_Y, "duo")
	
	create_low_overpass(parent, Vector2(940, TIER2_HIGHWAY_Y), 130.0, 28.0)
	spawn_zombie(parent, Vector2(1110, TIER2_HIGHWAY_Y - 18), 60.0)

## Archetype 6: "Stepped Highway Ramps" (Dynamic road elevations)
func build_highway_stepped_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(220, 32), plat_col)
	spawn_zombie(parent, Vector2(130, TIER2_HIGHWAY_Y - 18), 60.0)
	
	create_ramp(parent, Vector2(220, TIER2_HIGHWAY_Y), Vector2(460, -50.0))
	
	create_platform(parent, Vector2(460, -50.0), Vector2(360, 28), Color(0.24, 0.32, 0.4))
	spawn_hound(parent, Vector2(540, -61.0), 120.0)
	spawn_zombie(parent, Vector2(700, -68.0), 70.0)
	spawn_shard_row(parent, 600, -74.0, 3)
	
	create_ramp(parent, Vector2(820, -50.0), Vector2(1000, TIER2_HIGHWAY_Y))
	
	create_platform(parent, Vector2(1000, TIER2_HIGHWAY_Y), Vector2(chunk_width - 1000, 32), plat_col)
	spawn_enemy_squad(parent, 1080, TIER2_HIGHWAY_Y, "duo")

## Archetype 7: "Neon Speed Gauntlet" (Booster pads, slide hurdles & charging hounds)
func build_highway_speed_gauntlet_chunk(parent: Node2D) -> void:
	var plat_col = get_district_platform_color()
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 32), plat_col)
	
	# Speed booster strip 1
	spawn_booster(parent, Vector2(120, TIER2_HIGHWAY_Y - 8))
	spawn_enemy_squad(parent, 320, TIER2_HIGHWAY_Y, "duo")
	
	# Low overhead girder with generous clearance
	create_low_overpass(parent, Vector2(460, TIER2_HIGHWAY_Y), 130.0, 28.0)
	
	# Speed booster strip 2
	spawn_booster(parent, Vector2(660, TIER2_HIGHWAY_Y - 8))
	spawn_shard_row(parent, 780, TIER2_HIGHWAY_Y - 24, 4)
	
	# Charging hound pack on straightaway
	spawn_enemy_squad(parent, 980, TIER2_HIGHWAY_Y, "hound_pack")

# =========================================================================
# WALL CHUTE & CATWALK ARCHETYPES
# =========================================================================

## Occasional Vertical Wall Chute (Left entrance gap + base platform at top)
func build_wall_chute_chunk(parent: Node2D) -> void:
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	var sludge = InteractiveObjects.SludgeHazard.new(340.0, 30.0)
	sludge.position = Vector2(560, TIER3_CANAL_Y + 12)
	parent.add_child(sludge)
	
	var left_wall_x: float = 360.0
	var wall_w: float = 24.0
	var shaft_width: float = 96.0
	var right_wall_x: float = left_wall_x + wall_w + shaft_width # 480.0
	
	# 1. Approach Highway (Floor) leading into the entrance gap
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(right_wall_x, 32), Color(0.2, 0.25, 0.32))
	spawn_enemy_squad(parent, 180, TIER2_HIGHWAY_Y, "duo")
	spawn_barricade(parent, Vector2(270, TIER2_HIGHWAY_Y - 44))
	
	# 2. Wall Chute with 56px Entrance Gap on Left Wall
	create_wall_chute_with_entrance(parent, left_wall_x, TIER1_CATWALK_Y, TIER2_HIGHWAY_Y, 56.0, shaft_width, wall_w)
	
	# 3. BASE PLATFORM AT THE TOP:
	var top_plat_x: float = right_wall_x
	var top_plat_w: float = chunk_width - top_plat_x
	create_platform(parent, Vector2(top_plat_x, TIER1_CATWALK_Y), Vector2(top_plat_w, 32), Color(0.16, 0.36, 0.46))
	
	create_low_overpass(parent, Vector2(top_plat_x + 180.0, TIER1_CATWALK_Y), 130.0, 28.0)
	spawn_hound(parent, Vector2(top_plat_x + 380.0, TIER1_CATWALK_Y - 11), 120.0)
	spawn_enemy_squad(parent, top_plat_x + 540.0, TIER1_CATWALK_Y, "duo")

## Catwalk Speedway (High Tier 1 + Lower Highway Floor populated below)
func build_catwalk_speedway_chunk(parent: Node2D) -> void:
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	
	# LOWER HIGHWAY FLOOR BELOW (Active living world with zombies below catwalk)
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 24), Color(0.15, 0.18, 0.24))
	spawn_zombie(parent, Vector2(300, TIER2_HIGHWAY_Y - 18), 90.0)
	spawn_hound(parent, Vector2(740, TIER2_HIGHWAY_Y - 11), 130.0)
	
	# HIGH CATWALK (Current Base Platform)
	create_platform(parent, Vector2(0, TIER1_CATWALK_Y), Vector2(chunk_width, 32), Color(0.14, 0.34, 0.44))
	spawn_enemy_squad(parent, 220, TIER1_CATWALK_Y, "duo")
	create_low_overpass(parent, Vector2(440, TIER1_CATWALK_Y), 140.0, 28.0)
	spawn_shard_row(parent, 620, TIER1_CATWALK_Y - 24, 3)
	spawn_hound(parent, Vector2(800, TIER1_CATWALK_Y - 11), 130.0)
	spawn_enemy_squad(parent, 1020, TIER1_CATWALK_Y, "duo")

## Catwalk Assault (High Tier 1 gaps, hound packs & aerial leaps)
func build_catwalk_assault_chunk(parent: Node2D) -> void:
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width, 24), Color(0.15, 0.18, 0.24))
	spawn_enemy_squad(parent, 500, TIER2_HIGHWAY_Y, "duo")
	
	# Catwalk Section 1
	create_platform(parent, Vector2(0, TIER1_CATWALK_Y), Vector2(400, 32), Color(0.14, 0.34, 0.44))
	spawn_zombie(parent, Vector2(180, TIER1_CATWALK_Y - 18), 70.0)
	try_spawn_jump_pad(parent, Vector2(300, TIER1_CATWALK_Y - 12))
	spawn_shard_arc(parent, 320, 580, TIER1_CATWALK_Y, -80.0, 5)
	
	# Catwalk Section 2
	create_platform(parent, Vector2(580, TIER1_CATWALK_Y), Vector2(chunk_width - 580, 32), Color(0.14, 0.34, 0.44))
	spawn_enemy_squad(parent, 700, TIER1_CATWALK_Y, "hound_pack")
	spawn_barricade(parent, Vector2(880, TIER1_CATWALK_Y - 44))
	spawn_enemy_squad(parent, 1020, TIER1_CATWALK_Y, "duo")

## Catwalk Descent Ramp (Smooth transition from Tier 1 Catwalk back to Tier 2 Highway)
func build_catwalk_descent_chunk(parent: Node2D) -> void:
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	
	create_platform(parent, Vector2(0, TIER1_CATWALK_Y), Vector2(200, 32), Color(0.14, 0.34, 0.44))
	spawn_zombie(parent, Vector2(100, TIER1_CATWALK_Y - 18), 60.0)
	
	create_ramp(parent, Vector2(200, TIER1_CATWALK_Y), Vector2(600, TIER2_HIGHWAY_Y))
	spawn_zombie(parent, Vector2(400, -70.0), 60.0)
	
	create_platform(parent, Vector2(600, TIER2_HIGHWAY_Y), Vector2(chunk_width - 600, 32), Color(0.2, 0.25, 0.32))
	spawn_hound(parent, Vector2(720, TIER2_HIGHWAY_Y - 11), 130.0)
	spawn_enemy_squad(parent, 940, TIER2_HIGHWAY_Y, "trio")

# =========================================================================
# HELPER PLATFORM & VISUAL BUILDERS
# =========================================================================

func create_platform(parent: Node2D, pos: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	current_chunk_platforms.append(Rect2(pos, size))
	
	var body = StaticBody2D.new()
	body.position = pos
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = size / 2.0
	body.add_child(col)
	
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(size.x, 0),
		Vector2(size.x, size.y),
		Vector2(0, size.y)
	])
	poly.color = color
	body.add_child(poly)
	
	parent.add_child(body)
	return body

func create_ramp(parent: Node2D, start_pos: Vector2, end_pos: Vector2) -> StaticBody2D:
	var thickness: float = 24.0
	var min_x = min(start_pos.x, end_pos.x)
	var max_x = max(start_pos.x, end_pos.x)
	var min_y = min(start_pos.y, end_pos.y)
	var max_y = max(start_pos.y, end_pos.y) + thickness
	current_chunk_platforms.append(Rect2(min_x, min_y, max_x - min_x, max_y - min_y))
	
	var body = StaticBody2D.new()
	var poly = Polygon2D.new()
	
	poly.polygon = PackedVector2Array([
		start_pos,
		end_pos,
		end_pos + Vector2(0, thickness),
		start_pos + Vector2(0, thickness)
	])
	poly.color = Color(0.22, 0.3, 0.38)
	body.add_child(poly)
	
	var col = CollisionPolygon2D.new()
	col.polygon = poly.polygon
	body.add_child(col)
	
	parent.add_child(body)
	return body

# Inner class for visually rich vertical blast walls with neon grip grooves
class WallVisual extends Node2D:
	var wall_width: float
	var wall_height: float
	var base_color: Color
	
	func _init(w: float, h: float, col: Color) -> void:
		wall_width = w
		wall_height = h
		base_color = col
	
	func _draw() -> void:
		draw_rect(Rect2(0, 0, wall_width, wall_height), base_color)
		draw_rect(Rect2(2, 2, wall_width - 4, wall_height - 4), Color(0.12, 0.16, 0.22))
		
		var step: float = 24.0
		var count: int = int(wall_height / step)
		for i in range(count):
			var gy: float = 12.0 + i * step
			draw_line(Vector2(3, gy), Vector2(wall_width - 3, gy), Color(0.0, 0.85, 0.95, 0.8), 2.0)
			draw_rect(Rect2(wall_width / 2.0 - 1, gy - 1, 2, 2), Color(0.95, 0.65, 0.15))
		
		draw_rect(Rect2(0, 0, wall_width, 4), Color(0.95, 0.6, 0.1))
		draw_rect(Rect2(0, wall_height - 4, wall_width, 4), Color(0.95, 0.6, 0.1))

# Inner class for the doorway lintel marking the entrance under the left wall
class DoorwayLintelVisual extends Node2D:
	var lintel_width: float
	var lintel_height: float
	
	func _init(w: float, h: float) -> void:
		lintel_width = w
		lintel_height = h
	
	func _draw() -> void:
		draw_rect(Rect2(0, 0, lintel_width, lintel_height), Color(0.12, 0.16, 0.22))
		draw_rect(Rect2(1, 1, lintel_width - 2, lintel_height - 2), Color(0.24, 0.32, 0.42))
		draw_line(Vector2(2, lintel_height - 1), Vector2(lintel_width - 2, lintel_height - 1), Color(1.0, 0.72, 0.1, 0.95), 2.0)
		draw_line(Vector2(6, 2), Vector2(12, lintel_height / 2.0), Color(0.0, 0.9, 1.0, 0.9), 2.0)
		draw_line(Vector2(12, lintel_height / 2.0), Vector2(6, lintel_height - 2), Color(0.0, 0.9, 1.0, 0.9), 2.0)
		draw_circle(Vector2(lintel_width - 6, lintel_height / 2.0), 2.5, Color(0.1, 1.0, 0.4, 0.95))

# Visual signpost for backward milestone markers
class MilestoneSign extends Node2D:
	var meters: int
	
	func _init(m: int) -> void:
		meters = m
	
	func _draw() -> void:
		# Post
		draw_line(Vector2(0, 0), Vector2(0, 26), Color(0.2, 0.26, 0.35), 4.0)
		# Holographic / Cyber Signboard
		var sign_col = Color(0.8, 0.15, 0.15) if meters >= 1000 else Color(0.95, 0.55, 0.1)
		draw_rect(Rect2(-24, -18, 48, 18), Color(0.08, 0.12, 0.16, 0.9))
		draw_rect(Rect2(-24, -18, 48, 18), sign_col, false, 1.5)
		# Flashing beacon at top
		var beacon_col = Color(1.0, 0.2, 0.2) if meters >= 1000 else Color(1.0, 0.8, 0.2)
		draw_circle(Vector2(0, -22), 3.0, beacon_col)

