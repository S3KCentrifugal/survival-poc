class_name MerchantPost
extends Node3D
## Puts merchants in the world, where they can be found again.
##
## Authored positions rather than a scatter. [WandererSpawner] scatters because
## a wanderer is background; a merchant you cannot find twice is not a shop, and
## the first thing anyone does after selling mushrooms is go and get more
## mushrooms.
##
## Each one is stocked here rather than in the character scene, so "what this
## merchant has" is a world decision -- two posts can carry the same merchant
## scene and sell different things.

## Emitted for each merchant as it is placed.
signal placed(merchant: Node3D)

@export var scene: PackedScene

## Dropped onto the surface, so nobody stands in a hill.
@export var terrain: Terrain

## Where they stand, in tile-local metres. One merchant per entry.
@export var positions: Array[Vector2] = []

## Which way each faces, in degrees. Reused cyclically if there are fewer than
## there are positions.
@export var facings: Array[float] = []

@export_group("Stock")
## Gold each merchant starts with. They cannot buy past it, which is what stops
## a mushroom field being a money printer.
@export_range(0, 100000, 10) var starting_gold: int = 400

## What each has on the shelf at open, as item paths to counts.
@export var starting_items: Dictionary[String, int] = {}

var _merchants: Array[Node3D] = []


func _ready() -> void:
	# The world's contents are the server's to decide, exactly as the wanderers
	# and the mushrooms are.
	if not NetworkAuthority.is_server(self):
		return
	place_all()


## Puts one merchant at each authored position.
func place_all() -> void:
	if scene == null:
		return
	for index in positions.size():
		var merchant: Node3D = scene.instantiate()
		add_child(merchant)

		var where := Vector3(positions[index].x, 0.0, positions[index].y)
		if terrain != null:
			where.y = terrain.height_at_world(where)
		merchant.global_position = where
		if not facings.is_empty():
			merchant.rotation.y = deg_to_rad(facings[index % facings.size()])

		_stock(merchant)
		_merchants.append(merchant)
		placed.emit(merchant)


## The merchants standing here.
func merchants() -> Array[Node3D]:
	var standing: Array[Node3D] = []
	for merchant: Node3D in _merchants:
		if is_instance_valid(merchant):
			standing.append(merchant)
	return standing


func count() -> int:
	return merchants().size()


func _stock(merchant: Node3D) -> void:
	var inventory := merchant.get_node_or_null("Stock") as InventoryComponent
	if inventory == null:
		return
	if starting_gold > 0:
		inventory.collect(Purse.definition(), starting_gold)
	for path: String in starting_items:
		var item: ItemDefinition = load(path)
		if item != null:
			inventory.collect(item, starting_items[path])
