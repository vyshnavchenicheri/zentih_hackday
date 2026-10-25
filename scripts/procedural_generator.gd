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
	
	var pattern_type: int = randi() % 4
	build_accessible_chunk(chunk_root, pattern_type)
	
	next_chunk_x += chunk_width

func build_accessible_chunk(parent: Node2D, pattern: int) -> void:
	# 1. Base Ground (Tier 3)
	create_platform(parent, Vector2(0, TIER3_CANAL_Y), Vector2(chunk_width, 50), Color(0.08, 0.14, 0.12))
	
	# Sludge hazard pool on ground
	if randf() > 0.4:
		var sludge = InteractiveObjects.SludgeHazard.new(200.0, 30.0)
		sludge.position = Vector2(240, TIER3_CANAL_Y + 12)
		parent.add_child(sludge)
	
	match pattern:
		0:
			# Pattern 0: Direct Jump Pad on Highway launching to High Catwalk
			create_platform(parent, Vector2(80, TIER1_CATWALK_Y), Vector2(chunk_width - 160, 24), Color(0.12, 0.35, 0.45))
			create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(chunk_width - 80, 32), Color(0.2, 0.25, 0.32))
			
			var pad = InteractiveObjects.JumpPad.new(50.0, 12.0)
			pad.position = Vector2(220, TIER2_HIGHWAY_Y - 12)
			parent.add_child(pad)
			
			var bar = InteractiveObjects.Barricade.new(24.0, 48.0)
			bar.position = Vector2(520, TIER2_HIGHWAY_Y - 48)
			parent.add_child(bar)
			
			var enemy = InteractiveObjects.CyberEnemy.new("zombie")
			enemy.position = Vector2(720, TIER2_HIGHWAY_Y - 18)
			parent.add_child(enemy)

		1:
			# Pattern 1: Stepped Staircase Platforms (Stairs from Tier 3 up to Tier 1)
			create_platform(parent, Vector2(60, 80), Vector2(180, 24), Color(0.25, 0.3, 0.38))       # Step 1
			create_platform(parent, Vector2(280, TIER2_HIGHWAY_Y), Vector2(300, 32), Color(0.2, 0.25, 0.32)) # Highway
			create_platform(parent, Vector2(620, -70), Vector2(180, 24), Color(0.25, 0.3, 0.38))      # Step 2
			create_platform(parent, Vector2(820, TIER1_CATWALK_Y), Vector2(380, 24), Color(0.12, 0.35, 0.45)) # Catwalk
			
			var hound = InteractiveObjects.CyberEnemy.new("hound")
			hound.position = Vector2(940, TIER1_CATWALK_Y - 12)
			parent.add_child(hound)

		2:
			# Pattern 2: Sloped Ramp connecting Highway Tier 2 directly up to Catwalk Tier 1
			create_platform(parent, Vector2(0, TIER2_HIGHWAY_Y), Vector2(250, 32), Color(0.2, 0.25, 0.32))
			create_ramp(parent, Vector2(250, TIER2_HIGHWAY_Y), Vector2(600, TIER1_CATWALK_Y))
			create_platform(parent, Vector2(600, TIER1_CATWALK_Y), Vector2(600, 24), Color(0.12, 0.35, 0.45))
			
			var pad_ground = InteractiveObjects.JumpPad.new(50.0, 12.0)
			pad_ground.position = Vector2(100, TIER3_CANAL_Y - 12)
			parent.add_child(pad_ground)
			
			var bar_top = InteractiveObjects.Barricade.new(24.0, 48.0)
			bar_top.position = Vector2(820, TIER1_CATWALK_Y - 48)
			parent.add_child(bar_top)

		3:
			# Pattern 3: Full High Catwalk + Highway with dual jump pads
			create_platform(parent, Vector2(0, TIER1_CATWALK_Y), Vector2(chunk_width, 24), Color(0.12, 0.35, 0.45))
			create_platform(parent, Vector2(120, TIER2_HIGHWAY_Y), Vector2(chunk_width - 240, 32), Color(0.2, 0.25, 0.32))
			
			var pad_highway = InteractiveObjects.JumpPad.new(50.0, 12.0)
			pad_highway.position = Vector2(360, TIER2_HIGHWAY_Y - 12)
			parent.add_child(pad_highway)
			
			var zombie = InteractiveObjects.CyberEnemy.new("zombie")
			zombie.position = Vector2(580, TIER2_HIGHWAY_Y - 18)
			parent.add_child(zombie)
			
			var bar = InteractiveObjects.Barricade.new(24.0, 48.0)
			bar.position = Vector2(780, TIER1_CATWALK_Y - 48)
			parent.add_child(bar)

func create_platform(parent: Node2D, pos: Vector2, size: Vector2, color: Color) -> StaticBody2D:
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
	var body = StaticBody2D.new()
	var poly = Polygon2D.new()
	var thickness: float = 24.0
	
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
