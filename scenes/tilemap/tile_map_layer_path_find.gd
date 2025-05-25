extends TileMapLayer

class_name TileMapLayerPathFind


const GRAPH_POINT_SCENE_FILEPATH: String = "res://scenes/tilemap/graph_point.tscn"

class PointInfo:
	var is_fall_tile: bool
	var is_left_edge: bool
	var is_right_edge: bool
	var is_left_wall: bool
	var is_right_wall: bool
	var is_position_point: bool
	var point_id: int
	var graph_position: Vector2
	
	func _init(id: int, pos: Vector2) -> void:
		point_id = id
		graph_position = pos


#=====================================
# TILE MAP LAYER A* GRAPH SETTINGS
#=====================================
@export var _show_debug_graph: bool = true                # If the graph points and lines should be drawn
@export var _jump_distance: int = 4                       # Distance between two tiles to count as a jump
@export var _jump_height: int = 4                         # Height between two tiles to connect a jump

## Set to 1 when the collision shape of the characters are smalller than the tile size /
## If the collision shape of the characters are larger than the tile size, set it to be larger than
## than the smallest multiple of their ratio, else characters won't fall down when they reach the edge
## e.g. char size is 20px in the x-axis, and tile size is 16px, set this to 2 (16 * 2 > 20)  
@export var fall_tile_horizontal_scan = 2
#=====================================

const COLLISION_LAYER: int = 0  			# The collision layer for the tiles
const CELL_IS_EMPTY: int = -1				# TileMap defines an empty space as -1
const MAX_TILE_FALL_SCAN_DEPTH = 500		# Max number of tiles to scand downwards for a solid tile

var _astar_graph: AStar2D = AStar2D.new() 	# The a star graph
var _used_tiles: Array[Vector2i]			# The used tiles in the TileMap
var _graph_point: PackedScene				# The graph point node to visualize path
var _point_info_list: Array[PointInfo]


func _ready() -> void:
	_graph_point = load(GRAPH_POINT_SCENE_FILEPATH)
	_used_tiles = get_used_cells()
	build_graph()


func build_graph() -> void:
	add_graph_points()   # Add all the grah points

	# If the debug graph should not be shown
	if (!_show_debug_graph):
		connect_points()    # Connect the points


func draw_debug_line(to: Vector2, from: Vector2, color: Color) -> void:
	# If the debug graph should be visible
	if _show_debug_graph:
		draw_line(to, from, color); # Draw a line between the points with te given color


# Loop through all the used tiles in the tilemap
func add_graph_points():
	for tile in _used_tiles:
		add_left_edge_point(tile)
		add_right_edge_point(tile)
		add_left_wall_point(tile)
		add_right_wall_point(tile)
		add_fall_point(tile)


func tile_already_exist_in_graph(tile: Vector2i) -> int:
	var local_pos = map_to_local(tile);                            # Map the position to screen coordiantes

	# If the graph contains points
	if (_astar_graph.get_point_count() > 0):
		var point_id = _astar_graph.get_closest_point(local_pos)    # Find the closest point in the graph

		# If the points have the same local coordinates
		if (_astar_graph.get_point_position(point_id) == local_pos):
			return point_id                                     # Return the point id, the tile already exist

	# if the node was n found, return -1
	return -1;


func add_visual_point(tile: Vector2i, color: Color = Color.TRANSPARENT, scale_factor: float = 1.0):
	#If the graph should not be shown, return out of the method
	if (!_show_debug_graph): return

	# Instantiate a new visual point
	var visual_point: Sprite2D  = _graph_point.instantiate() as Sprite2D

	# If a custom color has been passed in
	if (color !=  Color.TRANSPARENT):
		visual_point.modulate = color;    # Change the color of the visual point to the custom color
	# If a custom scale has been passed in, and it is within valid range
	if (scale_factor != 1.0 && scale_factor > 0.1):
		visual_point.scale = Vector2(scale_factor, scale_factor)  # Update the visual point scale
	visual_point.position = map_to_local(tile);    # Map the position of the visual point to local coordinates
	add_child(visual_point)                      # Add the visual point as a child to the scene


