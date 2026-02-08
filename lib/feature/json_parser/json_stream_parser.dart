// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:blockly/core/logging/custom_logger.dart';

/// A parser that runs in a separate isolate and streams parsed objects in chunks.
/// This prevents UI jank when processing large lists of data.
class JsonStreamParser {
  final _logger = CustomLogger('JsonStreamParser');

  /// Spawns an isolate to parse the [jsonString] into a list of [T].
  ///
  /// [parser] must be a static or top-level function that converts a Map to T.
  /// Returns a [Stream] that emits chunks of [T] objects.
  Stream<List<T>> parse<T>(
    String jsonString,
    T Function(Map<String, dynamic> source) parser, {
    int chunkSize = 100,
  }) {
    _logger.info('Starting parsing. ChunkSize: $chunkSize');
    final controller = StreamController<List<T>>();
    final receivePort = ReceivePort();

    // Spawn the isolate
    unawaited(
      Isolate.spawn<_IsolateInput<T>>(
        _isolateEntry,
        _IsolateInput<T>(
          jsonString,
          receivePort.sendPort,
          chunkSize,
          parser,
        ),
      ).then((isolate) {
        _logger.debug('Isolate spawned.');

        receivePort.listen(
          (dynamic message) {
            if (message is List) {
              try {
                final typedChunk = message.cast<T>();
                _logger.debug('Received chunk of ${typedChunk.length} items');
                controller.add(typedChunk);
              } catch (e, s) {
                _logger.error(
                  'Data type mismatch in isolate response',
                  error: e,
                  stackTrace: s,
                );
                controller.addError(
                  Exception('Data type mismatch in isolate response'),
                  s,
                );
              }
            } else if (message is _IsolateError) {
              _logger.error(
                'Error from isolate',
                error: message.error,
                stackTrace: message.stackTrace,
              );
              controller.addError(message.error, message.stackTrace);
              receivePort.close();
              isolate.kill();
              unawaited(controller.close());
            } else if (message == null) {
              // Completion signal
              _logger.info('Parsing completed successfully.');
              receivePort.close();
              isolate.kill();
              unawaited(controller.close());
            }
          },
          onError: (Object error, StackTrace stack) {
            _logger.error('Stream error', error: error, stackTrace: stack);
            controller.addError(error, stack);
            receivePort.close();
            isolate.kill();
            unawaited(controller.close());
          },
        );
      }),
    );
    return controller.stream;
  }

  // The entry point for the isolate.
  static void _isolateEntry<T>(_IsolateInput<T> input) {
    try {
      final jsonStr = input.jsonString;
      final currentChunk = <T>[];

      var braceDepth = 0;
      var inString = false;
      var isEscaped = false;
      var startIndex = -1;

      for (var i = 0; i < jsonStr.length; i++) {
        final char = jsonStr[i];

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
          if (braceDepth == 0) {
            startIndex = i;
          }
          braceDepth++;
        } else if (char == '}') {
          braceDepth--;

          if (braceDepth == 0 && startIndex != -1) {
            final objectString = jsonStr.substring(startIndex, i + 1);

            try {
              final dynamic map = jsonDecode(objectString);
              if (map is Map<String, dynamic>) {
                currentChunk.add(input.mapper(map));
              }
            } catch (e) {
              // Skip malformed objects or continue
              // print('Error parsing chunk: $e');
            }

            if (currentChunk.length >= input.chunkSize) {
              input.sendPort.send(List<T>.from(currentChunk));
              currentChunk.clear();
            }

            startIndex = -1;
          }
        }
      }

      // Send any remaining items
      if (currentChunk.isNotEmpty) {
        input.sendPort.send(currentChunk);
      }

      input.sendPort.send(null);
    } catch (e, s) {
      input.sendPort.send(_IsolateError(e, s));
    }
  }
}

/// Data class to pass arguments to the isolate.
class _IsolateInput<T> {
  _IsolateInput(this.jsonString, this.sendPort, this.chunkSize, this.mapper);

  final String jsonString;
  final SendPort sendPort;
  final int chunkSize;
  final T Function(Map<String, dynamic> source) mapper;
}

/// Data class to pass errors from the isolate.
class _IsolateError {
  _IsolateError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
