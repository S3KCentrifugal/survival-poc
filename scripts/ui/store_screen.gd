class_name StoreScreen
extends CanvasLayer
## The shop, opened by walking up to a merchant and pressing the interact key.
##
## Opens because a merchant was hailed, not because a key was pressed, so a
## second merchant works without this file knowing one exists. Like the
## inventory and the bench it does **not** pause: trading is something your
## character does, and in multiplayer a shop that stops the world cannot exist.
##
## Every decision about whether a trade may happen belongs to [Trade]. This
## builds a button per offer, greys out the ones that would be refused, and puts
## the refusal on the button -- "you cannot do this" is only useful next to the
## thing you cannot do.

signal opened(merchant: MerchantComponent)
signal closed

@export var inventory: InventoryComponent

## Watched so the shop opens when a merchant is hailed.
@export var router: InteractionRouter

@export var world_root: WorldRoot

@export var buy_rows: VBoxContainer
@export var sell_rows: VBoxContainer
@export var title_label: Label
@export var gold_label: Label
@export var status_label: Label

var _merchant: MerchantComponent

## Buttons paired with the offer each one performs, so a press does not have to
## work out which row it was.
var _buttons: Array[Button] = []
var _offers: Array[TradeOffer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if router != null:
		router.merchant_hailed.connect(_on_hailed)
	if inventory != null:
		inventory.changed.connect(refresh)


## Handled in [method Node._input] rather than `_unhandled_input`, and this is
## not a style choice. `_unhandled_input` runs in reverse tree order, and the
## pause menu happens to sit after this panel -- so Escape reached the menu
## first and opened it *over* an open shop, which could then never be closed.
## Tree order is an invisible dependency and a bad one to rest on. `_input` runs
## before all of it, and an open modal panel is exactly the thing that should
## win its own close key.
##
## Returns immediately when hidden, so a closed panel costs one comparison.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_F:
		set_open(false)
		get_viewport().set_input_as_handled()


## Opens the shop on [param merchant], or closes it.
func show_merchant(merchant: MerchantComponent) -> void:
	_merchant = merchant
	if merchant == null:
		set_open(false)
		return
	if title_label != null:
		title_label.text = merchant.display_name
	_build_rows()
	refresh()
	set_open(true)


func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if world_root != null:
		world_root.set_mouse_captured(not open)
		# And the keyboard and buttons with it. Releasing only the cursor left
		# the character playable behind the panel -- harmless while the only
		# bindings were keys you would not press, and immediately visible once
		# right click became an attack.
		world_root.set_input_suspended(open)
	if open:
		opened.emit(_merchant)
	else:
		_merchant = null
		closed.emit()


func is_open() -> bool:
	return visible


func merchant() -> MerchantComponent:
	return _merchant


## Greys out what cannot be traded, says why, and shows both purses.
func refresh() -> void:
	if _merchant == null or inventory == null:
		return
	for index in _buttons.size():
		var offer := _offers[index]
		var refusal := _merchant.check(inventory, offer, 1)
		_buttons[index].disabled = refusal != Trade.Refusal.NONE
		_buttons[index].text = _label_for(offer)
		_buttons[index].tooltip_text = (
			offer.item.description if refusal == Trade.Refusal.NONE else Trade.reason(refusal)
		)

	if gold_label != null:
		gold_label.text = "Your gold: %d      %s has: %d" % [
			Purse.balance(inventory.inventory()), _merchant.display_name, _merchant.gold()
		]


## Trades one at [param index]. Returns how many changed hands.
##
## Public and index-based so a test can trade without a button press.
func trade(index: int) -> int:
	if _merchant == null or index < 0 or index >= _offers.size():
		return 0
	var offer := _offers[index]
	var moved := (
		_merchant.sell_to(inventory, offer, 1)
		if offer.direction == TradeOffer.Direction.SELLS
		else _merchant.buy_from(inventory, offer, 1)
	)
	_say(
		("Bought %s." if offer.direction == TradeOffer.Direction.SELLS else "Sold %s.")
			% offer.item.display_name
		if moved > 0
		else Trade.reason(_merchant.check(inventory, offer, 1))
	)
	refresh()
	return moved


## How many offers are on screen, for a test.
func offer_count() -> int:
	return _offers.size()


func button_for(index: int) -> Button:
	return null if index < 0 or index >= _buttons.size() else _buttons[index]


func _on_hailed(merchant: MerchantComponent) -> void:
	# Hailing the merchant you already have open closes the shop, which is what
	# pressing the key again should do.
	show_merchant(null if merchant == _merchant and visible else merchant)


func _build_rows() -> void:
	for button: Button in _buttons:
		button.get_parent().remove_child(button)
		button.queue_free()
	_buttons.clear()
	_offers.clear()

	for offer: TradeOffer in _merchant.offers:
		if offer == null or not offer.is_valid():
			continue
		var selling := offer.direction == TradeOffer.Direction.SELLS
		var rows := buy_rows if selling else sell_rows
		if rows == null:
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 40)
		button.pressed.connect(trade.bind(_buttons.size()))
		rows.add_child(button)
		_buttons.append(button)
		_offers.append(offer)


func _label_for(offer: TradeOffer) -> String:
	var held := inventory.count_of(offer.item.id)
	if offer.direction == TradeOffer.Direction.SELLS:
		return "Buy  %s" % offer.label()
	return "Sell  %s   (you have %d)" % [offer.label(), held]


func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text