func get_point_info(tile: Vector2i) -> PointInfo:
	# Loop through the point info list
	for point_info in _point_info_list:
		# If the tile has been added to the points list
		if (point_info.graph_position == map_to_local(tile)):
			return point_info   # Return the PointInfo
	return null # If the tile wasn't found, return null


func get_point_info_at_position(pos: Vector2) -> PointInfo:
	var new_info_point = PointInfo.new(-10000, pos)  # Create a new PointInfo with default ID
	new_info_point.is_position_point = true

	var tile: Vector2i = local_to_map(pos)

	# Check if there's a tile below
	if get_cell_source_id(Vector2i(tile.x, tile.y + 1)) != CELL_IS_EMPTY:

		# Check for wall tiles
		if get_cell_source_id(Vector2i(tile.x - 1, tile.y)) != CELL_IS_EMPTY:
			new_info_point.is_left_wall = true

		if get_cell_source_id(Vector2i(tile.x + 1, tile.y)) != CELL_IS_EMPTY:
			new_info_point.is_right_wall = true

		# Check for edge tiles
		if get_cell_source_id(Vector2i(tile.x - 1, tile.y + 1)) != CELL_IS_EMPTY:
			new_info_point.is_left_edge = true

		if get_cell_source_id(Vector2i(tile.x + 1, tile.y + 1)) != CELL_IS_EMPTY:
			new_info_point.is_right_edge = true

	return new_info_point


# -------------------------
# PATHFINDING LOGIC
# -------------------------
func reverse_path_stack(path_stack: Array[PointInfo]) -> Array[PointInfo]:
	var copy_of_stack = path_stack.duplicate()
	var path_stack_reversed: Array[PointInfo]

	while copy_of_stack.size() > 0:
		path_stack_reversed.append(copy_of_stack.pop_back())

	return path_stack_reversed


func get_platform_2d_path(start_pos: Vector2, end_pos: Vector2) -> Array[PointInfo]:
	var path_stack: Array[PointInfo]

	# Find the ID path from the AStar graph
	var id_path: Array = _astar_graph.get_id_path(
		_astar_graph.get_closest_point(start_pos),
		_astar_graph.get_closest_point(end_pos))

	if id_path.size() <= 0:
		return path_stack  # Return empty if no path found

	var start_point: PointInfo = get_point_info_at_position(start_pos)
	var end_point: PointInfo = get_point_info_at_position(end_pos)
	var num_points_in_path: int = id_path.size()

	for i in range(num_points_in_path):
		var curr_point: PointInfo = get_info_point_by_point_id(id_path[i])

		if num_points_in_path == 1:
			continue  # Skip single node paths

		if i == 0 and num_points_in_path >= 2:
			var second_point: PointInfo = get_info_point_by_point_id(id_path[i + 1])
			if start_point.graph_position.distance_to(second_point.graph_position) < curr_point.graph_position.distance_to(second_point.graph_position):
				path_stack.append(start_point)
				continue

		elif i == num_points_in_path - 1 and num_points_in_path >= 2:
			var penultimate_point: PointInfo = get_info_point_by_point_id(id_path[i - 1])
			if end_point.graph_position.distance_to(penultimate_point.graph_position) < curr_point.graph_position.distance_to(penultimate_point.graph_position):
				continue
			else:
				path_stack.append(curr_point)
				break

		path_stack.append(curr_point)

	path_stack.append(end_point)
	return reverse_path_stack(path_stack)


func get_info_point_by_point_id(point_id: int) -> PointInfo:
	for point in _point_info_list:
		if point.point_id == point_id:
			return point
	return null


func _draw() -> void:
	# If the debug graph should be visible
	if _show_debug_graph:
		connect_points()    # Connect the points & draw the graph and its connections


# -------------------------
# CONNECT GRAPH POINTS
# -------------------------

func connect_points() -> void:
	# Loop through all the points in the point info list
	for p1 in _point_info_list:
		connect_horizontal_points(p1)    # Connect the horizontal points in the graph			
		connect_jump_points(p1)          # Connect the jump points in the graph
		connect_fall_point(p1)           # Connect the fall points in the graph					


