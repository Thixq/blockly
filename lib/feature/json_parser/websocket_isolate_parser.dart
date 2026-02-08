// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:blockly/core/logging/custom_logger.dart';

/// Function type for parsing Map to T
typedef Parser<T> = T Function(Map<String, dynamic> json);

/// A class that manages a long-lived isolate for parsing WebSocket messages.
class WebSocketIsolateParser<T> {
  /// Constructor that takes a parser function to convert JSON maps to the desired type.
  WebSocketIsolateParser(this._parser, {this.chunkSize = 100});

  final Parser<T> _parser;

  /// The number of items to parse before sending a chunk back to the main isolate.
  final int chunkSize;
  final CustomLogger _logger = CustomLogger('WebSocketIsolateParser');

  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _receivePort;
  StreamController<dynamic>? _outputController;

  /// Stream of parsed objects coming from the isolate.
  Stream<dynamic> get output =>
      _outputController?.stream ?? const Stream.empty();

  /// Spawns the background isolate
  Future<void> spawn() async {
    _logger.info('Spawning WebSocket parser isolate...');
    _outputController = StreamController<dynamic>.broadcast();
    _receivePort = ReceivePort();

    final readyCompleter = Completer<void>();

    // Listen for messages from the isolate (Handshake & Data)
    _receivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        if (!readyCompleter.isCompleted) readyCompleter.complete();
      } else if (message is _IsolateError) {
        _logger.error('Error in isolate', error: message.error);
        _outputController?.addError(message.error);
      } else {
        _outputController?.add(message);
      }
    });

    try {
      _isolate = await Isolate.spawn<_IsolateInit<T>>(
        _entryPoint,
        _IsolateInit<T>(_receivePort!.sendPort, _parser, chunkSize),
        onError: _receivePort!.sendPort,
      );

      await readyCompleter.future;
      _logger.info('WebSocket parser isolate is ready.');
    } catch (e, s) {
      _logger.error('Failed to spawn isolate', error: e, stackTrace: s);
      dispose();
      rethrow;
    }
  }

  /// Sends a raw JSON string to the isolate for parsing
  void parse(String jsonString) {
    if (_isolateSendPort == null) {
      _logger.warning('Isolate not ready. Dropping message.');
      return;
    }
    _isolateSendPort!.send(jsonString);
  }

  /// Disposes the isolate and streams
  void dispose() {
    _receivePort?.close();
    unawaited(_outputController?.close());
    _isolate?.kill();
    _isolate = null;
    _isolateSendPort = null;
    _logger.info('WebSocket parser isolate disposed.');
  }

  /// The entry point for the isolate
  static void _entryPoint<T>(_IsolateInit<T> init) {
    final receivePort = ReceivePort();
    init.mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is String) {
        try {
          if (message.trimLeft().startsWith('{')) {
            final dynamic json = jsonDecode(message);
            if (json is Map) {
              if (json['type'] == 'pong') return; // Ignore pong
              final item = init.parser(Map<String, dynamic>.from(json));
              init.mainSendPort.send(item);
            }
            return;
          }

          if (message.trimLeft().startsWith('[')) {
            final currentChunk = <T>[];
            var braceDepth = 0;
            var inString = false;
            var isEscaped = false;
            var startIndex = -1;

            for (var i = 0; i < message.length; i++) {
              final char = message[i];

              if (isEscaped) {
                isEscaped = false;
                continue;
              }

              if (char == r'\') {
                isEscaped = true;
                continue;
              }

              if (char == '"') {
                inString = !inString;
                continue;
              }

              if (inString) continue;

              if (char == '{') {
                if (braceDepth == 0) startIndex = i;
                braceDepth++;
              } else if (char == '}') {
                braceDepth--;

                if (braceDepth == 0 && startIndex != -1) {
                  final objectString = message.substring(startIndex, i + 1);
                  try {
                    final dynamic map = jsonDecode(objectString);
                    if (map is Map<String, dynamic>) {
                      currentChunk.add(init.parser(map));
                    }
                  } catch (e) {
                    // Skip malformed items
                  }

                  if (currentChunk.length >= init.chunkSize) {
                    init.mainSendPort.send(List<T>.from(currentChunk));
                    currentChunk.clear();
                  }
                  startIndex = -1;
                }
              }
            }

            if (currentChunk.isNotEmpty) {
              init.mainSendPort.send(currentChunk);
            }
            return;
          }

          final dynamic json = jsonDecode(message);
          if (json is List) {
            final currentChunk = <T>[];
            for (final item in json) {
              if (item is Map) {
                try {
                  currentChunk.add(
                    init.parser(Map<String, dynamic>.from(item)),
                  );
                } catch (_) {}
                if (currentChunk.length >= init.chunkSize) {
                  init.mainSendPort.send(List<T>.from(currentChunk));
                  currentChunk.clear();
                }
              }
            }
            if (currentChunk.isNotEmpty) init.mainSendPort.send(currentChunk);
          }
        } catch (e) {
          init.mainSendPort.send(_IsolateError(e));
        }
      }
    });
  }
}

class _IsolateInit<T> {
  _IsolateInit(this.mainSendPort, this.parser, this.chunkSize);
  final SendPort mainSendPort;
  final Parser<T> parser;
  final int chunkSize;
}

class _IsolateError {
  _IsolateError(this.error);
  final Object error;
}
