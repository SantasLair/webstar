using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Amazon.GameLiftServer;
using Amazon.GameLiftServer.Model;
using Newtonsoft.Json;

public partial class GameLiftManager : Node
{
	#region Signals
	[Signal]
	public delegate void GameLiftInitializedEventHandler();
	
	[Signal]
	public delegate void GameSessionStartedEventHandler(string gameSessionId);
	
	[Signal]
	public delegate void GameSessionEndedEventHandler(string gameSessionId);
	
	[Signal]
	public delegate void PlayerSessionCreatedEventHandler(string playerSessionId, string playerId);
	
	[Signal]
	public delegate void PlayerSessionTerminatedEventHandler(string playerSessionId, string playerId);
	
	[Signal]
	public delegate void GameLiftErrorEventHandler(string error);
	#endregion

	#region Private Fields
	private bool _isInitialized = false;
	private bool _isGameSessionActive = false;
	private string _currentGameSessionId = "";
	private Dictionary<string, PlayerSession> _activePlayers = new Dictionary<string, PlayerSession>();
	private int _maxPlayers = 8;
	private int _serverPort = 7777;
	private string _logPath = "";
	#endregion

	#region Public Properties
	public bool IsInitialized => _isInitialized;
	public bool IsGameSessionActive => _isGameSessionActive;
	public string CurrentGameSessionId => _currentGameSessionId;
	public int MaxPlayers => _maxPlayers;
	public int ActivePlayerCount => _activePlayers.Count;
	#endregion

	#region Godot Lifecycle
	public override void _Ready()
	{
		GD.Print("[GameLift] GameLiftManager ready");
		
		// Only initialize on headless (server) builds
		if (DisplayServer.GetName() == "headless")
		{
			GD.Print("[GameLift] Running in headless mode, initializing GameLift...");
			CallDeferred(nameof(InitializeGameLift));
		}
		else
		{
			GD.Print("[GameLift] Not running in headless mode, GameLift disabled");
		}
	}

	public override void _ExitTree()
	{
		if (_isInitialized)
		{
			GD.Print("[GameLift] Shutting down GameLift integration...");
			ShutdownGameLift();
		}
	}
	#endregion

	#region GameLift Initialization
	private async void InitializeGameLift()
	{
		try
		{
			// Parse command line arguments for GameLift configuration
			ParseCommandLineArgs();
			
			// Set up log paths
			_logPath = OS.GetExecutablePath().GetBaseDir() + "/logs/";
			
			if (!DirAccess.DirExistsAbsolute(_logPath))
			{
				DirAccess.Open("user://").MakeDirRecursiveAbsolute(_logPath);
			}

			GD.Print($"[GameLift] Initializing with port: {_serverPort}, max players: {_maxPlayers}");
			GD.Print($"[GameLift] Log path: {_logPath}");

			// Initialize GameLift Server SDK
			var initOutcome = GameLiftServerAPI.InitSDK();
			
			if (!initOutcome.Success)
			{
				var error = $"GameLift initialization failed: {initOutcome.Error.ErrorMessage}";
				GD.PrintErr($"[GameLift] {error}");
				EmitSignal(SignalName.GameLiftError, error);
				return;
			}

			// Process parameters for the server
			var processParameters = new ProcessParameters(
				onStartGameSession: OnStartGameSession,
				onUpdateGameSession: OnUpdateGameSession,
				onProcessTerminate: OnProcessTerminate,
				onHealthCheck: OnHealthCheck,
				port: _serverPort,
				logParameters: new LogParameters(new List<string> 
				{ 
					_logPath + "game.log",
					_logPath + "engine.log" 
				})
			);

			// Process ready
			var processReadyOutcome = GameLiftServerAPI.ProcessReady(processParameters);
			
			if (!processReadyOutcome.Success)
			{
				var error = $"GameLift ProcessReady failed: {processReadyOutcome.Error.ErrorMessage}";
				GD.PrintErr($"[GameLift] {error}");
				EmitSignal(SignalName.GameLiftError, error);
				return;
			}

			_isInitialized = true;
			GD.Print("[GameLift] Successfully initialized and ready for game sessions");
			EmitSignal(SignalName.GameLiftInitialized);
		}
		catch (Exception ex)
		{
			var error = $"Exception during GameLift initialization: {ex.Message}";
			GD.PrintErr($"[GameLift] {error}");
			EmitSignal(SignalName.GameLiftError, error);
		}
	}

