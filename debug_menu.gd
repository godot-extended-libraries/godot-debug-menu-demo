extends Control


@export var fps: Label
@export var frame_time: Label
@export var frame_number: Label
@export var frame_history_total_avg: Label
@export var frame_history_total_min: Label
@export var frame_history_total_max: Label
@export var frame_history_total_last: Label
@export var frame_history_cpu_avg: Label
@export var frame_history_cpu_min: Label
@export var frame_history_cpu_max: Label
@export var frame_history_cpu_last: Label
@export var frame_history_gpu_avg: Label
@export var frame_history_gpu_min: Label
@export var frame_history_gpu_max: Label
@export var frame_history_gpu_last: Label
@export var fps_graph: Panel
@export var total_graph: Panel
@export var cpu_graph: Panel
@export var gpu_graph: Panel
@export var information: Label
@export var settings: Label

# Value of `Time.get_ticks_usec()` on the previous frame.
var last_tick := 0

# History of the last 100 rendered frames. This makes the "max" values effectively 1% performance lows.
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[Float] = []  # Only used for graphs.

var frame_time_gradient := Gradient.new()

func _ready() -> void:
	fps_graph.draw.connect(_fps_graph_draw)
	frame_time_gradient.set_color(0, Color.RED)
	frame_time_gradient.set_color(1, Color.CYAN)
	frame_time_gradient.add_point(0.3333, Color.YELLOW)
	frame_time_gradient.add_point(0.6667, Color.GREEN)

	get_viewport().size_changed.connect(update_settings_label)

	# Enable required time measurements to display CPU/GPU frame time information.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	update_information_label()
	update_settings_label()

## Update hardware information label (this can change at runtime based on window size and graphics settings).
func update_settings_label() -> void:
	var vsync_string := ""
	match DisplayServer.window_get_vsync_mode():
		DisplayServer.VSYNC_DISABLED:
			vsync_string = "Disabled"
		DisplayServer.VSYNC_ENABLED:
			vsync_string = "Enabled"
		DisplayServer.VSYNC_ADAPTIVE:
			vsync_string = "Adaptive"
		DisplayServer.VSYNC_MAILBOX:
			vsync_string = "Mailbox"

	var viewport := get_viewport()
	settings.text = (
			"%d×%d, V-Sync: %s\n" % [viewport.size.x, viewport.size.y, vsync_string]
	)

	# Display 3D settings only if relevant.
	if viewport.get_camera_3d():
		var antialiasing_3d_string := ""
		if viewport.use_taa:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "TAA"
		if viewport.msaa_3d >= Viewport.MSAA_2X:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "%d× MSAA" % pow(2, viewport.msaa_3d)
		if viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "FXAA"

		var environment := viewport.get_camera_3d().get_world_3d().environment
		settings.text += (
				"3D scale (%s): %d%% = %d×%d" % ["Bilinear" if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR else "FSR 1.0", viewport.scaling_3d_scale * 100, viewport.size.x * viewport.scaling_3d_scale, viewport.size.y * viewport.scaling_3d_scale]
#				+ "Dir. Shadow Size, Filter: %d, %d\n" % [ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"), ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")]
#				+ "Pos. Shadow Size, Filter: %d, %d" % [ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/size"), ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")]
		)

		if not antialiasing_3d_string.is_empty():
			settings.text += "\n3D Antialiasing: %s" % antialiasing_3d_string

		if environment.ssr_enabled:
			settings.text += "\nSSR: %d Steps" % environment.ssr_max_steps

		if environment.ssao_enabled:
			settings.text += "\nSSAO: On"
#			settings.text += "\nSSAO: On (%d)" % RenderingServer.environment_get_ssao_quality()

		if environment.ssil_enabled:
			settings.text += "\nSSIL: On"

		if environment.sdfgi_enabled:
			settings.text += "\nSDFGI: %d Cascades" % environment.sdfgi_cascades

		if environment.glow_enabled:
			settings.text += "\nGlow: On"

		if environment.volumetric_fog_enabled:
			settings.text += "\nVolumetric Fog: On"

	var antialiasing_2d_string := ""
	if viewport.msaa_2d >= Viewport.MSAA_2X:
		antialiasing_2d_string = "%d× MSAA" % pow(2, viewport.msaa_2d)

	if not antialiasing_2d_string.is_empty():
		settings.text += "\n2D Antialiasing: %s" % antialiasing_2d_string


## Update hardware/software information label (this never changes at runtime).
func update_information_label() -> void:
	var adapter_string := ""
	if RenderingServer.get_video_adapter_vendor() in RenderingServer.get_video_adapter_name():
		# Avoid repeating vendor name before adapter name.
		adapter_string = RenderingServer.get_video_adapter_name()
	else:
		adapter_string = RenderingServer.get_video_adapter_vendor() + " - " + RenderingServer.get_video_adapter_name()

	# Graphics driver version information isn't always availble.
	var driver_info := OS.get_video_adapter_driver_info()
	var driver_info_string := ""
	if driver_info.size() >= 2:
		driver_info_string = driver_info[1]
	else:
		driver_info_string = "(unknown)"

	var release_string := ""
	if OS.has_feature("editor"):
		# Editor build (implies `debug`).
		release_string = "editor"
	elif OS.has_feature("debug"):
		# Debug export template build.
		release_string = "debug"
	else:
		# Release export template build.
		release_string = "release"

	var graphics_api_string := ""
	if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "compatibility":
		graphics_api_string = "Vulkan"
	else:
		if OS.has_feature("web"):
			graphics_api_string = "WebGL"
		elif OS.has_feature("mobile"):
			graphics_api_string = "OpenGL ES"
		else:
			graphics_api_string = "OpenGL"

	information.text = (
			"%s, %d threads\n" % [OS.get_processor_name().replace("(R)", "").replace("(TM)", ""), OS.get_processor_count()]
			+ "%s %s (%s %s), %s %s\n" % [OS.get_name(), "64-bit" if OS.has_feature("64") else "32-bit", release_string, "double" if OS.has_feature("double") else "single", graphics_api_string, RenderingServer.get_video_adapter_api_version()]
			+ "%s, %s" % [adapter_string, driver_info_string]
	)


