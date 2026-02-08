// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';
import 'dart:convert';

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/enums/socket_status_enum.dart';
import 'package:blockly/feature/services/json_parser/websocket_isolate_parser.dart';
import 'package:meta/meta.dart'; // For @visibleForTesting
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Channel creator function type (For testability)
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

/// WebSocketService is a generic service class designed to manage WebSocket connections.
/// [T] represents the data model that will be received over the socket.
class WebSocketService<T> {
  /// Constructor
  WebSocketService({required Parser<T> parser, bool? manuellyRetry})
    : _parser = parser,
      _manuellyRetry = manuellyRetry ?? false;
  final Parser<T> _parser;

  final bool _manuellyRetry;

  /// Mock channel factory for use in tests
  @visibleForTesting
  WebSocketChannelFactory? channelFactory;

  final _logger = CustomLogger('WebSocketService');
  WebSocketChannel? _channel;
  SocketStatus _status = SocketStatus.disconnected;
  String? _lastUrl;

  int _retryCount = 0;
  final int _maxRetryDelaySeconds = 60;
  Timer? _reconnectTimer;

  // Heartbeat variables
  Timer? _heartbeatTimer;
  final Duration _inactivityTimeout = const Duration(seconds: 5);

  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  /// Stream where you can listen to the connection status.
  Stream<SocketStatus> get statusStream => _statusController.stream;

  final StreamController<T> _messageController =
      StreamController<T>.broadcast();

  /// Main stream where incoming messages can be listened to
  Stream<T> get messages => _messageController.stream;

  StreamSubscription<dynamic>? _subscription;

  // Background Isolate Parser
  WebSocketIsolateParser<T>? _isolateParser;
  bool _useIsolate = false;
  StreamSubscription<dynamic>? _isolateSubscription;