func connect_fall_point(p1: PointInfo) -> void:
	if p1.is_left_edge or p1.is_right_edge:
		# find_fall_points expects the exact tile coordinate. The points in the graph is one tile above: y-1
		# Therefore we adjust the y position with: y += 1
		var tile_pos: Vector2i = local_to_map(p1.graph_position)
		tile_pos.y += 1  # Adjust because graph point is one tile above

		var fall_point: Vector2i = find_fall_point(tile_pos)
		if fall_point != Vector2i.MAX:
			var point_info: PointInfo = get_point_info(fall_point)
			var p2_map: Vector2 = local_to_map(p1.graph_position)
			var p1_map: Vector2 = local_to_map(point_info.graph_position)

			if p1_map.distance_to(p2_map) <= _jump_height:
				_astar_graph.connect_points(p1.point_id, point_info.point_id)
				draw_debug_line(p1.graph_position, point_info.graph_position, Color(0, 1, 0, 1))  # Green
			else:
				_astar_graph.connect_points(p1.point_id, point_info.point_id, false) # Only allow edge -> fall_tile direction
				draw_debug_line(p1.graph_position, point_info.graph_position, Color(1, 1, 0, 1))  # Yellow



func connect_horizontal_points(p1: PointInfo):
	if (p1.is_left_edge || p1.is_left_wall || p1.is_fall_tile):
		var closest: PointInfo = null
		
		# Loop through the point info list
		for p2 in _point_info_list:
			if p1.point_id == p2.point_id: continue # If the points are the same, go to the next point
			
			# If the point is a right edge or a right wall, and the height (Y position) is the same,
			# and the p2 position is to the right of the p1 point
			if ((p2.is_right_edge || p2.is_right_wall || p2.is_fall_tile) && 
				p2.graph_position.y == p1.graph_position.y && p2.graph_position.x > p1.graph_position.x):
				# If the closest point has not yet been initialized
				if closest == null:
					closest = PointInfo.new(p2.point_id, p2.graph_position);   # Initialize it to the p2 point
				# If the p2 point is closer than the current closest point
				if p2.graph_position.x < closest.graph_position.x:
					closest.graph_position = p2.graph_position # Update the closest point position
					closest.point_id = p2.point_id             # Update the pointId
		
		# If a closest point was found
			if (closest != null):
				# If a horizontal connection cannot be made
				if (!horizontal_connection_cannot_be_made(p1.graph_position as Vector2i, closest.graph_position as Vector2i)):
					_astar_graph.connect_points(p1.point_id, closest.point_id)                 # Connect the points
					draw_debug_line(p1.graph_position, closest.graph_position, Color(0, 1, 0, 1))    # Draw a green line between the points


func horizontal_connection_cannot_be_made(p1: Vector2i, p2: Vector2i) -> bool:
	# Convert the position to tile coordinates
	var start_scan: Vector2i = local_to_map(p1)
	var end_scan: Vector2i = local_to_map(p2)

	# Loop through all tiles between the points
	for i in range(start_scan.x, end_scan.x):
		if (get_cell_source_id(Vector2i(i, start_scan.y)) != CELL_IS_EMPTY         # If the cell is not empty (a wall)
		|| get_cell_source_id(Vector2i(i, start_scan.y + 1)) == CELL_IS_EMPTY):    # or the cell below is empty (an edge tile)
			return true    # Return true, the connection cannot be made
	return false


func connect_jump_points(p1: PointInfo):
	for p2 in _point_info_list:
		connect_horizontal_platform_jumps(p1, p2)
		connect_diagonal_jump_right_edge_to_left_edge(p1, p2)
		connect_diagonal_jump_left_edge_to_right_edge(p1, p2);


