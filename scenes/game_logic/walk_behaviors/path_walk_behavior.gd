# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PathWalkBehavior
extends BaseCharacterBehavior
## @experimental
##
## Make the character walk along a path.
##
## If the path is closed the character walks in circles. If not, they walk back and forth turning
## around in endings.
##
## If the character gets stuck while walking the path, they turn around, unless
## [member turn_around] has been disabled.

## Emitted when [member character] reaches the ending of the path.
signal ending_reached

## Emitted when [member character] got stuck while walking the path.
signal got_stuck

## Emitted when turning around.
signal direction_changed

## Emitted when a "pointy" part of the path is reached.
## This could be used to wait standing for a bit in these points.
## If the path is not closed, both endings are considered pointy so this signal will also
## emit in them.
signal pointy_path_reached

## Parameters controlling the speed at which this character walks. If unset, the default values of
## [CharacterSpeeds] are used.
@export var speeds: CharacterSpeeds

## The walking path.
@export var walking_path: Path2D:
	set = _set_walking_path

## If set, the character will turn around when reaching the path ending or when stuck.
@export var turn_around: bool = true

## Make the "is path continuous" calculation more or less sensitive.
@export_range(0, 1, 0.01, "or_greater", "suffix:m") var path_continuous_tolerance: float = 0.01

## Make the "is path pointy" calculation more or less sensitive.
@export_range(0, 100, 1, "or_greater", "suffix:m") var path_pointy_tolerance: float = 20

## Position of the first point relative to the path position.
var initial_position: Vector2

## This is 1 when walking in the path direction, and -1 when walking in the opposite direction.
var direction: int = 1:
	set = _set_direction

## True if the [member walking_path] is closed, in which case the character will walk in
## circles.
var is_path_closed: bool

# Offset of each pointy point in the path.
var _pointy_offsets: Array[float]


func _set_walking_path(new_walking_path: Path2D) -> void:
	walking_path = new_walking_path
	update_configuration_warnings()
	if not is_node_ready():
		return
	if walking_path:
		# Set initial position and put character in path:
		var initial_position_local := walking_path.curve.get_point_position(0)
		initial_position = walking_path.to_global(initial_position_local)
		character.global_position = initial_position
		is_path_closed = _is_path_closed()
		_setup_pointy_offsets()


func _set_direction(new_direction: int) -> void:
	direction = signi(new_direction)
	if not is_node_ready():
		return
	direction_changed.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if not walking_path:
		warnings.append("Walking Path property must be set.")
	return warnings


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return

	if not speeds:
		speeds = CharacterSpeeds.new()

	_set_walking_path(walking_path)


func _physics_process(delta: float) -> void:
	var closest_offset := walking_path.curve.get_closest_offset(
		walking_path.to_local(character.global_position)
	)
	var new_offset := closest_offset + speeds.walk_speed * delta * direction

	for idx in range(_pointy_offsets.size()):
		var pointy_offset := _pointy_offsets[idx]
		if direction == 1:
			if (
				pointy_offset > closest_offset
				and (pointy_offset < new_offset or is_equal_approx(pointy_offset, new_offset))
			):
				pointy_path_reached.emit()
			elif new_offset > walking_path.curve.get_baked_length():
				pointy_path_reached.emit()
		elif direction == -1:
			if (
				pointy_offset < closest_offset
				and (pointy_offset > new_offset or is_equal_approx(pointy_offset, new_offset))
			):
				pointy_path_reached.emit()

	if not is_path_closed:
		# Turn around in endings:
		if new_offset > walking_path.curve.get_baked_length() or new_offset < 0.0:
			ending_reached.emit()
			if turn_around:
				direction *= -1

	# A point in the curve that is relative to the point in which the character is,
	# in the given direction, and at a distance that depends on the character walk
	# speed.
	var target_position_local := walking_path.curve.sample_baked(new_offset)
	var target_position := walking_path.to_global(target_position_local)

	character.velocity = character.position.direction_to(target_position) * speeds.walk_speed

	var collided := character.move_and_slide()
	if collided and character.is_on_wall():
		if speeds.is_stuck(character):
			got_stuck.emit()
			if turn_around:
				direction *= -1


func _is_curve_smooth(point_in: Vector2, point_out: Vector2) -> bool:
	# TODO: Compare length_squared() < path_pointy_tolerance
	return (point_in or point_out) and abs(point_in.cross(point_out)) <= path_continuous_tolerance


func _setup_pointy_offsets() -> void:
	var add_endings := (
		not is_path_closed
		or not _is_curve_smooth(
			walking_path.curve.get_point_in(walking_path.curve.point_count - 1),
			walking_path.curve.get_point_out(0)
		)
	)

	for idx in range(walking_path.curve.point_count):
		var point_position := walking_path.curve.get_point_position(idx)
		if idx == 0:
			if not add_endings:
				continue
			_pointy_offsets.append(walking_path.curve.get_closest_offset(point_position))
		elif idx == walking_path.curve.point_count - 1:
			if not add_endings:
				continue
			# This especial case is because get_closest_offset() returns zero for the last point.
			_pointy_offsets.append(walking_path.curve.get_baked_length())
		else:
			var p_in := walking_path.curve.get_point_in(idx)
			var p_out := walking_path.curve.get_point_out(idx)
			if _is_curve_smooth(p_in, p_out):
				# The curve is smooth (not pointy) in this point:
				continue
			else:
				_pointy_offsets.append(walking_path.curve.get_closest_offset(point_position))


## Return true if the end of the path is the same point as the beginning.
func _is_path_closed() -> bool:
	if walking_path.curve.point_count < 3:
		return false

	var first_point_position: Vector2 = walking_path.curve.get_point_position(0)
	var last_point_position: Vector2 = walking_path.curve.get_point_position(
		walking_path.curve.point_count - 1
	)

	return first_point_position.is_equal_approx(last_point_position)
