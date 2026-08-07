extends TestCase
## Converting imported materials to the shared shader, and the assertion that
## every actor actually got converted.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const CHARACTERS: Array[String] = [
	"res://characters/player.tscn",
	"res://characters/companion.tscn",
	"res://characters/wanderer.tscn",
	"res://characters/merchant.tscn",
]


func _standard(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.7
	return material


func test_it_produces_a_material_on_the_shared_shader() -> void:
	var made := StylisedSurface.stylised_from(
		_standard(Color(0.3, 0.5, 0.9)), SurfacePalette.Band.CHARACTER
	)
	assert_not_null(made.shader, "the converted material has no shader")
	assert_eq(made.shader.resource_path, StylisedSurface.SHADER_PATH)


func test_it_keeps_the_colour_it_was_given() -> void:
	var made := StylisedSurface.stylised_from(
		_standard(Color(0.3, 0.5, 0.9)), SurfacePalette.Band.PROP
	)
	assert_eq(made.get_shader_parameter(&"albedo"), Color(0.3, 0.5, 0.9))
	# Compared loosely: a shader parameter is stored as a 32-bit float, so 0.7
	# comes back as 0.69999998807907 and an exact check fails for no reason.
	assert_true(absf(float(made.get_shader_parameter(&"roughness")) - 0.7) < 0.0001)


func test_it_carries_the_band_it_was_told_to_use() -> void:
	var made := StylisedSurface.stylised_from(_standard(Color.WHITE), SurfacePalette.Band.GROUND)
	assert_eq(
		made.get_shader_parameter(&"band_value"),
		SurfacePalette.value_of(SurfacePalette.Band.GROUND)
	)


## The numbers come from the tokens, not from the shader's own defaults. Two
## places to change a number is one place too many -- ART.md rule 8.
func test_the_shading_numbers_come_from_the_tokens() -> void:
	var made := StylisedSurface.stylised_from(_standard(Color.WHITE), SurfacePalette.Band.PROP)
	assert_eq(made.get_shader_parameter(&"ramp_softness"), ArtTokens.RAMP_SOFTNESS)
	assert_eq(made.get_shader_parameter(&"rim_strength"), ArtTokens.RIM_STRENGTH)
	assert_eq(made.get_shader_parameter(&"rim_color"), ArtTokens.RIM_COLOR)


func test_a_material_with_no_texture_says_so() -> void:
	# The shader branches on this rather than sampling a null texture, which
	# would read as black and turn the surface into a silhouette.
	var made := StylisedSurface.stylised_from(_standard(Color.WHITE), SurfacePalette.Band.PROP)
	assert_false(made.get_shader_parameter(&"has_albedo_texture"))


func test_a_surface_with_no_material_at_all_still_converts() -> void:
	# An imported mesh can have a null material on a surface, and a component
	# that skipped those would leave one arm of a character unstylised.
	var made := StylisedSurface.stylised_from(null, SurfacePalette.Band.CHARACTER)
	assert_not_null(made)
	assert_eq(made.get_shader_parameter(&"albedo"), Color.WHITE)


## Composition's standing cost: a component nobody attached produces no error,
## no warning and no null -- the actor simply lacks a behaviour. So every
## character scene is asserted to have one, rather than assumed to.
func test_every_character_is_drawn_with_the_stylised_shader() -> void:
	for path: String in CHARACTERS:
		var actor: Node = mount(load(path).instantiate())
		var surface: StylisedSurface = null
		for node: Node in actor.find_children("*", "Node", true, false):
			if node is StylisedSurface:
				surface = node
		assert_not_null(surface, "%s has no StylisedSurface" % path)
		assert_eq(
			surface.band, SurfacePalette.Band.CHARACTER, "%s is not in the character band" % path
		)


## And that it converted something. A component that silently painted nothing
## looks exactly like one that was never attached.
func test_the_conversion_actually_reaches_the_meshes() -> void:
	var actor: Node = mount(load(CHARACTERS[0]).instantiate())
	var surface: StylisedSurface = null
	for node: Node in actor.find_children("*", "Node", true, false):
		if node is StylisedSurface:
			surface = node
	assert_true(surface.converted_count() > 0, "the component found no meshes to convert")

	var converted := 0
	for mesh: MeshInstance3D in StylisedSurface.meshes(surface.model):
		for index in (mesh.mesh.get_surface_count() if mesh.mesh != null else 0):
			if mesh.get_surface_override_material(index) is ShaderMaterial:
				converted += 1
	assert_eq(converted, surface.converted_count(), "some surfaces were left behind")


## An imported material is a cached resource shared by every instance of the
## model. Writing to it would restyle every character in the game from one
## component and survive into the next scene that loaded the mesh -- the trap
## that has caught this project four times.
func test_it_overrides_rather_than_editing_the_imported_material() -> void:
	var actor: Node = mount(load(CHARACTERS[0]).instantiate())
	for mesh: MeshInstance3D in StylisedSurface.meshes(actor):
		if mesh.mesh == null:
			continue
		for index in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(index)
			assert_false(
				original is ShaderMaterial,
				"the imported material itself was replaced, not overridden"
			)


## The merchant is told apart by a material *overlay*. A component that
## converted surfaces by writing the overlay slot would have made every merchant
## look like everyone else, silently.
func test_converting_a_merchant_leaves_its_gold_alone() -> void:
	var merchant: Node = mount(load("res://characters/merchant.tscn").instantiate())
	var painted := 0
	for mesh: MeshInstance3D in StylisedSurface.meshes(merchant):
		if mesh.material_overlay != null:
			painted += 1
	assert_true(painted > 0, "the merchant lost its tint to the stylised conversion")


func test_the_terrain_shares_the_shading_with_everything_else() -> void:
	# The terrain was the only surface in the world lit by its own maths, which
	# is the quickest way to make one world look like two.
	var material: ShaderMaterial = load("res://materials/terrain_ground.tres")
	assert_eq(
		material.get_shader_parameter(&"band_value"),
		SurfacePalette.value_of(SurfacePalette.Band.GROUND)
	)
	assert_eq(material.get_shader_parameter(&"ramp_softness"), ArtTokens.RAMP_SOFTNESS)


func test_the_buildings_are_on_the_shared_shader_too() -> void:
	for path: String in [
		"res://materials/structure_wall.tres", "res://materials/structure_floor.tres"
	]:
		var material: ShaderMaterial = load(path)
		assert_not_null(material.shader, "%s has no shader" % path)
		assert_eq(material.shader.resource_path, StylisedSurface.SHADER_PATH, path)
		assert_eq(
			material.get_shader_parameter(&"band_value"),
			SurfacePalette.value_of(SurfacePalette.Band.STRUCTURE),
			"%s is not in the structure band" % path
		)


func test_the_world_still_builds_with_every_actor_converted() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var found := 0
	for node: Node in world.find_children("*", "Node", true, false):
		if node is StylisedSurface:
			found += 1
	assert_true(found >= 3, "only %d actors in the world are stylised" % found)
