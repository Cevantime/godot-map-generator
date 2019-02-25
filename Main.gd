tool
extends Node2D

const N = 1
const E = 2
const S = 4
const W = 8

export(int, 1, 10) var GAP = 2 setget set_gap
var OFFSET
export(float, 0, 1) var ERASE_FACTOR : float = 0.2 setget set_erase_factor
export(float, 0, 1) var SPARSE_FACTOR : float = 0.2 setget set_sparse_factor
export(int, 1, 20) var MIN_LENGTH : int = 3 setget set_min_length
export(bool) var FORCE_LINKING : bool = true setget set_force_linking
export(int, 0, 1000000) var selected_seed : int = 0 setget set_selected_seed
export(bool) var do_linking_first : bool = false setget set_do_linking_first
export(int, 0, 300) var MAX_PAINTED_LENGTH = 100 setget set_max_painted_length

var cell_walls

var width : int = 64
var height : int = 38

var cells_to_fill = []
var prec = []

onready var timer : Timer
onready var tilemap : TileMap

func _ready() :
	randomize()
	init()

func init() :
	timer = $TimerRegenerate
	tilemap = $TileMap
	OFFSET = Vector2(GAP/2, GAP/2)
	cell_walls = {
		Vector2(GAP,0) : E,
		Vector2(-GAP,0) : W,
		Vector2(0,GAP) : S,
		Vector2(0,-GAP) : N,
	}
	if selected_seed <= 0 :
		selected_seed = - randi()
		print("generated_seed ", selected_seed)
		
	seed(selected_seed)
	
func generate_maze():
	make_maze()
	if do_linking_first :
		do_linking()
		erase_walls()
	else :
		erase_walls()
		do_linking()
	
	for i in range(0, 10) :
		paint_tile(16)
		
	for i in range(0, 10) :
		paint_tile(17)
	
	for i in range(0, 10) :
		paint_tile(18)
		
	clean_dirty_autotiles()
	
	
func regenerate_maze():
	init()
	if $TimerRegenerate :
		$TimerRegenerate.stop()
		$TimerRegenerate.start()
	
func check_neighbors(cell : Vector2, unvisited : Array) -> Array:
	var list = []
	for n in cell_walls.keys() :
		var celln = cell + n
		if celln in unvisited : 
			list.append(celln)
	return list
	
func make_maze():
	var unvisited = []
	var stack = []
	tilemap.clear()
	for x in range(width) :
		for y in range(height) :
			tilemap.set_cellv(Vector2(x,y), N|E|S|W)
	for x in range(OFFSET.x, width, GAP):
		for y in range(OFFSET.y, height, GAP):
			if(randf() > SPARSE_FACTOR) : unvisited.append(Vector2(x, y))
	var current = OFFSET
	cells_to_fill.push_back(current)
	unvisited.erase(current)
	prec = []
	
	while unvisited :
		var neighbors = check_neighbors(current, unvisited)
		if neighbors.size() > 0 :
			var next = neighbors[randi() % neighbors.size()]
			stack.append(current)
			var dir = next - current
			var current_walls = tilemap.get_cellv(current) - cell_walls[dir]
			var next_walls = tilemap.get_cellv(next) - cell_walls[-dir]
			tilemap.set_cellv(current, current_walls)
			tilemap.set_cellv(next, next_walls)
			cells_to_fill.push_back(next)
			var suppWall = N|S if dir.x != 0 else W|E
			var rangeMax = dir.x if dir.x != 0 else dir.y
			for i in range(1, abs(rangeMax)) :
				cells_to_fill.push_back(current + dir.normalized() * i)
				tilemap.set_cellv(current + dir.normalized() * i, suppWall)
			current = next
			unvisited.erase(current)
		elif stack:
			current = stack.pop_back()
		else :
			if ! erase_shorts() :
				prec.push_back(current)

			current = unvisited.pop_back()
			cells_to_fill = [current]
		
	if ! erase_shorts() :
		prec.push_back(current)
	
func do_linking() :
	if FORCE_LINKING :	
		for i in range(0, prec.size()) : 
			var p = prec[i]
			if i != prec.size() - 1 :
				dig_between(p, prec[i+1])
	
	
			
func erase_shorts() :
	if cells_to_fill.size() < MIN_LENGTH :
		for cell in cells_to_fill :
			tilemap.set_cellv(cell, 15)
		
		return true
	return false
	
