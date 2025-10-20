# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name HookableArea
extends Area2D
## @experimental
##
## Area to connect the grappling hook.
##
## An area to connect the grappling hook to a game entity (by default, this node's parent).
## While the final connection is a single position, as returned by [method get_anchor_position],
## the collision is checked against this area that should be big enough
## for player forgiveness.
## [br][br]
## This is a piece of the grappling hook mechanic.
## [br][br]
## When the grappling hook ray enters, it connects at [method get_anchor_position].
## You can specify a [member anchor_point] for using something different than this node's position.
## [br][br]
## If [member hook_control] is provided, this becomes a connection
## so the grappling hook can in turn aim from here.
## [br][br]
## If this is not a connection, it will be pulled automatically.
## When pulled, the game entity controlled by this area could be attracted to the player,
## or the player can be attracted to this node's controlled entity (or something in between)
## depending on the value of [member weight] and the controlled entity being a
## [CharacterBody2D].
## [br][br]
## [b]Note:[/b] This area is expected to be in the "hookable" collision layer.

## The game entity that becomes hookable.
## [br][br]
## [b]Note:[/b] If the parent node is a Node2D and this isn't set,
## the parent node will be automatically assigned to this variable.
@export var controlled_entity: Node2D:
	set = _set_controlled_entity

## Optional control to make this area a connection.
@export var hook_control: HookControl:
	set = _set_hook_control

## The exact point to attach the string.
## [br][br]
## Optional. [member global_position] will be used if this is not set.
@export var anchor_point: Marker2D

## When the grappling hook pulls and this area is hooked:[br]
## • 1: The player moves towards this.[br]
## • 0: This node's controlled entity moves towards the player.[br]
## • Something in between: Both move depending on the value.[br][br]
## Not relevant if [member hook_control] is set.[br][br]
## If this node's controlled entity is not a [CharacterBody2D], 1 is assumed.
@export var weight: float = 1.0


func _enter_tree() -> void:
	if not controlled_entity and get_parent() is Node2D:
		controlled_entity = get_parent()


## Return the global position used to connect the hook.
func get_anchor_position() -> Vector2:
	return anchor_point.global_position if anchor_point else global_position


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray
	if not controlled_entity:
		warnings.append("Controlled Entity must be set.")
	if not get_collision_layer_value(Enums.CollisionLayers.HOOKABLE):
		warnings.append(
			(
				"Consider enabling collision with the hookable layer: %d."
				% Enums.CollisionLayers.HOOKABLE
			)
		)
	return warnings


func _set(property: StringName, _value: Variant) -> bool:
	if property == "collision_layer":
		update_configuration_warnings()
	return false


func _set_controlled_entity(new_controlled_entity: Node2D) -> void:
	controlled_entity = new_controlled_entity
	update_configuration_warnings()


func _set_hook_control(new_hook_control: HookControl) -> void:
	hook_control = new_hook_control
	hook_control.hook_area = self
