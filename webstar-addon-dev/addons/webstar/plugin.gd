@tool
extends EditorPlugin

## WebStar Networking Plugin
## 
## This plugin provides WebRTC star topology networking for multiplayer games.
## It includes automatic WebSocket fallback and host migration capabilities.

const WebStarManager = preload("res://addons/webstar/webstar_manager.gd")
const WebStarConfig = preload("res://addons/webstar/webstar_config.gd")

func _enter_tree():
	# Add the WebStar autoload
	add_autoload_singleton("WebStar", "res://addons/webstar/webstar_manager.gd")
	
	# Add custom types for easier access
	add_custom_type(
		"WebStarManager",
		"Node", 
		preload("res://addons/webstar/webstar_manager.gd"),
		preload("res://addons/webstar/icons/webstar_manager.svg")
	)
	
	add_custom_type(
		"WebStarConfig",
		"Resource",
		preload("res://addons/webstar/webstar_config.gd"), 
		preload("res://addons/webstar/icons/webstar_config.svg")
	)
	
	print("WebStar Networking plugin enabled")

func _exit_tree():
	# Remove autoload
	remove_autoload_singleton("WebStar")
	
	# Remove custom types
	remove_custom_type("WebStarManager")
	remove_custom_type("WebStarConfig")
	
	print("WebStar Networking plugin disabled")

func get_plugin_name():
	return "WebStar Networking"