func dig_between(from : Vector2, to : Vector2) -> void :
	var x_diff = sign(to.x - from.x)
	var y_diff = sign(to.y - from.y)
	# if x_diff == 0 : x_diff = pow(-1, randi() % 2)
	# if y_diff == 0 : y_diff = pow(-1, randi() % 2)
	var x_y = to
	var y_x = from
	if randi() % 2 > 0 :
		x_y = from
		y_x = to
		
	var progressX = E if x_diff >= 0 else W
	var retroX = W if x_diff >= 0 else E
	for x in range(from.x, to.x,  x_diff) :
		var cell = tilemap.get_cell(x, x_y.y) & (15 - progressX)
		tilemap.set_cell(x, x_y.y, cell)
		# yield(get_tree().create_timer(0.1), "timeout")
		if x != to.x :
			cell = tilemap.get_cell(x + x_diff, x_y.y) & (15 - retroX)
			tilemap.set_cell(x + x_diff, x_y.y, cell)
		
	var progressY = S if y_diff >= 0 else N
	var retroY = N if y_diff >= 0 else S
	for y in range(from.y, to.y, y_diff) :
		var cell = tilemap.get_cell(y_x.x, y) & (15 - progressY)
		tilemap.set_cell(y_x.x, y, cell)
		# yield(get_tree().create_timer(0.1), "timeout")
		if y != to.y :
			cell = tilemap.get_cell(y_x.x, y + y_diff) & (15 - retroY)
			tilemap.set_cell(y_x.x, y + y_diff, cell)
		
func erase_walls():
	# randomly remove a percentage of the map's walls
	for i in range(int(width * height * ERASE_FACTOR / GAP)):
		# pick a random tile not on the edge
		var x = int(rand_range(1, (width - GAP) / GAP))
		var y = int(rand_range(1, (height - GAP) / GAP))
		var cell = Vector2(x, y) * GAP + OFFSET
		if tilemap.get_cellv(cell) == 15 :
			continue
		# pick a random neighbor
		var dir = cell_walls.keys()[randi() % cell_walls.size()]
		# if there's a wall between cell and neighbor, remove it
		if tilemap.get_cellv(cell) & cell_walls[dir]:
			var walls = tilemap.get_cellv(cell) - cell_walls[dir]
			var n_walls = tilemap.get_cellv(cell+dir) - cell_walls[-dir]
			tilemap.set_cellv(cell, walls)
			tilemap.set_cellv(cell+dir, n_walls)
			var suppWall = N|S if dir.x != 0 else W|E
			var rangeMax = dir.x if dir.x != 0 else dir.y
			
			for i in range(1, abs(rangeMax)) :
				tilemap.set_cellv(cell + dir.normalized() * i, suppWall)
		# yield(get_tree(), 'idle_frame')
		
func paint_tile(tile_id) :
	var initial_pos = get_paint_start_pos()
	if initial_pos == null :
		return
		
	var square_length = randi() % MAX_PAINTED_LENGTH
	print(square_length)
	tilemap.set_cellv(initial_pos, tile_id)
	tilemap.update_bitmask_area(initial_pos)
	var placed_square = [initial_pos]
	var current = initial_pos
	var stack = [initial_pos]
	for i in range(0, square_length) :
		var available_neighbors = get_paint_available_neighbors(current)
		if available_neighbors.size() == 0 :
			if stack.size() == 0 :
				print("over")
				return
			current = stack.pop_back()
			continue
			
		stack.append(current)
		var neighbor = available_neighbors[randi() % available_neighbors.size()]
		placed_square.append(neighbor)
		tilemap.set_cellv(neighbor, tile_id)
		tilemap.update_bitmask_area(neighbor)
		current = neighbor
	
func clean_dirty_autotiles() :
	var found_bad_tile = true
	while found_bad_tile :
		found_bad_tile = false
		for x in range(width) :
			for y in range(height) :
				var pos = Vector2(x,y)
				var autotile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
				if autotile_coord == Vector2(2,4) :
					found_bad_tile = true
					tilemap.set_cellv(pos, 15)
					tilemap.update_bitmask_area(pos)

func get_paint_available_neighbors(pos : Vector2) -> Array:
	var available_neighbors = []
	for x in range(-1,2) :
		if x == 0 :
			continue
		var c_pos = Vector2(pos.x + x, pos.y)
		if tilemap.get_cellv(c_pos) == 15 :
			available_neighbors.append(c_pos)
	for y in range(-1,2) :
		if y == 0 :
			continue
		var c_pos = Vector2(pos.x, pos.y + y)
		if tilemap.get_cellv(c_pos) == 15 :
			available_neighbors.append(c_pos)
	
	return available_neighbors

func get_paint_start_pos() :
	var available = []
	for x in range(width) :
		for y in range(height) :
			var pos = Vector2(x,y)
			if tilemap.get_cellv(pos) == 15 :
				available.append(pos)
				
	if ! available: 
		return null
		
	return available[randi() % available.size()]

func set_erase_factor(factor) :
	ERASE_FACTOR = factor
	regenerate_maze()
	
func set_gap(gap) :
	GAP = gap
	regenerate_maze()

func set_sparse_factor(factor):
	SPARSE_FACTOR = factor
	regenerate_maze()
	
func set_min_length(min_length) :
	MIN_LENGTH = min_length
	regenerate_maze()
	
func set_force_linking(force) : 
	FORCE_LINKING = force
	regenerate_maze()
	
func set_selected_seed(s_seed) :
	selected_seed = s_seed
	regenerate_maze()
	
func set_do_linking_first(first) :
	do_linking_first = first
	regenerate_maze()
	
func set_max_painted_length(max_painted) :
	MAX_PAINTED_LENGTH = max_painted
	regenerate_maze()
	
func _on_TimerRegenerate_timeout():
	generate_maze()