  /// Connects to the WebSocket server. Manages connection status and processes messages.
  Future<void> connect(String url, {bool useIsolate = false}) async {
    _lastUrl = url;
    _useIsolate = useIsolate;

    if (_status == SocketStatus.connected ||
        _status == SocketStatus.connecting) {
      _logger.warning('Already connected or connecting to $url');
      return;
    }

    // Initialize isolate if requested
    if (_useIsolate && _isolateParser == null) {
      try {
        _isolateParser = WebSocketIsolateParser<T>(_parser);
        await _isolateParser!.spawn();

        // Listen to objects coming from the isolate
        _isolateSubscription = _isolateParser!.output.listen((data) {
          if (data is List) {
            for (final item in data) {
              _messageController.add(item as T);
            }
          } else if (data is T) {
            _messageController.add(data);
          }
        });
      } catch (e) {
        _logger.error(
          'Failed to spawn isolate, falling back to main thread.',
          error: e,
        );
        _useIsolate = false;
        _isolateParser?.dispose();
        _isolateParser = null;
      }
    }

    _updateStatus(SocketStatus.connecting);
    _logger.info('Connecting to $url');

    try {
      if (channelFactory != null) {
        _channel = channelFactory!(Uri.parse(url));
      } else {
        _channel = WebSocketChannel.connect(Uri.parse(url));
      }

      await _channel!.ready;
      _onConnected();

      await _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: disconnect,
        onError: (Object? error) {
          _logger.error('Stream error occurred', error: error);
          _handleDisconnect();
        },
      );
    } catch (e, s) {
      _logger.error(
        'Unexpected error during connection',
        error: e,
        stackTrace: s,
      );
      _handleDisconnect();
    }
  }

  void _onConnected() {
    _logger.info('Connection established successfully');
    _updateStatus(SocketStatus.connected);
    _retryCount = 0;
    _startHeartbeat();
  }

  Future<void> _onMessageReceived(dynamic message) async {
    _resetHeartbeat();
    if (_messageController.isClosed) return;

    try {
      String payload;
      if (message is String) {
        payload = message;
      } else if (message is List<int>) {
        payload = utf8.decode(message);
      } else {
        throw FormatException(
          'Unsupported message type: ${message.runtimeType}',
        );
      }

      // 1. ISOLATE PATH
      if (_useIsolate && _isolateParser != null) {
        _isolateParser!.parse(payload);
        return;
      }

      // 2. MAIN THREAD PATH (Fallback)
      final jsonMap = jsonDecode(payload);

      if (_messageController.isClosed) return;

      if (jsonMap is Map && jsonMap['type'] == 'pong') {
        return;
      }

      if (jsonMap is List) {
        // Gelen veri bir liste ise (örn: !miniTicker@arr)
        for (final item in jsonMap) {
          if (item is Map) {
            final data = _parser(Map<String, dynamic>.from(item));
            _messageController.add(data);
          }
        }
      } else if (jsonMap is Map) {
        // Gelen veri tekil obje ise
        final data = _parser(Map<String, dynamic>.from(jsonMap));
        _messageController.add(data);
      }
    } catch (e, s) {
      if (_messageController.isClosed) return;
      _logger.error('Error parsing incoming message', error: e, stackTrace: s);
    }
  }

  /// Sends a message over WebSocket. Checks connection status and logs appropriately.
  void send(dynamic message) {
    if (_status == SocketStatus.connected) {
      _channel?.sink.add(message);
    } else {
      _logger.warning('Attempted to send message while disconnected');
    }
  }

  void _handleDisconnect() {
    _updateStatus(SocketStatus.disconnected);
    _heartbeatTimer?.cancel();
    _logger.warning('Socket Disconnected');
    if (!_manuellyRetry) {
      _scheduleReconnect();
    }
    _logger.info(
      'Manual retry is enabled, not scheduling automatic reconnect.',
    );
  }

  void _scheduleReconnect() {
    _updateStatus(SocketStatus.reconnecting);
    _retryCount++;

    final delay = (_retryCount * _retryCount).clamp(1, _maxRetryDelaySeconds);

    _logger.info(
      'Connection lost. Reconnecting in $delay seconds... '
      '(attempt $_retryCount)',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_lastUrl != null) {
        unawaited(connect(_lastUrl!, useIsolate: _useIsolate));
      }
    });
  }

  void _updateStatus(SocketStatus newStatus) {
    if (_statusController.isClosed) return;
    if (_status != newStatus) {
      _logger.info('Socket Status Changed: $_status -> $newStatus');
    }
    _status = newStatus;
    _statusController.add(_status);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(_inactivityTimeout, _onHeartbeatTimeout);
  }

  void _resetHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
      _heartbeatTimer = Timer(_inactivityTimeout, _onHeartbeatTimeout);
    }
  }

  void _onHeartbeatTimeout() {
    _logger.warning(
      'No data received for ${_inactivityTimeout.inSeconds}s. Assuming connection is dead.',
    );
    // Move to disconnected state immediately to trigger reconnect logic
    // We assume the socket is dead, so we don't wait for 'onDone'
    unawaited(_channel?.sink.close(status.goingAway));
    _handleDisconnect();
  }

  /// Manually closes the connection.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    await _subscription?.cancel();
    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
    _updateStatus(SocketStatus.disconnected);
    _logger.info('Disconnected manually');
  }

  /// Completely closes the service and cleans up resources (Streams are closed).
  void dispose() {
    unawaited(disconnect());

    // Clean up isolate
    unawaited(_isolateSubscription?.cancel());
    _isolateParser?.dispose();
    _isolateParser = null;

    unawaited(_statusController.close());
    unawaited(_messageController.close());
  }

  /// Allows manual retrying of the connection. If already connected or connecting, it will ignore the request.
  Future<void> manualRetry() async {
    if (_status == SocketStatus.connected ||
        _status == SocketStatus.connecting) {
      _logger.warning('Already connected or connecting, manual retry ignored.');
      return;
    }
    _logger.info('Manual retry initiated by user.');
    unawaited(connect(_lastUrl!, useIsolate: _useIsolate));
  }
}
