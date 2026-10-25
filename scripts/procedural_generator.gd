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

var next_chunk_x: float = 0.0
var active_chunks: Array[Node2D] = []
var current_chunk_platforms: Array[Rect2] = []

func _ready() -> void:
	for i in range(render_distance_chunks):
		spawn_next_chunk()

func _process(_delta: float) -> void:
	if not player_node:
		return
	
	var lookahead_x: float = player_node.global_position.x + (chunk_width * 2.0)
	if lookahead_x > next_chunk_x:
		spawn_next_chunk()
	
	cull_old_chunks()

func spawn_next_chunk() -> void:
	var chunk_root = Node2D.new()
	chunk_root.name = "Chunk_%d" % int(next_chunk_x)
	chunk_root.position.x = next_chunk_x
	add_child(chunk_root)
	active_chunks.append(chunk_root)
	
	current_chunk_platforms.clear()
	var pattern_type: int = randi() % 4
	build_accessible_chunk(chunk_root, pattern_type)
	
	next_chunk_x += chunk_width

func can_spawn_jump_pad_at(pos: Vector2, pad_width: float = 50.0) -> bool:
	# Check whether any platform in the chunk sits directly above this jump pad's launch zone
	for rect in current_chunk_platforms:
		# If platform is vertically above the jump pad (lower Y value)
		if rect.position.y < pos.y - 15.0:
			# Check horizontal overlap with 25px clearance
			var plat_left: float = rect.position.x - 25.0
			var plat_right: float = rect.position.x + rect.size.x + 25.0
			var pad_left: float = pos.x
			var pad_right: float = pos.x + pad_width
			if pad_right > plat_left and pad_left < plat_right:
				# A ceiling platform is directly above! Do not spawn!
				return false
	return true

func try_spawn_jump_pad(parent: Node2D, pos: Vector2, pad_width: float = 50.0) -> bool:
	if can_spawn_jump_pad_at(pos, pad_width):
		var pad = InteractiveObjects.JumpPad.new(pad_width, 12.0)
		pad.position = pos
		parent.add_child(pad)
		return true
	return false

func create_low_overpass(parent: Node2D, pos: Vector2, span_width: float = 140.0, clearance: float = 24.0, thickness: float = 24.0) -> InteractiveObjects.LowOverpass:
	var overpass = InteractiveObjects.LowOverpass.new(span_width, clearance, thickness)
	overpass.position = pos
	parent.add_child(overpass)
	current_chunk_platforms.append(Rect2(pos.x, pos.y - clearance - thickness, span_width, thickness))
	return overpass

