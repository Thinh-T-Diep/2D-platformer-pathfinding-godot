extends CharacterBody2D

# -------------------------
# MOVEMENT SETTINGS
# -------------------------
const SPEED: float = 300.0
const JUMP_VELOCITY: float = -450.0
const SMALL_JUMP_VELOCITY: float = -370.0
const TINY_JUMP_VELOCITY: float = -270.0
const JUMP_DISTANCE_HEIGHT_THRESHOLD: float = 120.0

const TILE_MAP_GROUP_NAME: String = "tile_map_layer_pathfind"

# Get the gravity from the project settings to sync with RigidBody2D nodes
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _path_find_2d: TileMapLayerPathFind
var _path: Array[TileMapLayerPathFind.PointInfo] = []
var _target: TileMapLayerPathFind.PointInfo = null
var _prev_target:TileMapLayerPathFind.PointInfo = null
var _start_timer: Timer
var _player: Player


func _ready() -> void:
	_path_find_2d = get_tree().get_first_node_in_group(TILE_MAP_GROUP_NAME) as TileMapLayerPathFind
	_player = get_parent().get_node("Player") as Player
	_start_timer = get_node("PathFindTimer")


func go_to_next_point_in_path() -> void:
	if _path.size() <= 0:
		_prev_target = null
		_target = null
		return

	_prev_target = _target
	_target = _path.pop_back()


func do_path_finding() -> void:
	var player_tile_position = _path_find_2d.local_to_map(_player.position)
	_path = _path_find_2d.get_platform_2d_path(position, _path_find_2d.map_to_local(player_tile_position))
	go_to_next_point_in_path()


func _physics_process(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	
	# Handle skeleton start follow the player
	if Input.is_action_just_pressed("start_follow"):
		_start_timer.start()
	
	# Apply gravity if not on the floor
	if not is_on_floor():
		velocity.y += gravity * delta

	# If there's a current target
	if _target != null:
		if _target.graph_position.x - 5 > position.x:
			direction.x = 1.0
		elif _target.graph_position.x + 5 < position.x:
			direction.x = -1.0
		else:
			if is_on_floor():
				go_to_next_point_in_path()
				jump()

	# Apply horizontal movement
	if direction != Vector2.ZERO:
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()


func jump_right_edge_to_left_edge() -> bool:
	if _prev_target.is_right_edge and _target.is_left_edge \
	and _prev_target.graph_position.y <= _target.graph_position.y \
	and _prev_target.graph_position.x < _target.graph_position.x:
		return true
	return false


func jump_left_edge_to_right_edge() -> bool:
	if _prev_target.is_left_edge and _target.is_right_edge \
	and _prev_target.graph_position.y <= _target.graph_position.y \
	and _prev_target.graph_position.x > _target.graph_position.x:
		return true
	return false


func jump() -> void:
	if _prev_target == null or \
		#_prev_target.is_position_point or \ # If controlling player by button or keyboard inputs, may need to uncomment this line 
		_target == null or \
		_target.is_position_point:
		return

	# Skip jump if previous target is above the target position and distance is below threshold
	if _prev_target.graph_position.y < _target.graph_position.y \
	and _prev_target.graph_position.distance_to(_target.graph_position) < JUMP_DISTANCE_HEIGHT_THRESHOLD:
		return

	# Skip jump if target is a fall tile below
	if _prev_target.graph_position.y < _target.graph_position.y and _target.is_fall_tile:
		return

	# Determine if jump is needed
	if _prev_target.graph_position.y > _target.graph_position.y or jump_right_edge_to_left_edge() or jump_left_edge_to_right_edge():
		var height_distance: int = \
			_path_find_2d.local_to_map(_target.graph_position).y - _path_find_2d.local_to_map(_prev_target.graph_position).y

		if abs(height_distance) <= 1:
			velocity.y = TINY_JUMP_VELOCITY
		elif abs(height_distance) == 2:
			velocity.y = SMALL_JUMP_VELOCITY
		else:
			velocity.y = JUMP_VELOCITY


func _on_path_find_timer_timeout() -> void:
	if is_on_floor():
		do_path_finding()
