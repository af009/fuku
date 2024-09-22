@tool
extends EditorPlugin

var dock: Control

# To move the tab to the bottom panel, change this variable to true and restart the plugin
const BOTTOM_PANEL: bool = false

func _enter_tree() -> void:
	dock = preload("res://addons/fuku/control.tscn").instantiate()
	
	if BOTTOM_PANEL:
		add_control_to_bottom_panel(dock, "Fuku")
	else:
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if is_instance_valid(dock):
		remove_control_from_bottom_panel(dock)
		remove_control_from_docks(dock)
		dock.queue_free()
	dock = null
