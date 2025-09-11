extends Node2D

## Visual Star Topology Demonstration
## Shows how WebStar implements star networking with visual connections

class_name StarTopologyDemo

var host_node: Node2D
var client_nodes: Array[Node2D] = []
var connection_lines: Array[Line2D] = []

var host_position := Vector2(400, 300)  # Center of screen
var client_positions := [
	Vector2(200, 150),  # Top-left
	Vector2(600, 150),  # Top-right  
	Vector2(200, 450),  # Bottom-left
	Vector2(600, 450),  # Bottom-right
	Vector2(400, 100),  # Top-center
	Vector2(400, 500)   # Bottom-center
]

var colors := {
	"host": Color.GOLD,
	"client": Color.CYAN,
	"connection": Color.GREEN,
	"data_flow": Color.RED
}

func _ready():
	print("🌟 === Visual Star Topology Demo ===")
	setup_demo()

func setup_demo():
	# Create host node (center)
	host_node = create_node("HOST", host_position, colors.host, true)
	add_child(host_node)
	
	# Create client nodes (around host)
	for i in range(min(6, client_positions.size())):
		var client_name = "CLIENT_%d" % (i + 1)
		var client = create_node(client_name, client_positions[i], colors.client, false)
		client_nodes.append(client)
		add_child(client)
		
		# Create connection line from client to host
		var line = create_connection_line(client_positions[i], host_position)
		connection_lines.append(line)
		add_child(line)
	
	# Add explanatory text
	create_demo_text()
	
	# Start animation
	animate_star_topology()

func create_node(label: String, pos: Vector2, color: Color, is_host: bool) -> Node2D:
	var node = Node2D.new()
	node.position = pos
	
	# Create circle background
	var circle = ColorRect.new()
	circle.size = Vector2(80, 80)
	circle.position = Vector2(-40, -40)
	circle.color = color
	
	# Make it circular using a shader or just keep it square for simplicity
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.corner_radius_top_left = 40
	stylebox.corner_radius_top_right = 40
	stylebox.corner_radius_bottom_left = 40
	stylebox.corner_radius_bottom_right = 40
	
	# Add label
	var text_label = Label.new()
	text_label.text = label
	text_label.position = Vector2(-30, -10)
	text_label.size = Vector2(60, 20)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override("font_color", Color.BLACK)
	
	node.add_child(circle)
	node.add_child(text_label)
	
	# Add host crown or client indicator
	if is_host:
		var crown_label = Label.new()
		crown_label.text = "👑"
		crown_label.position = Vector2(-10, -50)
		crown_label.size = Vector2(20, 20)
		node.add_child(crown_label)
	
	return node

func create_connection_line(from: Vector2, to: Vector2) -> Line2D:
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.default_color = colors.connection
	line.width = 3
	return line

func create_demo_text():
	# Title
	var title = Label.new()
	title.text = "WebStar Star Topology Architecture"
	title.position = Vector2(200, 20)
	title.size = Vector2(400, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	
	# Legend
	var legend = RichTextLabel.new()
	legend.position = Vector2(20, 80)
	legend.size = Vector2(150, 200)
	legend.bbcode_enabled = true
	legend.text = """[b]Star Topology:[/b]

[color=gold]👑 HOST[/color]
• Central hub
• Routes all messages
• Authoritative

[color=cyan]📱 CLIENTS[/color]  
• Connect only to host
• Send/receive via host
• No direct connections

[color=green]━ CONNECTIONS[/color]
• WebRTC P2P channels
• Low latency
• Reliable delivery"""
	
	add_child(legend)
	
	# Benefits box
	var benefits = RichTextLabel.new()
	benefits.position = Vector2(650, 80)
	benefits.size = Vector2(150, 200)
	benefits.bbcode_enabled = true
	benefits.text = """[b]Benefits:[/b]

🚀 [b]Performance[/b]
• O(n) connections
• Predictable routing
• Host authority

⚡ [b]Reliability[/b]
• Single point control
• Easy host migration
• Consistent state

🎮 [b]Gaming[/b]
• Anti-cheat friendly
• Deterministic sync
• Scales well"""
	
	add_child(benefits)

func animate_star_topology():
	print("🎬 Starting star topology animation...")
	
	# Animate data flow from clients to host
	var tween = create_tween()
	tween.set_loops()
	
	# Pulse host node
	tween.parallel().tween_method(pulse_host, 1.0, 1.3, 1.0)
	tween.parallel().tween_method(pulse_host, 1.3, 1.0, 1.0)
	
	# Animate connection lines
	for i in range(connection_lines.size()):
		var line = connection_lines[i]
		tween.parallel().tween_method(animate_line_color.bind(line), 0.0, 1.0, 2.0)

func pulse_host(scale_factor: float):
	if host_node:
		host_node.scale = Vector2(scale_factor, scale_factor)

func animate_line_color(line: Line2D, progress: float):
	var alpha = sin(progress * PI * 4) * 0.5 + 0.5
	line.default_color = Color(colors.connection.r, colors.connection.g, colors.connection.b, alpha)

func _input(event):
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed):
		print("🎯 Demo completed - Star topology visualized!")
		get_tree().quit()
