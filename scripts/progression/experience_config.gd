class_name ExperienceConfig
extends Resource
## How much experience a level costs.
##
## A curve rather than a table, because a table is fifty numbers a designer has
## to keep monotonic by hand. Three numbers here produce the whole thing, and
## the shape they produce is checked in [ExperienceTable]'s tests rather than
## trusted.

## Experience from level 1 to level 2.
@export_range(1, 100000, 1) var first_level_cost: int = 60

## What each level multiplies the last one's cost by.
##
## Just above 1: a flat curve makes level 30 as easy as level 2, and a steep one
## makes the second hour of play look like a wall. 1.18 roughly doubles the cost
## every four levels.
@export_range(1.0, 3.0, 0.01) var growth: float = 1.18

## The ceiling. Experience past it is still counted -- it just stops buying
## levels, so a "max level" character does not look like a broken bar.
@export_range(1, 999, 1) var max_level: int = 30

@export_group("Rewards")
## Experience per point of damage dealt.
##
## Damage rather than kills alone, so a fight you lose is not worth nothing and
## so the number moves while you are watching it. A wanderer is 100 health, so
## a full kill by damage is 50.
@export_range(0.0, 100.0, 0.05) var per_damage: float = 0.5

## Extra for the blow that finishes something off.
@export_range(0.0, 10000.0, 1.0) var per_kill: float = 25.0
