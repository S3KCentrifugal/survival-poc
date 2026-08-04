class_name StructureConfig
extends Resource
## Tuning shared by everything built out of walls.
##
## Dimensions a person has to fit through or see over, so the defaults are set
## against the 1.8 m player rather than picked for looking right in a screenshot.

@export_range(1.0, 12.0, 0.1) var wall_height: float = 3.0

@export_range(0.1, 2.0, 0.05) var wall_thickness: float = 0.3

## Clear width of a doorway. 1.6 m is generous — a character that clips a frame
## while walking through it reads as the door being broken.
@export_range(0.6, 6.0, 0.1) var doorway_width: float = 1.6

## Clear height of a doorway. Must stay above the 1.8 m character or they walk
## into the lintel.
@export_range(1.0, 6.0, 0.1) var doorway_height: float = 2.2

## Thickness of a floor slab. It sits below the walking surface, so this is how
## far the building's foundation stands proud of the ground.
@export_range(0.05, 2.0, 0.05) var floor_thickness: float = 0.3

@export var wall_material: Material
@export var floor_material: Material