	private void ParseCommandLineArgs()
	{
		var args = OS.GetCmdlineArgs();
		
		for (int i = 0; i < args.Length; i++)
		{
			var arg = args[i];
			
			switch (arg)
			{
				case "-port":
					if (i + 1 < args.Length && int.TryParse(args[i + 1], out int port))
					{
						_serverPort = port;
						i++; // Skip next argument as it's the value
					}
					break;
					
				case "-maxplayers":
					if (i + 1 < args.Length && int.TryParse(args[i + 1], out int maxPlayers))
					{
						_maxPlayers = maxPlayers;
						i++; // Skip next argument as it's the value
					}
					break;
			}
		}
	}
	#endregion

	#region GameLift Callbacks
	private void OnStartGameSession(GameSession gameSession)
	{
		try
		{
			GD.Print($"[GameLift] Starting game session: {gameSession.GameSessionId}");
			GD.Print($"[GameLift] Max players: {gameSession.MaximumPlayerSessionCount}");
			GD.Print($"[GameLift] Game session data: {gameSession.GameSessionData}");
			
			_currentGameSessionId = gameSession.GameSessionId;
			_maxPlayers = gameSession.MaximumPlayerSessionCount;
			_isGameSessionActive = true;
			_activePlayers.Clear();

			// Activate the game session
			var activateOutcome = GameLiftServerAPI.ActivateGameSession();
			
			if (!activateOutcome.Success)
			{
				var error = $"Failed to activate game session: {activateOutcome.Error.ErrorMessage}";
				GD.PrintErr($"[GameLift] {error}");
				EmitSignal(SignalName.GameLiftError, error);
				return;
			}

			GD.Print($"[GameLift] Game session {gameSession.GameSessionId} activated successfully");
			EmitSignal(SignalName.GameSessionStarted, gameSession.GameSessionId);
			
			// Initialize the actual game server/lobby here
			CallDeferred(nameof(StartGameServer));
		}
		catch (Exception ex)
		{
			var error = $"Exception in OnStartGameSession: {ex.Message}";
			GD.PrintErr($"[GameLift] {error}");
			EmitSignal(SignalName.GameLiftError, error);
		}
	}

	private UpdateGameSession OnUpdateGameSession(UpdateGameSession updateGameSession)
	{
		try
		{
			GD.Print($"[GameLift] Update game session: {updateGameSession.GameSessionId}");
			GD.Print($"[GameLift] Update reason: {updateGameSession.UpdateReason}");
			
			// Handle game session updates (like backfill requests)
			return new UpdateGameSession();
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception in OnUpdateGameSession: {ex.Message}");
			return new UpdateGameSession();
		}
	}

	private void OnProcessTerminate()
	{
		try
		{
			GD.Print("[GameLift] Process termination requested");
			
			// End current game session if active
			if (_isGameSessionActive)
			{
				EndGameSession();
			}
			
			// Graceful shutdown
			GetTree().Quit();
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception in OnProcessTerminate: {ex.Message}");
			GetTree().Quit();
		}
	}

	private bool OnHealthCheck()
	{
		// Return true if the server is healthy
		// You can add custom health checks here
		return _isInitialized;
	}
	#endregion

	#region Player Session Management
	public bool AcceptPlayerSession(string playerSessionId)
	{
		if (!_isInitialized || !_isGameSessionActive)
		{
			GD.PrintErr("[GameLift] Cannot accept player session - GameLift not initialized or no active game session");
			return false;
		}

		try
		{
			var outcome = GameLiftServerAPI.AcceptPlayerSession(playerSessionId);
			
			if (!outcome.Success)
			{
				GD.PrintErr($"[GameLift] Failed to accept player session {playerSessionId}: {outcome.Error.ErrorMessage}");
				return false;
			}

			GD.Print($"[GameLift] Accepted player session: {playerSessionId}");
			return true;
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception accepting player session: {ex.Message}");
			return false;
		}
	}

	public bool RemovePlayerSession(string playerSessionId)
	{
		if (!_isInitialized || !_isGameSessionActive)
		{
			return false;
		}

		try
		{
			var outcome = GameLiftServerAPI.RemovePlayerSession(playerSessionId);
			
			if (!outcome.Success)
			{
				GD.PrintErr($"[GameLift] Failed to remove player session {playerSessionId}: {outcome.Error.ErrorMessage}");
				return false;
			}

			if (_activePlayers.ContainsKey(playerSessionId))
			{
				var playerId = _activePlayers[playerSessionId].PlayerId;
				_activePlayers.Remove(playerSessionId);
				EmitSignal(SignalName.PlayerSessionTerminated, playerSessionId, playerId);
			}

			GD.Print($"[GameLift] Removed player session: {playerSessionId}");
			return true;
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception removing player session: {ex.Message}");
			return false;
		}
	}

