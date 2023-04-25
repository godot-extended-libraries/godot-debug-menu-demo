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
var frame_history_total: Array = []
var frame_history_cpu: Array = []
var frame_history_gpu: Array = []

var frame_time_gradient := Gradient.new()

func _ready() -> void:
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
		var antialiasing_string := ""
		if viewport.use_taa:
			antialiasing_string += (" + " if not antialiasing_string.is_empty() else "") + "TAA"
		if viewport.msaa_3d >= Viewport.MSAA_2X:
			antialiasing_string += (" + " if not antialiasing_string.is_empty() else "") + "%d× MSAA" % pow(2, viewport.msaa_3d)
		if viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA:
			antialiasing_string += (" + " if not antialiasing_string.is_empty() else "") + "FXAA"

		var environment := viewport.get_camera_3d().get_world_3d().environment
		settings.text += (
				"3D scale (%s): %d%% = %d×%d\n" % ["Bilinear" if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR else "FSR 1.0", viewport.scaling_3d_scale * 100, viewport.size.x * viewport.scaling_3d_scale, viewport.size.y * viewport.scaling_3d_scale]
				+ "Antialiasing: %s\n" % antialiasing_string
				+ "Dir. Shadow Size, Filter: %d, %d\n" % [ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"), ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")]
				+ "Pos. Shadow Size, Filter: %d, %d" % [ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/size"), ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")]
		)

		if environment.ssr_enabled:
			settings.text += "\nSSR: On"

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
			# FIXME: 3D scale is displayed twice due to % formatting.


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

	information.text = (
			"%s, %d threads\n" % [OS.get_processor_name().replace("(R)", "").replace("(TM)", ""), OS.get_processor_count()]
			+ "%s %s %s, Vulkan %s\n" % [OS.get_name(), "64-bit" if OS.has_feature("64") else "32-bit", "(double precision)" if OS.has_feature("double") else "", RenderingServer.get_video_adapter_api_version()]
			+ "%s, %s" % [adapter_string, driver_info_string]
	)


func _process(_delta: float) -> void:
	# Different between the last two rendered frames in milliseconds.
	var frametime := (Time.get_ticks_usec() - last_tick) * 0.001
	fps.text = str(Engine.get_frames_per_second()) + " FPS"
	frame_time.text = str(frametime).pad_decimals(2) + " mspf"
	frame_number.text = "Frame: " + str(Engine.get_frames_drawn())

	frame_history_total.push_back(frametime)
	if frame_history_total.size() > 100:
		frame_history_total.pop_front()

	frame_history_total_avg.text = str(frame_history_total.reduce(func avg(accum, number): return accum + number) / frame_history_total.size()).pad_decimals(2)
	frame_history_total_min.text = str(frame_history_total.min()).pad_decimals(2)
	frame_history_total_max.text = str(frame_history_total.max()).pad_decimals(2)
	frame_history_total_last.text = str(frametime).pad_decimals(2)

	var viewport_rid := get_viewport().get_viewport_rid()
	frame_history_cpu.push_back(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu())
	if frame_history_cpu.size() > 100:
		frame_history_cpu.pop_front()

	frame_history_cpu_avg.text = str(frame_history_cpu.reduce(func avg(accum, number): return accum + number) / frame_history_cpu.size()).pad_decimals(2)
	frame_history_cpu_min.text = str(frame_history_cpu.min()).pad_decimals(2)
	frame_history_cpu_max.text = str(frame_history_cpu.max()).pad_decimals(2)
	frame_history_cpu_last.text = str(frametime).pad_decimals(2)

	frame_history_gpu.push_back(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	if frame_history_gpu.size() > 100:
		frame_history_gpu.pop_front()

	frame_history_gpu_avg.text = str(frame_history_gpu.reduce(func avg(accum, number): return accum + number) / frame_history_gpu.size()).pad_decimals(2)
	frame_history_gpu_min.text = str(frame_history_gpu.min()).pad_decimals(2)
	frame_history_gpu_max.text = str(frame_history_gpu.max()).pad_decimals(2)
	frame_history_gpu_last.text = str(frametime).pad_decimals(2)

	last_tick = Time.get_ticks_usec()