func connect_horizontal_platform_jumps(p1: PointInfo, p2: PointInfo):
	if (p1.point_id == p2.point_id): return # If the points are the same, return out of the method

	# If the points are on the same height and p1 is a right edge, and p2 is a left edge	
	if (p2.graph_position.y == p1.graph_position.y && p1.is_right_edge && p2.is_left_edge):
		# If the p2 position is to the right of the p1 position
		if (p2.graph_position.x > p1.graph_position.x):
			var p2_map: Vector2 = local_to_map(p2.graph_position);    # Get the p2 tile position
			var p1_map: Vector2 = local_to_map(p1.graph_position);    # Get the p1 tile position				

			# If the distance between the p2 and p1 map position are within jump reach
			if (p2_map.distance_to(p1_map) < _jump_distance + 1):
				_astar_graph.connect_points(p1.point_id, p2.point_id);              # Connect the points
				draw_debug_line(p1.graph_position, p2.graph_position, Color(0, 1, 0, 1)); # Draw a green line between the points


func connect_diagonal_jump_right_edge_to_left_edge(p1: PointInfo, p2: PointInfo) -> void:
	if p1.is_right_edge:
		var p1_map: Vector2 = local_to_map(p1.graph_position)
		var p2_map: Vector2 = local_to_map(p2.graph_position)

		if (p2.is_left_edge 								# If the p2 tile is a left edge
			&& p2.graph_position.x > p1.graph_position.x	# And the p2 tile is to the right of the p1 tile
			&& p2.graph_position.y > p1.graph_position.y	# And the p2 tile is below the p1 tile
			&& p2_map.distance_to(p1_map) < _jump_distance):# And the distance between the p2 and p1 map position is within jump reach
			
			_astar_graph.connect_points(p1.point_id, p2.point_id)					# Connect the points
			draw_debug_line(p1.graph_position, p2.graph_position, Color(0, 1, 0, 1))# Draw a green line between the points


func connect_diagonal_jump_left_edge_to_right_edge(p1: PointInfo, p2: PointInfo) -> void:
	if p1.is_left_edge:
		var p1_map: Vector2 = local_to_map(p1.graph_position)
		var p2_map: Vector2 = local_to_map(p2.graph_position)

		if (p2.is_right_edge 								# If the p2 tile is a right edge
			&& p2.graph_position.x < p1.graph_position.x	# And the p2 tile is to the left of the p1 tile
			&& p2.graph_position.y > p1.graph_position.y	# And the p2 tile is below the p1 tile
			&& p2_map.distance_to(p1_map) < _jump_distance):# And the distance between the p2 and p1 map position is within jump reach
			
			_astar_graph.connect_points(p1.point_id, p2.point_id)					# Connect the points
			draw_debug_line(p1.graph_position, p2.graph_position, Color(0, 1, 0, 1))# Draw a green line between the points


# -------------------------
# TILE FALL POINTS
# -------------------------

func get_start_scan_tile_for_fall_point(tile: Vector2i) -> Vector2i:
		var tile_above = Vector2i(tile.x, tile.y - 1)
		var point = get_point_info(tile_above)

		# If the point did not exist in the point info list
		if (point == null): return Vector2i.MAX  # Return Vector2i.MAX, representing not found state

		var tile_scan = Vector2i.ZERO

		# If the point is a left edge
		if (point.is_left_edge):
			tile_scan = Vector2i(tile.x - fall_tile_horizontal_scan, tile.y - 1)    # Set the start position to start scanning one tile to the left
			return tile_scan                                # Return the tile scan position
		# If the point is a right edge
		elif (point.is_right_edge):
			tile_scan = Vector2i(tile.x + fall_tile_horizontal_scan, tile.y - 1)    # Set the start position to start scanning one tile to the right
			return tile_scan                                # Return the tile scan position
		return Vector2i.MAX  # Return Vector2i.MAX, representing not found state


func find_fall_point(tile: Vector2i) -> Vector2i:
	var scan = get_start_scan_tile_for_fall_point(tile);# Get the start scan tile position
	if (scan == Vector2i.MAX): return Vector2i.MAX      # If it wasn't found, return Vector2i.MAX out of the method

	var fall_tile: Vector2i = Vector2i.MAX      # Initialize the fall_tile to Vector2i.MAX, an invalid result

	# Loop, and start to look for a solid tile
	for i in MAX_TILE_FALL_SCAN_DEPTH:
		# If the tile cell below is solid
		if get_cell_source_id(Vector2i(scan.x, scan.y + 1)) != CELL_IS_EMPTY:
			fall_tile = scan;    # The fall tile was found
			break;               # Break out of the for loop
		
		# If a solid tile was not found, scan the next tile below the current one
		scan.y += 1
	return fall_tile;    # return the fall tile result