func build_accessible_chunk(parent: Node2D, pattern: int) -> void:
	# 1. Base Ground (Tier 3 Toxic Canal)
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	
	# Sludge hazard pool on ground
	if randf() > 0.4:
		var sludge = InteractiveObjects.SludgeHazard.new(200.0, 30.0)
		sludge.position = Vector2(240, TIER3_CANAL_Y + 12)
		parent.add_child(sludge)
	
	match pattern:
		0:
			# Pattern 0: Highway Slide Tunnel -> Clear Jump Pad Launch -> High Catwalk
			create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(420, 32), Color(0.2, 0.25, 0.32))
			create_platform(parent, Vector2(460, TIER1_CATWALK_Y), Vector2(chunk_width - 460, 24), Color(0.12, 0.35, 0.45))
			
			# Low industrial overhead girder (forces player to slide underneath!)
			create_low_overpass(parent, Vector2(140, TIER2_HIGHWAY_Y), 130.0)
			
			# Jump pad on Highway with 100% clear vertical sky above
			try_spawn_jump_pad(parent, Vector2(340, TIER2_HIGHWAY_Y - 12))
			
			var zombie = InteractiveObjects.CyberEnemy.new("zombie")
			zombie.position = Vector2(650, TIER1_CATWALK_Y - 18)
			parent.add_child(zombie)
			
			var dog = InteractiveObjects.CyberEnemy.new("hound")
			dog.position = Vector2(880, TIER1_CATWALK_Y - 12)
			parent.add_child(dog)

		1:
			# Pattern 1: Stepped Staircase Platforms (Stairs from Tier 3 up to Tier 1)
			create_platform(parent, Vector2(40, 80), Vector2(180, 24), Color(0.25, 0.3, 0.38))       # Step 1
			create_platform(parent, Vector2(260, TIER2_HIGHWAY_Y), Vector2(300, 32), Color(0.2, 0.25, 0.32)) # Highway
			create_platform(parent, Vector2(600, -70), Vector2(180, 24), Color(0.25, 0.3, 0.38))      # Step 2
			create_platform(parent, Vector2(820, TIER1_CATWALK_Y), Vector2(380, 24), Color(0.12, 0.35, 0.45)) # Catwalk
			
			var hound = InteractiveObjects.CyberEnemy.new("hound")
			hound.position = Vector2(380, TIER2_HIGHWAY_Y - 12)
			parent.add_child(hound)
			
			var zombie = InteractiveObjects.CyberEnemy.new("zombie")
			zombie.position = Vector2(950, TIER1_CATWALK_Y - 18)
			parent.add_child(zombie)

		2:
			# Pattern 2: Sloped Ramp connecting Highway Tier 2 directly up to Catwalk Tier 1
			create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(240, 32), Color(0.2, 0.25, 0.32))
			create_ramp(parent, Vector2(240, TIER2_HIGHWAY_Y), Vector2(560, TIER1_CATWALK_Y))
			create_platform(parent, Vector2(560, TIER1_CATWALK_Y), Vector2(640, 24), Color(0.12, 0.35, 0.45))
			
			# Low overhead beam on the high catwalk (slide place!)
			create_low_overpass(parent, Vector2(720, TIER1_CATWALK_Y), 140.0)
			
			# Jump pad on open canal section after the ramp
			try_spawn_jump_pad(parent, Vector2(50, TIER3_CANAL_Y - 12))
			
			var zombie = InteractiveObjects.CyberEnemy.new("zombie")
			zombie.position = Vector2(140, TIER2_HIGHWAY_Y - 18)
			parent.add_child(zombie)
			
			var hound = InteractiveObjects.CyberEnemy.new("hound")
			hound.position = Vector2(950, TIER1_CATWALK_Y - 12)
			parent.add_child(hound)

		3:
			# Pattern 3: Dual Highway & Catwalk with an Open Skylight Launch Gap and Slide Zone
			create_platform(parent, Vector2(0, TIER1_CATWALK_Y), Vector2(240, 24), Color(0.12, 0.35, 0.45))
			create_platform(parent, Vector2(480, TIER1_CATWALK_Y), Vector2(chunk_width - 480, 24), Color(0.12, 0.35, 0.45))
			create_platform(parent, Vector2(100, TIER2_HIGHWAY_Y), Vector2(chunk_width - 200, 32), Color(0.2, 0.25, 0.32))
			
			# Jump pad at x: 340 launches through the open 240px skylight directly onto Catwalk Part 2!
			try_spawn_jump_pad(parent, Vector2(340, TIER2_HIGHWAY_Y - 12))
			
			# Low overpass slide challenge on Highway after the launch
			create_low_overpass(parent, Vector2(620, TIER2_HIGHWAY_Y), 150.0)
			
			var zombie = InteractiveObjects.CyberEnemy.new("zombie")
			zombie.position = Vector2(850, TIER2_HIGHWAY_Y - 18)
			parent.add_child(zombie)
			
			var hound = InteractiveObjects.CyberEnemy.new("hound")
			hound.position = Vector2(760, TIER1_CATWALK_Y - 12)
			parent.add_child(hound)

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
	poly.color = Color(0.25, 0.32, 0.4)
	body.add_child(poly)
	
	var col = CollisionPolygon2D.new()
	col.polygon = poly.polygon
	body.add_child(col)
	
	parent.add_child(body)
	return body

func cull_old_chunks() -> void:
	if not player_node:
		return
	var cull_threshold_x: float = player_node.global_position.x - (chunk_width * cull_distance_chunks)
	
	var remaining: Array[Node2D] = []
	for chunk in active_chunks:
		if chunk.position.x < cull_threshold_x:
			chunk.queue_free()
		else:
			remaining.append(chunk)
	active_chunks = remaining
