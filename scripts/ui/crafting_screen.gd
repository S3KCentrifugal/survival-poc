class_name CraftingScreen
extends CanvasLayer
## The panel that opens when you use a workbench.
##
## Opens because a bench said someone used it, not because a key was pressed --
## so the same panel serves a second bench later without knowing one exists, and
## a test can open it without pretending to walk anywhere.
##
## Like the inventory, it does **not** pause: crafting is something your
## character does, and in multiplayer a bench that stops the world cannot exist.

signal opened(bench: WorkbenchComponent)
signal closed

## Where the ingredients come from and the result goes.
@export var inventory: InventoryComponent

## Watched so the panel opens when a bench is used.
@export var interactor: Interactor

## Owns opening, closing, the cursor, the keyboard and the close keys.
@export var modal: ModalPanel

## Given to the component above, which is what releases the cursor and the
## keyboard. Optional, so a panel can be tested with no world around it.
@export var world_root: WorldRoot

@export var rows: VBoxContainer
@export var title_label: Label
@export var status_label: Label

## Rebuilt per recipe, so a bench with three recipes gets three buttons.
var _buttons: Array[Button] = []

var _bench: WorkbenchComponent


func _ready() -> void:
	if modal != null:
		# The world wires the panel; the panel configures its own component. Same
		# shape as the pause menu handing its SettingsController a path -- a
		# child is ready before its parent, so a component that read this for
		# itself would read it too early.
		modal.world_root = world_root
		modal.closed.connect(_on_closed)
	if interactor != null:
		interactor.used.connect(_on_used)
	if inventory != null:
		# The panel shows what can be made *now*, so it has to follow the bag:
		# crafting one soup can be what makes the second one impossible.
		inventory.changed.connect(refresh)


## Escape closes it, and so does the use key. Handled as unhandled input so the
## console and the pause menu get first refusal.
## Opens the panel on [param bench], or closes it.
func show_bench(bench: WorkbenchComponent) -> void:
	_bench = bench
	if bench == null:
		set_open(false)
		return
	if title_label != null:
		title_label.text = bench.display_name
	_build_rows()
	refresh()
	set_open(true)
	opened.emit(bench)


func set_open(open: bool) -> void:
	if modal != null:
		modal.set_open(open)


func is_open() -> bool:
	return modal != null and modal.is_open()


func _on_closed() -> void:
	_bench = null
	closed.emit()


## The bench currently open, or null.
func bench() -> WorkbenchComponent:
	return _bench


## Greys out what cannot be made, and says why.
func refresh() -> void:
	if _bench == null or inventory == null:
		return
	var bag := inventory.inventory()
	for index in _buttons.size():
		var recipe := _bench.recipes[index]
		var possible := recipe != null and recipe.can_craft(bag)
		_buttons[index].disabled = not possible
		# The reason is on the button rather than in a message somewhere else:
		# "you cannot make this" is only useful next to the thing you cannot
		# make.
		_buttons[index].tooltip_text = (
			recipe.summary() if possible else _reason_for(recipe, bag)
		)


## Makes [param index] on the open bench. Returns how many were made.
##
## Public and index-based so a test can craft without a button press.
func craft(index: int) -> int:
	if _bench == null or index < 0 or index >= _bench.recipes.size():
		return 0
	var recipe := _bench.recipes[index]
	var made := _bench.craft(recipe, inventory)
	_say(
		"Made %s x%d." % [recipe.output.display_name, made]
		if made > 0
		else _reason_for(recipe, inventory.inventory())
	)
	refresh()
	return made


func _on_used(bench: WorkbenchComponent) -> void:
	# Using the bench you already have open closes it, which is what pressing
	# the key again should do.
	show_bench(null if bench == _bench and visible else bench)


func _build_rows() -> void:
	if rows == null:
		return
	for button: Button in _buttons:
		rows.remove_child(button)
		button.queue_free()
	_buttons.clear()

	for recipe: Recipe in _bench.recipes:
		var button := Button.new()
		button.custom_minimum_size = Vector2(360, 44)
		button.text = recipe.summary() if recipe != null else "(empty recipe)"
		button.pressed.connect(craft.bind(_buttons.size()))
		rows.add_child(button)
		_buttons.append(button)


func _reason_for(recipe: Recipe, bag: Inventory) -> String:
	if recipe == null or not recipe.is_valid():
		return "This recipe is broken."
	if not recipe.has_ingredients(bag):
		var missing: Array[String] = []
		for ingredient: RecipeIngredient in recipe.ingredients:
			var short := ingredient.count - bag.count_of(ingredient.item.id)
			if short > 0:
				missing.append("%d more %s" % [short, ingredient.item.display_name])
		return "Need " + ", ".join(missing) + "."
	if not recipe.has_room_for_result(bag):
		return "No room in your bag."
	return recipe.summary()


func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text
