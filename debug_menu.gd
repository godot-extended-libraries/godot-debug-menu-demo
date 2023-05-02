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

# Number of frames to keep in history.
const HISTORY_NUM_FRAMES = 150

const GRAPH_SIZE = Vector2(150, 25)
const GRAPH_MIN_FPS = 10
const GRAPH_MAX_FPS = 160
const GRAPH_MIN_FRAMETIME = 1.0 / GRAPH_MIN_FPS
const GRAPH_MAX_FRAMETIME = 1.0 / GRAPH_MAX_FPS

# Value of `Time.get_ticks_usec()` on the previous frame.
var last_tick := 0

## Returns the sum of all values of an array (use as a parameter to `Array.reduce()`).
var sum_func := func avg(accum: float, number: float) -> float: return accum + number

# History of the last `HISTORY_NUM_FRAMES` rendered frames.
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[float] = []  # Only used for graphs.

var frametime_avg := GRAPH_MIN_FRAMETIME
var frametime_cpu_avg := GRAPH_MAX_FRAMETIME
var frametime_gpu_avg := GRAPH_MIN_FRAMETIME
var frames_per_second := float(GRAPH_MIN_FPS)

var frame_time_gradient := Gradient.new()

func _ready() -> void:
	fps_graph.draw.connect(_fps_graph_draw)
	total_graph.draw.connect(_total_graph_draw)
	cpu_graph.draw.connect(_cpu_graph_draw)
	gpu_graph.draw.connect(_gpu_graph_draw)

	# Fill in initial data to prevent graphs from looking strange before `HISTORY_NUM_FRAMES` frames
	# have been drawn.
	fps_history.resize(HISTORY_NUM_FRAMES)
	fps_history.fill(GRAPH_MIN_FPS)
	frame_history_total.resize(HISTORY_NUM_FRAMES)
	frame_history_total.fill(GRAPH_MIN_FRAMETIME)
	frame_history_cpu.resize(HISTORY_NUM_FRAMES)
	frame_history_cpu.fill(GRAPH_MIN_FRAMETIME)
	frame_history_gpu.resize(HISTORY_NUM_FRAMES)
	frame_history_gpu.fill(GRAPH_MIN_FRAMETIME)

	# NOTE: Both FPS and frametimes are colored following FPS logic
	# (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	# Colors are taken from <https://tailwindcolor.com/>.
	frame_time_gradient.set_color(0, Color8(239, 68, 68))   # red-500
	frame_time_gradient.set_color(1, Color8(56, 189, 248))  # light-blue-400
	frame_time_gradient.add_point(0.3333, Color8(250, 204, 21))  # yellow-400
	frame_time_gradient.add_point(0.6667, Color8(128, 226, 95))  # 50-50 mix of lime-400 and green-400

	get_viewport().size_changed.connect(update_settings_label)

	# Enable required time measurements to display CPU/GPU frame time information.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	update_information_label()
	update_settings_label()

