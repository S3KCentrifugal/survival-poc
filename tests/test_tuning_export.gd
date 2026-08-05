extends TestCase
## Tuning in a form something that is not Godot can read.

const TEST_PATH: String = "user://test_tuning.json"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_it_finds_the_tuning_resources() -> void:
	var tuning := TuningExport.collect()
	assert_true(tuning.has("movement"), "movement tuning was not exported")
	assert_true(tuning.has("health"))
	assert_true(TuningExport.count() >= 10, "only %d resources exported" % TuningExport.count())


## The numbers a server has to agree with the client about.
func test_the_numbers_that_matter_are_in_it() -> void:
	var movement: Dictionary = TuningExport.collect()["movement"]["player_movement"]
	assert_true(movement.has("walk_speed"))
	assert_true(movement.has("sprint_multiplier"))
	assert_true(movement.has("jump_height"))
	assert_true(is_equal_approx(movement["walk_speed"], 4.5))


func test_attack_tuning_is_exported() -> void:
	var attack: Dictionary = TuningExport.collect()["attack"]["player_attack"]
	assert_true(attack.has("damage"))
	assert_true(attack.has("cooldown"))
	assert_true(attack.has("reach"))


## `"(1600, 900)"` is a thing a server would have to parse; two named numbers
## are not.
func test_godot_types_are_unwrapped_rather_than_stringified() -> void:
	var config := StructureConfig.new()
	var values := TuningExport.values_of(config)
	assert_true(values.has("wall_height"))
	assert_true(values["wall_height"] is float)

	var camera := CameraConfig.new()
	var colours := TuningExport.values_of(DayNightConfig.new())
	assert_true(colours["day_color"] is Dictionary, "a colour went out as a Godot type")
	assert_true((colours["day_color"] as Dictionary).has("r"))
	assert_true(TuningExport.values_of(camera)["distance"] is float)


func test_clip_names_come_out_as_strings() -> void:
	var values := TuningExport.values_of(AnimationConfig.new())
	assert_true(values["idle_animation"] is String, "a StringName is not JSON")


## A material is a thing the server does not simulate.
func test_nested_resources_are_named_rather_than_followed() -> void:
	var config: StructureConfig = load("res://resources/structures/prototype_structure.tres")
	var values := TuningExport.values_of(config)
	assert_true(values["wall_material"] is String)
	assert_true((values["wall_material"] as String).begins_with("res://"))


func test_bookkeeping_properties_are_left_out() -> void:
	var values := TuningExport.values_of(HealthConfig.new())
	for skipped: String in TuningExport.SKIPPED:
		assert_false(values.has(skipped), "%s should not be exported" % skipped)


func test_it_writes_json_that_parses() -> void:
	assert_true(TuningExport.write(TEST_PATH))
	var text := FileAccess.get_file_as_string(TEST_PATH)
	assert_false(text.is_empty())

	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the export is not valid JSON")
	assert_true((parsed as Dictionary).has("movement"))


func test_a_bad_path_is_reported_rather_than_thrown() -> void:
	assert_false(TuningExport.write("res://nowhere/tuning.json"))


func test_a_missing_directory_yields_nothing() -> void:
	assert_true(TuningExport.collect("res://does_not_exist").is_empty())
