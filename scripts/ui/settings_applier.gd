class_name SettingsApplier
extends RefCounted
## Makes the machine obey a [GameSettings].
##
## The only file in the settings feature that talks to the window, the renderer
## or the audio server. Kept apart because none of it can be checked in a
## headless test -- there is no window to resize -- so everything that *can* be
## checked lives in [GameSettings] and [SettingsStore] instead.

## Applies everything to [param window].
##
## Order matters in one place: the monitor is chosen before the mode, because
## going fullscreen moves the window to whichever screen it is currently on.
static func apply(settings: GameSettings, window: Window) -> void:
	if settings == null or window == null:
		return
	apply_monitor(settings, window)
	apply_display_mode(settings, window)
	apply_frame_pacing(settings, window)
	apply_rendering(settings, window)
	apply_audio(settings)


static func apply_monitor(settings: GameSettings, window: Window) -> void:
	if DisplayServer.get_screen_count() <= 1:
		return
	var screen := clampi(settings.monitor, 0, DisplayServer.get_screen_count() - 1)
	if window.current_screen != screen:
		window.current_screen = screen


static func apply_display_mode(settings: GameSettings, window: Window) -> void:
	match settings.display_mode:
		GameSettings.DisplayMode.FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			window.borderless = false
		GameSettings.DisplayMode.BORDERLESS:
			window.mode = Window.MODE_FULLSCREEN
			window.borderless = true
		_:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			window.size = settings.resolution
			# Re-centre, or a window that just shrank sits with its title bar
			# off the top of the screen.
			var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
			window.position = usable.position + (usable.size - window.size) / 2


static func apply_frame_pacing(settings: GameSettings, _window: Window) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = settings.max_fps


static func apply_rendering(settings: GameSettings, window: Window) -> void:
	window.scaling_3d_scale = settings.render_scale
	window.msaa_3d = _msaa_mode(settings.msaa)


## Master volume, converted from a linear slider to decibels.
##
## Silence is not "0 dB", it is negative infinity -- so a slider at zero has to
## mute the bus rather than set a very small number, or the quietest setting is
## still audible.
static func apply_audio(settings: GameSettings) -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, settings.master_volume <= 0.0)
	if settings.master_volume > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(settings.master_volume))


## Pushes the two settings that belong to the camera onto its config.
##
## Duplicated first, or this edits the .tres every camera in the project shares
## -- the resource cache trap from post 013.
static func apply_to_camera(settings: GameSettings, camera: CameraController) -> void:
	if camera == null or camera.config == null:
		return
	camera.config = camera.config.duplicate()
	camera.config.look_sensitivity = settings.look_sensitivity
	camera.config.invert_pitch = settings.invert_pitch


static func _msaa_mode(level: int) -> Viewport.MSAA:
	match level:
		2:
			return Viewport.MSAA_2X
		4:
			return Viewport.MSAA_4X
		8:
			return Viewport.MSAA_8X
		_:
			return Viewport.MSAA_DISABLED