	public void ReportPlayerSessionStatus(string playerSessionId, PlayerSessionStatus status)
	{
		if (!_isInitialized)
			return;

		try
		{
			var playerSession = new PlayerSession
			{
				PlayerSessionId = playerSessionId,
				Status = status
			};

			var outcome = GameLiftServerAPI.UpdatePlayerSessionCreationPolicy(PlayerSessionCreationPolicy.ACCEPT_ALL);
			
			if (status == PlayerSessionStatus.ACTIVE && !_activePlayers.ContainsKey(playerSessionId))
			{
				_activePlayers[playerSessionId] = playerSession;
				EmitSignal(SignalName.PlayerSessionCreated, playerSessionId, playerSession.PlayerId ?? "");
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception reporting player session status: {ex.Message}");
		}
	}
	#endregion

	#region Game Server Management
	private void StartGameServer()
	{
		try
		{
			GD.Print("[GameLift] Starting game server...");
			
			// Get the network manager and create lobby
			var networkManager = GetNode("/root/NetworkManager");
			if (networkManager != null)
			{
				// Set the lobby name to the game session ID for uniqueness
				networkManager.Set("lobby_name", _currentGameSessionId);
				
				// Connect to lobby created signal to know when ready
				if (!networkManager.IsConnected("lobby_created", new Callable(this, nameof(OnLobbyCreated))))
				{
					networkManager.Connect("lobby_created", new Callable(this, nameof(OnLobbyCreated)));
				}
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception starting game server: {ex.Message}");
		}
	}

	private void OnLobbyCreated()
	{
		GD.Print("[GameLift] Game lobby created successfully");
	}

	private void EndGameSession()
	{
		if (!_isGameSessionActive)
			return;

		try
		{
			GD.Print($"[GameLift] Ending game session: {_currentGameSessionId}");

			// Remove all active players
			var playerSessions = new List<string>(_activePlayers.Keys);
			foreach (var playerSessionId in playerSessions)
			{
				RemovePlayerSession(playerSessionId);
			}

			// Terminate the game session
			var outcome = GameLiftServerAPI.TerminateGameSession();
			
			if (!outcome.Success)
			{
				GD.PrintErr($"[GameLift] Failed to terminate game session: {outcome.Error.ErrorMessage}");
			}

			_isGameSessionActive = false;
			var sessionId = _currentGameSessionId;
			_currentGameSessionId = "";
			_activePlayers.Clear();

			EmitSignal(SignalName.GameSessionEnded, sessionId);
			GD.Print("[GameLift] Game session ended successfully");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception ending game session: {ex.Message}");
		}
	}
	#endregion

	#region Utility Methods
	public void LogGameEvent(string eventName, Dictionary<string, object> eventData = null)
	{
		if (!_isInitialized)
			return;

		try
		{
			var logData = new Dictionary<string, object>
			{
				["timestamp"] = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
				["gameSessionId"] = _currentGameSessionId,
				["eventName"] = eventName
			};

			if (eventData != null)
			{
				foreach (var kvp in eventData)
				{
					logData[kvp.Key] = kvp.Value;
				}
			}

			var logMessage = JsonConvert.SerializeObject(logData);
			GD.Print($"[GameLift-Event] {logMessage}");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception logging game event: {ex.Message}");
		}
	}

	private void ShutdownGameLift()
	{
		try
		{
			if (_isGameSessionActive)
			{
				EndGameSession();
			}

			if (_isInitialized)
			{
				GameLiftServerAPI.Destroy();
				_isInitialized = false;
				GD.Print("[GameLift] GameLift SDK destroyed");
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"[GameLift] Exception during shutdown: {ex.Message}");
		}
	}

	public Dictionary<string, object> GetServerStatus()
	{
		return new Dictionary<string, object>
		{
			["isInitialized"] = _isInitialized,
			["isGameSessionActive"] = _isGameSessionActive,
			["currentGameSessionId"] = _currentGameSessionId,
			["activePlayerCount"] = _activePlayers.Count,
			["maxPlayers"] = _maxPlayers,
			["serverPort"] = _serverPort
		};
	}
	#endregion
}
