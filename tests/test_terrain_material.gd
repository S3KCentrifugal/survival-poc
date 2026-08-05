extends TestCase
## The ground's texturing: that the textures exist, that the shader is wired to
## them, and that the slope thresholds make sense in the order they are used.

const MATERIAL_PATH: String = "res://materials/terrain_ground.tres"
const SHADER_PATH: String = "res://shaders/terrain.gdshader"
const TERRAIN_SCENE: String = "res://world/terrain.tscn"

const TEXTURES: Array[String] = [
	"grass_albedo", "grass_normal", "dirt_albedo", "dirt_normal", "rock_albedo", "rock_normal"
]


func _material() -> ShaderMaterial:
	return load(MATERIAL_PATH)


func test_the_shader_and_material_load() -> void:
	assert_true(ResourceLoader.exists(SHADER_PATH), "there is no terrain shader")
	var material := _material()
	assert_not_null(material, "%s is missing or malformed" % MATERIAL_PATH)
	assert_eq(material.shader, load(SHADER_PATH))


## A missing texture is not an error in Godot -- the uniform is simply white,
## and the ground comes out looking like snow for no stated reason.
func test_every_texture_slot_is_filled() -> void:
	var material := _material()
	for name: String in TEXTURES:
		var texture: Texture2D = material.get_shader_parameter(name)
		assert_not_null(texture, "%s has no texture" % name)
		assert_true(texture.get_width() > 0, "%s is empty" % name)


## Repeat has to be on or the ground is one stretched copy of a grass photo.
func test_the_textures_tile() -> void:
	for name: String in TEXTURES:
		var texture: Texture2D = _material().get_shader_parameter(name)
		var image := texture.get_image()
		assert_not_null(image, "%s has no image data" % name)
		assert_eq(image.get_width(), image.get_height(), "%s is not square" % name)


## Grass, then dirt, then rock, as the ground gets steeper. Out of order, the
## blends fight and a cliff comes out green.
func test_the_slope_bands_are_in_order() -> void:
	var material := _material()
	var dirt_begins: float = material.get_shader_parameter("dirt_begins")
	var dirt_full: float = material.get_shader_parameter("dirt_full")
	var rock_begins: float = material.get_shader_parameter("rock_begins")
	var rock_full: float = material.get_shader_parameter("rock_full")

	assert_true(dirt_begins < dirt_full, "dirt finishes before it starts")
	assert_true(dirt_full <= rock_begins, "rock starts before dirt has finished")
	assert_true(rock_begins < rock_full, "rock finishes before it starts")
	assert_true(dirt_begins > 0.0, "flat ground would already be dirt")
	assert_true(rock_full < 90.0, "no slope is ever rock")


## One texture repeating every few metres is a chequerboard from any height.
## The second, much larger tiling is what hides the grid.
func test_the_macro_tiling_is_much_larger_than_the_detail_tiling() -> void:
	var material := _material()
	var grass: float = material.get_shader_parameter("grass_scale")
	var macro: float = material.get_shader_parameter("macro_scale")
	assert_true(macro > grass * 5.0, "the macro tiling is too close to the detail tiling")
	assert_true(
		float(material.get_shader_parameter("macro_strength")) > 0.0,
		"the macro tiling is mixed in at zero strength, so it does nothing"
	)


func test_the_terrain_scene_uses_it() -> void:
	var terrain: Terrain = load(TERRAIN_SCENE).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(terrain)

	var mesh_instance: MeshInstance3D = terrain.get_node("MeshInstance3D")
	var material: Material = mesh_instance.material_override
	if material == null:
		material = mesh_instance.get_surface_override_material(0)
	assert_not_null(material, "the ground has no material at all")
	assert_true(material is ShaderMaterial, "the ground is not using the terrain shader")

	terrain.free()
