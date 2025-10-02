@tool
extends EditorPlugin

var dock: Control
var added_to_bottom: bool = false #Tracks where the dock was added (Don't touch)

# ----------------USE_BOTTOM_PANEL------------------------
# Set to true to move the tab to the bottom panel:
# Restart plugin to apply changes!
@export var use_bottom_panel: bool = false
# --------------------------------------------------------

func _enter_tree() -> void:
	_cleanup()

	dock = preload("res://addons/fuku/control.tscn").instantiate()

	if use_bottom_panel:
		add_control_to_bottom_panel(dock, "Fuku")
		added_to_bottom = true
	else:
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
		added_to_bottom = false

func _exit_tree() -> void:
	_cleanup()


func _cleanup() -> void:
	if not is_instance_valid(dock):
		return

	if added_to_bottom:
		remove_control_from_bottom_panel(dock)
	else:
		remove_control_from_docks(dock)
		
	dock.queue_free()
	dock = null
