extends Node3D


func _on_cycle_debug_menu_display_mode_pressed() -> void:
	DebugMenu.style = wrapi(DebugMenu.style + 1, 0, DebugMenu.Style.MAX)
