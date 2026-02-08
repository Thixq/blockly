///WebSocketService is a service class developed for creating WebSocket connections.
///It provides connection images, connection segments, and automatic reconnection segments.
enum SocketStatus {
  /// Connection in progress
  connecting,

  /// Connection established successfully
  connected,

  /// Connection has been closed or lost
  disconnected,

  /// Attempting to reconnect after a disconnection
  reconnecting,
}
