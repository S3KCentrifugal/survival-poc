class_name WallOpening
extends RefCounted
## A gap left in a wall: a doorway, a window, a collapsed section.
##
## Measured along the wall from its start rather than in world space, so a wall
## can be moved or re-pointed without every opening in it needing to be
## recalculated.

## Distance in metres from the wall's start to the near edge of the gap.
var offset: float

## How wide the gap is, in metres.
var width: float

## Height of the gap. A wall taller than this keeps a lintel above the opening;
## a gap at or above the wall's height cuts all the way through.
var height: float


func _init(p_offset: float, p_width: float, p_height: float) -> void:
	offset = p_offset
	width = p_width
	height = p_height


## Where the gap ends, measured from the wall's start.
func far_edge() -> float:
	return offset + width


func _to_string() -> String:
	return "<WallOpening %.2f..%.2f h%.2f>" % [offset, far_edge(), height]
