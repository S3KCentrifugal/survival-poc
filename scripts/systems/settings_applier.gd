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
	window.scaling_3d_scale = render_scale_for(settings, output_size(window, settings))
	window.msaa_3d = _msaa_mode(settings.msaa)


## The 3D render scale to actually use.
##
## Split out and given the output size as an argument rather than reading the
## window, so the policy -- the part with a decision in it -- is testable without
## a display. The window is only consulted by [method output_size].
static func render_scale_for(settings: GameSettings, output: Vector2i) -> float:
	if settings == null:
		return RenderBudget.MAX_SCALE
	return RenderBudget.scale_for(output) if settings.render_scale_auto else settings.render_scale


## How many pixels the game is actually drawing into.
##
## Asks the *settings* which surface is about to be filled, and only falls back
## to the window when there is nothing to ask -- because the window is not
## trustworthy here, which was found by checking rather than by reasoning.
## Setting [member Window.mode] to a fullscreen mode does not update
## [member Window.size] in the same frame: applying borderless fullscreen on a
## 6144x3456 display and immediately reading the window still reported the old
## 3840x2160, so the cap was computed for a resolution the game was no longer at.
##
## That failure is invisible. Fullscreen still works, the game still runs, and
## the render scale is simply the wrong one -- which reads as the cap not doing
## very much rather than as a bug.
static func output_size(window: Window, settings: GameSettings = null) -> Vector2i:
	var screen := Vector2i.ZERO
	var windowed := Vector2i.ZERO
	if window != null:
		screen = DisplayServer.screen_get_size(window.current_screen)
		windowed = window.size
	return output_size_for(settings, windowed, screen)


## Which of the two sizes the game will actually be drawing into.
##
## The decision, separated from the two lookups that feed it, so the part with a
## judgement in it can be tested without a display. [method output_size] is then
## only "ask the window, ask the screen, call this".
static func output_size_for(
	settings: GameSettings, window_size: Vector2i, screen_size: Vector2i
) -> Vector2i:
	if settings != null:
		# Both fullscreen modes fill the monitor, whatever the window currently
		# says and whatever resolution is remembered for windowed mode.
		if settings.uses_monitor_size():
			return screen_size if screen_size.x > 0 and screen_size.y > 0 else window_size
		if settings.resolution.x > 0 and settings.resolution.y > 0:
			return settings.resolution
	if window_size.x > 0 and window_size.y > 0:
		return window_size
	return screen_size


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
