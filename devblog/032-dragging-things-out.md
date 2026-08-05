# 032 — Dragging things out, and three ways to leak

*5 August 2026 — covers the item drop and icons commit*

Three asks: take a stack out of the bag and put it on the ground, show real
icons that scale properly, and put counts on the things that stack. Two of
those are small. The third — dropping — turned out to be where every
interesting bug was, and none of them were in the drag code.

## The rules are not in the mouse

Godot's drag-and-drop is three virtual methods: `_get_drag_data`,
`_can_drop_data`, `_drop_data`. It would be very easy to put the logic in them,
and then the only way to check "does dragging a stack of 20 onto a stack of 15
merge correctly" is to drag a stack of 20 onto a stack of 15.

So the drag methods decide nothing. They answer *which gesture happened* and
call something that can be tested with numbers:

- Onto another cell → `Inventory.move_to(from, to)`
- Outside the panel → `InventoryScreen.drop_to_world(index)`

`move_to` merges when both slots hold the same item and swaps otherwise.
Swapping rather than refusing is what makes a grid feel like a grid — a dragged
stack that snaps back because the target was occupied is a UI arguing with you.
And only what fits pours across, so 12 dropped on 15 in stacks of 20 becomes 20
and 7, not 27 in a slot that holds 20. That last one has a test asserting the
*total* is unchanged, because the failure mode is items quietly appearing or
vanishing.

## Nothing leaves the bag until it exists in the world

```gdscript
if dropper.drop(definition, amount) == null:
	return 0
bag.take_all(index)
```

That order is the whole safety property. Remove first and the spawn can fail —
no world scene, no parent, a scene that failed to load — and the stack now
exists nowhere. There is a test that drops an item with no world form and
asserts the bag still holds all three.

A whole stack lands as **one** pickup carrying a count, not one node per item.
Twenty mushrooms dropped as twenty nodes is a pile you have to press F at twenty
times. The prompt already knew how to say this — `prompt_text()` has had the
`x%d` form since it was written — so a dropped stack reads "Pick up Mushroom
x9" and comes back in one press.

## A cycle, and why the item holds a *path*

`ItemDefinition` wants to say what it looks like on the ground. `mushroom.tscn`
wants to say what it is when you pick it up. Both are natural, and together
they are a loop:

```
mushroom.tres --world_scene--> mushroom.tscn --definition--> mushroom.tres
```

Godot resolves some resource cycles and chokes on others, and a load order that
works by luck is not one to build on. So the item holds a **path**, resolved on
first use, by which point both files are loaded. It is uglier in the editor and
it is the reason nothing explodes.

## Three leaks in one afternoon

The suite prints `ObjectDB instances were leaked` and `resources still in use
at exit` on the way out. None of these failed a test. All three were found by
reading the tail of a green run.

**One.** The first version cached the loaded scene in a member:

```gdscript
var _world_scene: PackedScene
```

That is a strong reference from the item to the scene, and the scene already
holds the item. Two `RefCounted`s pointing at each other is a cycle GDScript
never collects — the same asymmetry that bit this project in post 015, wearing
different clothes. The fix is not to cache: `ResourceLoader` has its own cache,
so `load()` is a dictionary lookup for as long as anything else holds the
scene, and the mushroom patch holds it for the life of the world.

**Two.** `set_drag_preview()` only means something inside a real drag. A test
calling `_get_drag_data` handed the viewport a `Control` that no drag would
ever finish and no one would ever free. Fixed by splitting the payload out:

```gdscript
func drag_payload() -> Variant:
	return null if _empty else {"source": &"inventory", "index": index}
```

The tests use that. `_get_drag_data` is the payload plus decoration. Better
anyway — the decoration was never the interesting part.

**Three.** Each cell builds its own `StyleBoxFlat`. That is the fifth appearance
of the shared-resource trap and this time it was avoided by habit rather than
by discovering it again, which feels like progress.

## Two error messages that lie

Worth writing down because both cost time.

**`Invalid call. Nonexistent function 'new' in base 'GDScript'`** — pointing at
`InventoryScreen._ensure_cells`, a line that had worked five minutes earlier.
The real error was fourteen lines up the log: `InventoryCell` had a
`var payload := drag_payload()` inferring `Variant`, which this project treats
as an error, so the script never compiled. An uncompiled script still resolves
as a `GDScript` object — it just has no `new`. The failure is reported at the
*caller* and names the wrong file entirely.

**`Invalid cast: could not convert value to 'Dictionary'`** — from
`data as Dictionary` in the guard that exists specifically to reject foreign
payloads. For objects, `as` returns null on a mismatch; for built-in types it
raises. So the check written to be defensive was the thing that crashed, and
the test that found it was the one dragging a string at it on purpose. Check
`typeof()` first.

## Icons that fit

Two properties, and both matter:

```gdscript
_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
```

Without `KEEP_ASPECT_CENTERED` a tall icon is squashed into the square cell.
Without `IGNORE_SIZE` the texture's own dimensions become the cell's minimum
size, so a 512-pixel icon makes an 84-pixel cell 512 pixels wide and the grid
runs off the screen. There is a test asserting both, and another asserting the
cell keeps its 84×84 minimum with an icon in it.

The mushroom icon is an SVG, which Godot rasterises on import — so the same
file serves a 48-pixel cell and whatever a future 4K UI wants. Post 031 said
"there is no item art yet, and a coloured swatch is honest about that". There
is now one piece of item art; the swatch survives as the fallback and as a tint
behind the icon.

Counts show **only for things that stack**. A "1" under an item you can only
hold one of is a number that never changes and therefore says nothing.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
