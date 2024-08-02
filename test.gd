extends Node3D


func _on_cycle_debug_menu_display_mode_pressed() -> void:
	@warning_ignore("int_as_enum_without_cast")
	DebugMenu.style = wrapi(DebugMenu.style + 1, 0, DebugMenu.Style.MAX)


func _on_pause_toggled(toggled_on: bool) -> void:
	get_tree().paused = toggled_on
