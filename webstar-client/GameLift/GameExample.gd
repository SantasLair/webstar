extends Node

# Example game integration with GameLift
# This script shows how to integrate your game logic with GameLiftManager

var player_sessions = {}  # Dictionary to track player sessions
var game_state = "waiting"  # waiting, active, ended

func _ready():
	# Connect to NetworkManager signals
	if NetworkManager.gamelift_manager:
		NetworkManager.gamelift_manager.connect("game_session_started", _on_gamelift_session_started)
		NetworkManager.gamelift_manager.connect("game_session_ended", _on_gamelift_session_ended)
		NetworkManager.gamelift_manager.connect("player_session_created", _on_gamelift_player_joined)
		NetworkManager.gamelift_manager.connect("player_session_terminated", _on_gamelift_player_left)
	
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_gamelift_session_started(session_id: String):
	print("[GameExample] GameLift session started: ", session_id)
	game_state = "waiting"
	player_sessions.clear()
	
	# Log game session start
	NetworkManager.log_gamelift_event("game_session_started", {
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_gamelift_session_ended(session_id: String):
	print("[GameExample] GameLift session ended: ", session_id)
	game_state = "ended"
	
	# Log game session end
	NetworkManager.log_gamelift_event("game_session_ended", {
		"session_id": session_id,
		"final_player_count": player_sessions.size(),
		"game_duration": _get_game_duration()
	})

func _on_gamelift_player_joined(player_session_id: String, player_id: String):
	print("[GameExample] Player joined - Session: %s, ID: %s" % [player_session_id, player_id])
	
	# Store player session info
	player_sessions[player_session_id] = {
		"player_id": player_id,
		"join_time": Time.get_unix_time_from_system(),
		"peer_id": null  # Will be set when peer connects
	}
	
	# Log player join
	NetworkManager.log_gamelift_event("player_joined", {
		"player_session_id": player_session_id,
		"player_id": player_id,
		"total_players": player_sessions.size()
	})
	
	# Check if we should start the game
	_check_game_start_conditions()

func _on_gamelift_player_left(player_session_id: String, player_id: String):
	print("[GameExample] Player left - Session: %s, ID: %s" % [player_session_id, player_id])
	
	if player_sessions.has(player_session_id):
		var session_data = player_sessions[player_session_id]
		
		# Log player leave
		NetworkManager.log_gamelift_event("player_left", {
			"player_session_id": player_session_id,
			"player_id": player_id,
			"session_duration": Time.get_unix_time_from_system() - session_data.join_time,
			"remaining_players": player_sessions.size() - 1
		})
		
		player_sessions.erase(player_session_id)
	
	# Check if game should end
	_check_game_end_conditions()

func _on_peer_connected(peer_id: int):
	print("[GameExample] Peer connected: ", peer_id)
	
	# Find and link the peer to a player session
	# In a real implementation, you'd have a way to map peer_id to player_session_id
	# For now, we'll just assign to the first available session
	for session_id in player_sessions:
		if player_sessions[session_id].peer_id == null:
			player_sessions[session_id].peer_id = peer_id
			print("[GameExample] Linked peer %d to session %s" % [peer_id, session_id])
			break

func _on_peer_disconnected(peer_id: int):
	print("[GameExample] Peer disconnected: ", peer_id)
	
	# Find the corresponding player session and remove it from GameLift
	for session_id in player_sessions:
		if player_sessions[session_id].peer_id == peer_id:
			NetworkManager.remove_player_session(session_id)
			break

func _check_game_start_conditions():
	# Start game when we have 2 or more players (customize as needed)
	if game_state == "waiting" and player_sessions.size() >= 2:
		_start_game()

func _check_game_end_conditions():
	# End game if we have fewer than 2 players during active game
	if game_state == "active" and player_sessions.size() < 2:
		_end_game("insufficient_players")

func _start_game():
	print("[GameExample] Starting game with %d players" % player_sessions.size())
	game_state = "active"
	
	NetworkManager.log_gamelift_event("game_started", {
		"player_count": player_sessions.size(),
		"players": _get_player_list()
	})
	
	# Your game start logic here
	# - Initialize game world
	# - Spawn players
	# - Start game timer
	# - etc.

func _end_game(reason: String = "completed"):
	print("[GameExample] Ending game. Reason: ", reason)
	game_state = "ended"
	
	NetworkManager.log_gamelift_event("game_ended", {
		"reason": reason,
		"final_player_count": player_sessions.size(),
		"game_duration": _get_game_duration(),
		"players": _get_player_list()
	})
	
	# Your game end logic here
	# - Calculate scores
	# - Show results
	# - Clean up resources
	# - etc.
	
	# In a real game, you might want to keep the session alive for a bit
	# to show results, then gracefully shut down

func _get_player_list() -> Array:
	var players = []
	for session_id in player_sessions:
		players.append({
			"session_id": session_id,
			"player_id": player_sessions[session_id].player_id,
			"peer_id": player_sessions[session_id].peer_id
		})
	return players

func _get_game_duration() -> float:
	# Return game duration in seconds
	# You'd implement this based on when your game actually started
	return 0.0

# Example of custom game events
func on_player_scored(player_session_id: String, points: int):
	NetworkManager.log_gamelift_event("player_scored", {
		"player_session_id": player_session_id,
		"points": points,
		"game_time": _get_game_duration()
	})

func on_player_died(player_session_id: String, cause: String):
	NetworkManager.log_gamelift_event("player_died", {
		"player_session_id": player_session_id,
		"cause": cause,
		"game_time": _get_game_duration()
	})

func on_match_completed(winner_session_id: String, final_scores: Dictionary):
	NetworkManager.log_gamelift_event("match_completed", {
		"winner_session_id": winner_session_id,
		"final_scores": final_scores,
		"match_duration": _get_game_duration()
	})
	
	_end_game("completed")