func add_fall_point(tile: Vector2i) -> void:
	var fall_tile: Vector2i = find_fall_point(tile)                           # Find the fall tile point
	if fall_tile == Vector2i.MAX: return                                      # If the fall tile was not found, return out of the method
	var fall_tile_local = map_to_local(fall_tile)                             # Get the local coordinates for the fall tile

	var existing_point_id: int = tile_already_exist_in_graph(fall_tile)       # Check if the point already has been added

	# If the tile doesn't exist in the graph already
	if (existing_point_id == -1):
		var point_id: int = _astar_graph.get_available_point_id()            # Get the next available point id
		var point_info: PointInfo = PointInfo.new(point_id, fall_tile_local)  # Create point information, and pass in the pointId and tile
		point_info.is_fall_tile = true                                        # Flag that the tile is a fall tile
		_point_info_list.append(point_info)                                   # Add the tile to the point info list
		_astar_graph.add_point(point_id, fall_tile_local)                    # Add the point to the Astar graph, in local coordinates
		add_visual_point(fall_tile, Color(1, .35, .1, 1), .35)                # Add the point visually to the map (if ShowDebugGraph = true)
	else:
		for point in _point_info_list:
			if point.point_id == existing_point_id:
				point.is_fall_tile = true
		#var updateInfo = _pointInfoList.Find(x => x.PointID == existingPointId);  # Find the existing point info
		#updateInfo.IsFallTile = true;                                             # Flag that it's a fall tile
			
			add_visual_point(fall_tile, Color("#ef7d57"), .3)


# -------------------------
# TILE EDGE & WALL GRAPH POINTS
# -------------------------

func add_left_edge_point(tile: Vector2i):
	# If a tile exist above, it's not an edge
	if tile_above_exist(tile):
		return
	
	# If the tile to the left (X - 1) is empty
	if (get_cell_source_id(Vector2i(tile.x - 1, tile.y)) == CELL_IS_EMPTY):
		var tile_above: Vector2i = Vector2i(tile.x, tile.y - 1)
		
		# Check if the point already has been added
		var existing_point_id: int = tile_already_exist_in_graph(tile_above)
		
		# If the point has not already been added
		if (existing_point_id == -1):
			var point_id: int = _astar_graph.get_available_point_id()              # Get the next available point id
			var point_info: PointInfo = PointInfo.new(point_id, map_to_local(tile_above) as Vector2i) # Create a new point information, and pass in the pointId
			point_info.is_left_edge = true                                         # Flag that the tile is a left edge
			_point_info_list.append(point_info)                                          # Add the tile to the point info list
			_astar_graph.add_point(point_id, map_to_local(tile_above) as Vector2i);         # Add the point to the Astar graph, in local coordinates
			add_visual_point(tile_above) # Add the point visually to the map (if ShowDebugGraph = true)				
		else:
			#var exisiting_point_array: Array[PointInfo] = _point_info_list.filter(\
					#func(point: PointInfo): return point.point_id == existing_point_id)
			#exisiting_point_array[0].is_left_edge = true
			
			#flag that it's a left edge
			for point in _point_info_list:
				if point.point_id == existing_point_id:
					point.is_left_edge = true
			
			add_visual_point(tile_above, Color("#73eff7"))