func _fps_graph_draw() -> void:
	var fps_polyline = PackedVector2Array()
	draw_polyline(fps_polyline, 2.0, true)
	fps_graph.draw_circle(Vector2.ZERO, 50, Color.RED)


func _process(_delta: float) -> void:
	Engine.max_fps = 120
	# Difference between the last two rendered frames in milliseconds.
	var frametime := (Time.get_ticks_usec() - last_tick) * 0.001

	frame_history_total.push_back(frametime)
	if frame_history_total.size() > 100:
		frame_history_total.pop_front()

	# Frametimes are colored following FPS logic (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	var frametime_avg: float = frame_history_total.reduce(func avg(accum, number): return accum + number) / frame_history_total.size()
	frame_history_total_avg.text = str(frametime_avg).pad_decimals(2)
	frame_history_total_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_avg, 10, 160, 0.0, 1.0))

	var frametime_min: float = frame_history_total.min()
	frame_history_total_min.text = str(frametime_min).pad_decimals(2)
	frame_history_total_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_min, 10, 160, 0.0, 1.0))

	var frametime_max: float = frame_history_total.max()
	frame_history_total_max.text = str(frametime_max).pad_decimals(2)
	frame_history_total_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_max, 10, 160, 0.0, 1.0))

	frame_history_total_last.text = str(frametime).pad_decimals(2)
	frame_history_total_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime, 10, 160, 0.0, 1.0))

	var viewport_rid := get_viewport().get_viewport_rid()
	var frametime_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
	frame_history_cpu.push_back(frametime_cpu)
	if frame_history_cpu.size() > 100:
		frame_history_cpu.pop_front()

	var frametime_cpu_avg: float = frame_history_cpu.reduce(func avg(accum, number): return accum + number) / frame_history_cpu.size()
	frame_history_cpu_avg.text = str(frametime_cpu_avg).pad_decimals(2)
	frame_history_cpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_avg, 10, 160, 0.0, 1.0))

	var frametime_cpu_min: float = frame_history_cpu.min()
	frame_history_cpu_min.text = str(frametime_cpu_min).pad_decimals(2)
	frame_history_cpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_min, 10, 160, 0.0, 1.0))

	var frametime_cpu_max: float = frame_history_cpu.max()
	frame_history_cpu_max.text = str(frametime_cpu_max).pad_decimals(2)
	frame_history_cpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_max, 10, 160, 0.0, 1.0))

	frame_history_cpu_last.text = str(frametime_cpu).pad_decimals(2)
	frame_history_cpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu, 10, 160, 0.0, 1.0))

	var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	frame_history_gpu.push_back(frametime_gpu)
	if frame_history_gpu.size() > 100:
		frame_history_gpu.pop_front()

	var frametime_gpu_avg: float = frame_history_gpu.reduce(func avg(accum, number): return accum + number) / frame_history_gpu.size()
	frame_history_gpu_avg.text = str(frametime_gpu_avg).pad_decimals(2)
	frame_history_gpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_avg, 10, 160, 0.0, 1.0))

	var frametime_gpu_min: float = frame_history_gpu.min()
	frame_history_gpu_min.text = str(frametime_gpu_min).pad_decimals(2)
	frame_history_gpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_min, 10, 160, 0.0, 1.0))

	var frametime_gpu_max: float = frame_history_gpu.max()
	frame_history_gpu_max.text = str(frametime_gpu_max).pad_decimals(2)
	frame_history_gpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_max, 10, 160, 0.0, 1.0))

	frame_history_gpu_last.text = str(frametime_gpu).pad_decimals(2)
	frame_history_gpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu, 10, 160, 0.0, 1.0))

	var frames_per_second := 1000.0 / frametime_avg
	fps_history.push_back(frames_per_second)
	if fps_history.size() > 100:
		fps_history.pop_front()

	fps.text = str(floor(frames_per_second)) + " FPS"
	var frame_time_color := frame_time_gradient.sample(remap(frames_per_second, 10, 160, 0.0, 1.0))
	fps.modulate = frame_time_color

	frame_time.text = str(frametime).pad_decimals(2) + " mspf"
	frame_time.modulate = frame_time_color

	if Engine.max_fps > 0 or OS.low_processor_usage_mode:
		# Display FPS cap determined by `Engine.max_fps` or low-processor usage mode sleep duration
		# (the lowest FPS cap is used).
		var low_processor_max_fps := roundf(1000000.0 / OS.low_processor_usage_mode_sleep_usec)
		var fps_cap := low_processor_max_fps
		if Engine.max_fps > 0:
			fps_cap = min(Engine.max_fps, low_processor_max_fps)
		frame_time.text += " (cap: " + str(fps_cap) + " FPS)"

	frame_number.text = "Frame: " + str(Engine.get_frames_drawn())

	last_tick = Time.get_ticks_usec()