## Update hardware information label (this can change at runtime based on window size and graphics settings).
func update_settings_label() -> void:
	var rendering_method_string := ""
	match str(ProjectSettings.get_setting("rendering/renderer/rendering_method")):
		"forward_plus":
			rendering_method_string = "Forward+"
		"mobile":
			rendering_method_string = "Forward Mobile"
		"gl_compatibility":
			rendering_method_string = "Compatibility"
	var viewport := get_viewport()
	settings.text = "Method: %s, Viewport: %d×%d\n" % [rendering_method_string, viewport.size.x, viewport.size.y]

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
		settings.text += "3D scale (%s): %d%% = %d×%d" % [
				"Bilinear" if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR else "FSR 1.0",
				viewport.scaling_3d_scale * 100,
				viewport.size.x * viewport.scaling_3d_scale,
				viewport.size.y * viewport.scaling_3d_scale,
		]

		if not antialiasing_3d_string.is_empty():
			settings.text += "\n3D Antialiasing: %s" % antialiasing_3d_string

		if environment.ssr_enabled:
			settings.text += "\nSSR: %d Steps" % environment.ssr_max_steps

		if environment.ssao_enabled:
			settings.text += "\nSSAO: On"

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
	# Make "NVIDIA Corporation" and "NVIDIA" be considered identical (required when using OpenGL to avoid redundancy).
	if RenderingServer.get_video_adapter_vendor().trim_suffix(" Corporation") in RenderingServer.get_video_adapter_name():
		# Avoid repeating vendor name before adapter name.
		# Trim redundant suffix sometimes reported by NVIDIA graphics cards when using OpenGL.
		adapter_string = RenderingServer.get_video_adapter_name().trim_suffix("/PCIe/SSE2")
	else:
		adapter_string = RenderingServer.get_video_adapter_vendor() + " - " + RenderingServer.get_video_adapter_name().trim_suffix("/PCIe/SSE2")

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
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
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
	var fps_polyline := PackedVector2Array()
	fps_polyline.resize(HISTORY_NUM_FRAMES)
	for fps_index in fps_history.size():
		fps_polyline[fps_index] = Vector2(
				remap(fps_index, 0, fps_history.size(), 0, GRAPH_SIZE.x),
				remap(clampf(fps_history[fps_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	fps_graph.draw_polyline(fps_polyline, frame_time_gradient.sample(remap(frames_per_second, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _total_graph_draw() -> void:
	var total_polyline := PackedVector2Array()
	total_polyline.resize(HISTORY_NUM_FRAMES)
	for total_index in frame_history_total.size():
		total_polyline[total_index] = Vector2(
				remap(total_index, 0, frame_history_total.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_total[total_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	total_graph.draw_polyline(total_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _cpu_graph_draw() -> void:
	var cpu_polyline := PackedVector2Array()
	cpu_polyline.resize(HISTORY_NUM_FRAMES)
	for cpu_index in frame_history_cpu.size():
		cpu_polyline[cpu_index] = Vector2(
				remap(cpu_index, 0, frame_history_cpu.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_cpu[cpu_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	cpu_graph.draw_polyline(cpu_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_cpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _gpu_graph_draw() -> void:
	var gpu_polyline := PackedVector2Array()
	gpu_polyline.resize(HISTORY_NUM_FRAMES)
	for gpu_index in frame_history_gpu.size():
		gpu_polyline[gpu_index] = Vector2(
				remap(gpu_index, 0, frame_history_gpu.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_gpu[gpu_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	gpu_graph.draw_polyline(gpu_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_gpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _process(_delta: float) -> void:
	fps_graph.queue_redraw()
	total_graph.queue_redraw()
	cpu_graph.queue_redraw()
	gpu_graph.queue_redraw()

	# Difference between the last two rendered frames in milliseconds.
	var frametime := (Time.get_ticks_usec() - last_tick) * 0.001

	frame_history_total.push_back(frametime)
	if frame_history_total.size() > HISTORY_NUM_FRAMES:
		frame_history_total.pop_front()

	# Frametimes are colored following FPS logic (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	frametime_avg = frame_history_total.reduce(sum_func) / frame_history_total.size()
	frame_history_total_avg.text = str(frametime_avg).pad_decimals(2)
	frame_history_total_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_min: float = frame_history_total.min()
	frame_history_total_min.text = str(frametime_min).pad_decimals(2)
	frame_history_total_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_max: float = frame_history_total.max()
	frame_history_total_max.text = str(frametime_max).pad_decimals(2)
	frame_history_total_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	frame_history_total_last.text = str(frametime).pad_decimals(2)
	frame_history_total_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var viewport_rid := get_viewport().get_viewport_rid()
	var frametime_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
	frame_history_cpu.push_back(frametime_cpu)
	if frame_history_cpu.size() > HISTORY_NUM_FRAMES:
		frame_history_cpu.pop_front()

	frametime_cpu_avg = frame_history_cpu.reduce(sum_func) / frame_history_cpu.size()
	frame_history_cpu_avg.text = str(frametime_cpu_avg).pad_decimals(2)
	frame_history_cpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_cpu_min: float = frame_history_cpu.min()
	frame_history_cpu_min.text = str(frametime_cpu_min).pad_decimals(2)
	frame_history_cpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_cpu_max: float = frame_history_cpu.max()
	frame_history_cpu_max.text = str(frametime_cpu_max).pad_decimals(2)
	frame_history_cpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	frame_history_cpu_last.text = str(frametime_cpu).pad_decimals(2)
	frame_history_cpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	frame_history_gpu.push_back(frametime_gpu)
	if frame_history_gpu.size() > HISTORY_NUM_FRAMES:
		frame_history_gpu.pop_front()

	frametime_gpu_avg = frame_history_gpu.reduce(sum_func) / frame_history_gpu.size()
	frame_history_gpu_avg.text = str(frametime_gpu_avg).pad_decimals(2)
	frame_history_gpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_gpu_min: float = frame_history_gpu.min()
	frame_history_gpu_min.text = str(frametime_gpu_min).pad_decimals(2)
	frame_history_gpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	var frametime_gpu_max: float = frame_history_gpu.max()
	frame_history_gpu_max.text = str(frametime_gpu_max).pad_decimals(2)
	frame_history_gpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	frame_history_gpu_last.text = str(frametime_gpu).pad_decimals(2)
	frame_history_gpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

	frames_per_second = 1000.0 / frametime_avg
	fps_history.push_back(frames_per_second)
	if fps_history.size() > HISTORY_NUM_FRAMES:
		fps_history.pop_front()

	fps.text = str(floor(frames_per_second)) + " FPS"
	var frame_time_color := frame_time_gradient.sample(remap(frames_per_second, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))
	fps.modulate = frame_time_color

	frame_time.text = str(frametime).pad_decimals(2) + " mspf"
	frame_time.modulate = frame_time_color

	var vsync_string := ""
	match DisplayServer.window_get_vsync_mode():
		DisplayServer.VSYNC_ENABLED:
			vsync_string = "V-Sync"
		DisplayServer.VSYNC_ADAPTIVE:
			vsync_string = "Adaptive V-Sync"
		DisplayServer.VSYNC_MAILBOX:
			vsync_string = "Mailbox V-Sync"

	if Engine.max_fps > 0 or OS.low_processor_usage_mode:
		# Display FPS cap determined by `Engine.max_fps` or low-processor usage mode sleep duration
		# (the lowest FPS cap is used).
		var low_processor_max_fps := roundf(1000000.0 / OS.low_processor_usage_mode_sleep_usec)
		var fps_cap := low_processor_max_fps
		if Engine.max_fps > 0:
			fps_cap = min(Engine.max_fps, low_processor_max_fps)
		frame_time.text += " (cap: " + str(fps_cap) + " FPS"

		if not vsync_string.is_empty():
			frame_time.text += " + " + vsync_string

		frame_time.text += ")"
	else:
		if not vsync_string.is_empty():
			frame_time.text += " (" + vsync_string + ")"

	frame_number.text = "Frame: " + str(Engine.get_frames_drawn())

	last_tick = Time.get_ticks_usec()
