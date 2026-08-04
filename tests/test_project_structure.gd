extends TestCase
## Guards the project skeleton.
##
## The folder hierarchy is part of the architecture, not decoration -- systems
## are expected to live in predictable places so a person or an agent can find
## them without searching. A directory quietly disappearing (or never being
## committed, which is the same thing to a fresh clone) should fail here.

const REQUIRED_DIRS: PackedStringArray = [
	"res://scenes",
	"res://scripts",
	"res://scripts/components",
	"res://scripts/systems",
	"res://scripts/ui",
	"res://scripts/world",
	"res://resources",
	"res://ui",
	"res://characters",
	"res://enemies",
	"res://items",
	"res://world",
	"res://audio",
	"res://shaders",
	"res://materials",
	"res://effects",
	"res://prefabs",
	"res://tests",
]

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"


func test_every_required_directory_exists() -> void:
	for path: String in REQUIRED_DIRS:
		assert_true(DirAccess.dir_exists_absolute(path), "missing directory %s" % path)


func test_main_scene_is_the_configured_entry_point() -> void:
	var configured: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(configured, MAIN_SCENE_PATH, "project.godot does not point at the main scene")


func test_main_scene_loads_and_is_a_3d_world() -> void:
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	assert_not_null(scene, "%s is missing or malformed" % MAIN_SCENE_PATH)
	assert_true(scene.can_instantiate())

	var root: Node = scene.instantiate()
	assert_true(root is Node3D, "the world root must be a Node3D")
	root.free()


func test_the_world_can_be_seen() -> void:
	# An empty 3D scene with no camera or light renders black, which reads as a
	# failed launch. Both are placeholders, but their absence is a real bug.
	var root: Node = load(MAIN_SCENE_PATH).instantiate()
	var has_camera := false
	var has_light := false
	for child: Node in root.get_children():
		has_camera = has_camera or child is Camera3D
		has_light = has_light or child is DirectionalLight3D
	assert_true(has_camera, "no Camera3D -- nothing would render")
	assert_true(has_light, "no DirectionalLight3D -- the world would be unlit")
	root.free()
