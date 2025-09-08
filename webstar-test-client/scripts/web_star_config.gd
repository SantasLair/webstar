extends Node


func _ready():
	# Configure WebStar
	var config = WebStarConfig.new()
	config.set_signaling_server("ws://localhost:5090/ws")	
	
	WebStar.initialize_with_config(config)
