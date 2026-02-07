// ignore_for_file: avoid_catches_without_on_clauses, document_ignores, use_setters_to_change_properties

import 'dart:async';
import 'dart:convert';

import 'dart:isolate'; // Isolate için gerekli

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/enums/socket_status_enum.dart';
import 'package:meta/meta.dart'; // For @visibleForTesting
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Channel creator function type (For testability)
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

/// Function type for parsing incoming data into a model
typedef Parser<T> = T Function(Map<String, dynamic> json);

/// WebSocketService is a generic service class designed to manage WebSocket connections.
/// [T] represents the data model that will be received over the socket.
class WebSocketService<T> {
  /// Factory Constructor: Returns an existing service for type T if available,
  /// otherwise creates a new one, adds it to the pool, and returns it.
  factory WebSocketService() {
    return _instances.putIfAbsent(T, WebSocketService<T>._internal)
        as WebSocketService<T>;
  }

  WebSocketService._internal();

  static final Map<Type, WebSocketService<dynamic>> _instances = {};

  /// Instance reset method for testing purposes (Used in tests)
  @visibleForTesting
  static void resetInstance() {
    for (final instance in _instances.values) {
      // Trigger disconnect
      unawaited(instance.disconnect());
    }
    _instances.clear();
  }

  Parser<T>? _parser;

  /// Method to set the parser externally.
  /// Must be called before connecting.
  void setParser(Parser<T> parser) {
    _parser = parser;
  }

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

  Timer? _heartbeatTimer;

  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  /// Stream where you can listen to the connection status.
  Stream<SocketStatus> get statusStream => _statusController.stream;

  final StreamController<T> _messageController =
      StreamController<T>.broadcast();

  /// Main stream where incoming messages can be listened to
  Stream<T> get messages => _messageController.stream;

  StreamSubscription<dynamic>? _subscription;

  /// Connects to the WebSocket server. Manages connection status and processes messages.
  Future<void> connect(String url) async {
    _lastUrl = url;

    if (_parser == null) {
      _logger.error('Parser not set! Call setParser() before connecting.');
      throw StateError(
        'Parser not set. You must call setParser() before connecting.',
      );
    }

    if (_status == SocketStatus.connected ||
        _status == SocketStatus.connecting) {
      _logger.warning('Already connected or connecting to $url');
      return;
    }

    _updateStatus(SocketStatus.connecting);
    _logger.info('Connecting to $url');

    try {
      if (channelFactory != null) {
        _channel = channelFactory!(Uri.parse(url));
      } else {
        _channel = WebSocketChannel.connect(Uri.parse(url));
      }

      await _channel!.ready
          .then((_) {
            _onConnected();
          })
          .catchError((Object? e) {
            _logger.error('Failed to establish connection', error: e);
            _handleDisconnect();
          });

      await _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _handleDisconnect,
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
  }

  Future<void> _onMessageReceived(dynamic message) async {
    if (_messageController.isClosed) return;

    try {
      String payload;
      if (message is String) {
        payload = message;
      } else if (message is List<int>) {
        payload = utf8.decode(message);
      } else {
        return;
      }
      final jsonMap = await Isolate.run(() {
        final decoded = jsonDecode(payload);
        return decoded;
      });

      if (_messageController.isClosed) return;

      if (jsonMap is Map && jsonMap['type'] == 'pong') {
        return;
      }

      if (_parser != null) {
        if (jsonMap is List) {
          // Gelen veri bir liste ise (örn: !miniTicker@arr), her elemanı tek tek işle
          for (final item in jsonMap) {
            if (item is Map) {
              final data = _parser!(Map<String, dynamic>.from(item));
              _messageController.add(data);
            }
          }
        } else if (jsonMap is Map) {
          // Gelen veri tekil obje ise
          final data = _parser!(Map<String, dynamic>.from(jsonMap));
          _messageController.add(data);
        }
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
    _heartbeatTimer?.cancel();
    _updateStatus(SocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _updateStatus(SocketStatus.reconnecting);
    _retryCount++;

    final delay = (_retryCount * _retryCount).clamp(1, _maxRetryDelaySeconds);

    _logger.info('Reconnecting in $delay seconds...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_lastUrl != null) {
        unawaited(connect(_lastUrl!));
      }
    });
  }

  void _updateStatus(SocketStatus newStatus) {
    if (_statusController.isClosed) return;
    _status = newStatus;
    _statusController.add(_status);
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
    // Remove this type from pool
    _instances.remove(T);
    unawaited(disconnect());
    unawaited(_statusController.close());
    unawaited(_messageController.close());
  }
}