func add_right_edge_point(tile: Vector2i):
	# If a tile exist above, it's not an edge
	if tile_above_exist(tile):
		return
	
	# If the tile to the right (X + 1) is empty
	if (get_cell_source_id(Vector2i(tile.x + 1, tile.y)) == CELL_IS_EMPTY):
		var tile_above: Vector2i = Vector2i(tile.x, tile.y - 1)
		
		# Check if the point already has been added
		var existing_point_id: int = tile_already_exist_in_graph(tile_above)
		
		# If the point has not already been added
		if (existing_point_id == -1):
			var point_id: int = _astar_graph.get_available_point_id()              # Get the next available point id
			var point_info: PointInfo = PointInfo.new(point_id, map_to_local(tile_above) as Vector2i) # Create a new point information, and pass in the point_id
			point_info.is_right_edge = true                                         # Flag that the tile is a right edge
			_point_info_list.append(point_info)                                          # Add the tile to the point info list
			_astar_graph.add_point(point_id, map_to_local(tile_above) as Vector2i);         # Add the point to the Astar graph, in local coordinates
			add_visual_point(tile_above, Color("#94b0c2")) # Add the point visually to the map (if ShowDebugGraph = true)				
		else:
			#flag that it's a right edge
			for point in _point_info_list:
				if point.point_id == existing_point_id:
					point.is_right_edge = true
			
			add_visual_point(tile_above, Color("#ffcd75"))


func add_left_wall_point(tile: Vector2i):
	# If a tile exist above, it's not an edge
	if tile_above_exist(tile):
		return
	
	# If the tile to the left and above (x - 1, y -1) is not empty
	if (get_cell_source_id(Vector2i(tile.x - 1, tile.y -1)) != CELL_IS_EMPTY):
		var tile_above: Vector2i = Vector2i(tile.x, tile.y - 1)
		
		# Check if the point already has been added
		var existing_point_id: int = tile_already_exist_in_graph(tile_above)
		
		# If the point has not already been added
		if (existing_point_id == -1):
			var point_id: int = _astar_graph.get_available_point_id()              # Get the next available point id
			var point_info: PointInfo = PointInfo.new(point_id, map_to_local(tile_above) as Vector2i) # Create a new point information, and pass in the pointId
			point_info.is_left_wall = true                                         # Flag that the tile is a left wall
			_point_info_list.append(point_info)                                          # Add the tile to the point info list
			_astar_graph.add_point(point_id, map_to_local(tile_above) as Vector2i);         # Add the point to the Astar graph, in local coordinates
			add_visual_point(tile_above, Color(0, 0, 0, 1)) # Add the point visually to the map (if ShowDebugGraph = true)				
		else:
			#flag that it's a left wall
			for point in _point_info_list:
				if point.point_id == existing_point_id:
					point.is_left_wall = true
			
			add_visual_point(tile_above, Color(0, 0, 1, 1), .45) # Add a blue small point


func add_right_wall_point(tile: Vector2i):
	# If a tile exist above, it's not an edge
	if tile_above_exist(tile):
		return
	
	# If the tile to the right and above (x + 1, y -1) is not empty
	if (get_cell_source_id(Vector2i(tile.x + 1, tile.y -1)) != CELL_IS_EMPTY):
		var tile_above: Vector2i = Vector2i(tile.x, tile.y - 1)
		
		# Check if the point already has been added
		var existing_point_id: int = tile_already_exist_in_graph(tile_above)
		
		# If the point has not already been added
		if (existing_point_id == -1):
			var point_id: int = _astar_graph.get_available_point_id()  # Get the next available point id
			var point_info: PointInfo = PointInfo.new(point_id, map_to_local(tile_above) as Vector2i) # Create a new point information, and pass in the pointId
			point_info.is_right_wall = true                             # Flag that the tile is a right wall
			_point_info_list.append(point_info)                                          # Add the tile to the point info list
			_astar_graph.add_point(point_id, map_to_local(tile_above) as Vector2i);         # Add the point to the Astar graph, in local coordinates
			add_visual_point(tile_above, Color(0, 0, 0, 1)) # Add the point visually to the map (if ShowDebugGraph = true)				
		else:
			#flag that it's a right wall
			for point in _point_info_list:
				if point.point_id == existing_point_id:
					point.is_right_wall = true
			
			add_visual_point(tile_above, Color("#566c86"), .65) #Add a purple small point


func tile_above_exist(tile: Vector2i ) -> bool:
	# If a tile doesn't exist above (Y - 1)
	if (get_cell_source_id(Vector2i(tile.x, tile.y - 1)) == CELL_IS_EMPTY):
		return false;   # If it's empty, return false
	
	return true;
