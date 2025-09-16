@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("Webstar", "res://addons/webstar_networking/webstar.gd")
	pass


func _exit_tree() -> void:
	remove_autoload_singleton("Webstar")
	pass
