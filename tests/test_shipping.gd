extends TestCase
## The things that have to be true for a build to reach a tester.
##
## Export presets, depot scripts and workflows fail in a particular way: not at
## all, until release day, and then in a form nobody can debug from a CI log.
## These are cheap and they run on every commit.
##
## What they cannot check is Steam itself -- no App ID, no credentials, nothing
## to upload to. See DEPLOY.md for what a human has to do.

const PRESETS: String = "res://export_presets.cfg"


func _presets() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PRESETS)
	return config


func _repo_file(relative: String) -> String:
	# ProjectSettings resolves res:// to the project root, which is the repo
	# root here -- the workflows live outside res:// as far as Godot cares, so
	# they are read through the OS path.
	return FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://").path_join(relative)
	)


func test_the_export_presets_exist_and_are_readable() -> void:
	assert_true(FileAccess.file_exists(PRESETS), "there is nothing to export with")
	assert_eq(_presets().load(PRESETS), OK, "%s is malformed" % PRESETS)


## Godot matches a preset by its exact name and exports nothing at all when it
## does not find one -- no error, just no file. build.sh asks for these two.
func test_the_presets_are_named_what_the_build_script_asks_for() -> void:
	var config := _presets()
	var names: Array[String] = []
	for section: String in config.get_sections():
		if config.has_section_key(section, "name"):
			names.append(config.get_value(section, "name"))

	for wanted: String in ["Linux", "Windows"]:
		assert_true(names.has(wanted), "no preset named %s; build.sh asks for it" % wanted)


## One x86_64 Linux build covers desktop Linux, the Steam Deck and the Steam
## Machine -- all three are SteamOS or Linux on x86_64.
func test_both_platforms_are_x86_64() -> void:
	var config := _presets()
	for section: String in config.get_sections():
		if not section.ends_with(".options"):
			continue
		var architecture: String = config.get_value(section, "binary_format/architecture", "")
		if not architecture.is_empty():
			assert_eq(architecture, "x86_64", "%s targets %s" % [section, architecture])


## Embedded, so a tester gets one file rather than a binary that silently needs
## a .pck beside it.
func test_the_pack_is_embedded_in_the_binary() -> void:
	var config := _presets()
	for section: String in config.get_sections():
		if section.ends_with(".options"):
			assert_true(
				config.get_value(section, "binary_format/embed_pck", false),
				"%s ships a separate .pck, which testers will lose" % section
			)


## Tests and the devblog are not gameplay. Shipping them is 12 000 lines of
## GDScript in a build, and the devblog is the project's internal notes.
func test_the_build_excludes_what_players_do_not_need() -> void:
	var config := _presets()
	for section: String in config.get_sections():
		if section.ends_with(".options"):
			continue
		var excluded: String = config.get_value(section, "exclude_filter", "")
		for unwanted: String in ["tests/", "devblog/"]:
			assert_true(
				excluded.contains(unwanted),
				"preset %s ships %s" % [section, unwanted]
			)


func test_the_depot_scripts_exist() -> void:
	for name: String in ["app_build.vdf", "depot_linux.vdf", "depot_windows.vdf"]:
		assert_false(
			_repo_file("steam/%s" % name).is_empty(), "steam/%s is missing or empty" % name
		)


## SetLive empty means "upload, change nothing". A manual script that promotes
## on every run is one nobody dares run.
func test_the_manual_build_script_does_not_promote_itself() -> void:
	var text := _repo_file("steam/app_build.vdf")
	assert_true(text.contains("\"SetLive\" \"\""), "app_build.vdf sets a branch live by itself")


## The depots must point at what build.sh actually produces, or the upload
## succeeds with nothing in it.
func test_the_depots_point_at_the_build_output() -> void:
	assert_true(
		_repo_file("steam/depot_linux.vdf").contains("../build/linux/"),
		"the Linux depot does not point at the Linux build"
	)
	assert_true(
		_repo_file("steam/depot_windows.vdf").contains("../build/windows/"),
		"the Windows depot does not point at the Windows build"
	)


func test_the_workflows_exist() -> void:
	for name: String in ["test.yml", "release.yml"]:
		assert_false(
			_repo_file(".github/workflows/%s" % name).is_empty(),
			".github/workflows/%s is missing" % name
		)


## Nothing reaches a tester that has not been through the suite.
func test_the_release_workflow_runs_the_tests_first() -> void:
	var text := _repo_file(".github/workflows/release.yml")
	assert_true(text.contains("uses: ./.github/workflows/test.yml"), "release skips the suite")
	assert_true(text.contains("needs: tests"), "the build does not wait for the suite")


## The one that fails silently and ruins a release day: a Linux binary without
## its executable bit installs fine and then does nothing when launched.
func test_the_executable_bit_is_set_in_both_places() -> void:
	assert_true(
		_repo_file("build.sh").contains("chmod +x"),
		"build.sh does not make the Linux binary executable"
	)
	assert_true(
		_repo_file(".github/workflows/release.yml").contains("chmod +x build/linux/"),
		"the Steam job does not restore the bit that download-artifact drops"
	)


## The engine used to build has to be the engine that was tested against.
func test_ci_builds_with_the_pinned_engine_version() -> void:
	for name: String in ["test.yml", "release.yml"]:
		var text := _repo_file(".github/workflows/%s" % name)
		assert_true(
			text.contains("cat .godot-version"),
			"%s does not read the pin, so it can build with a different engine" % name
		)


## Credentials belong in repository secrets, never in the tree.
func test_no_steam_credentials_are_committed() -> void:
	for name: String in ["app_build.vdf", "depot_linux.vdf", "depot_windows.vdf"]:
		var text := _repo_file("steam/%s" % name).to_lower()
		for leak: String in ["password", "steamguard", "\"login\""]:
			assert_false(text.contains(leak), "steam/%s looks like it contains a credential" % name)

	var workflow := _repo_file(".github/workflows/release.yml")
	assert_true(workflow.contains("secrets.STEAM_USERNAME"), "the workflow inlines a username")
	assert_true(workflow.contains("secrets.STEAM_CONFIG_VDF"), "the workflow inlines a session")
