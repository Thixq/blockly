import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

/// A parser that runs in a separate isolate and streams parsed objects in chunks.
/// This prevents UI jank when processing large lists of data.
class JsonStreamParser {
  /// Spawns an isolate to parse the [jsonString] into a list of [T].
  ///
  /// [mapper] must be a static or top-level function that converts a Map to T.
  /// Returns a [Stream] that emits chunks of [T] objects.
  Stream<List<T>> parse<T>(
    String jsonString,
    T Function(Map<String, dynamic> source) mapper, {
    int chunkSize = 100,
  }) {
    final controller = StreamController<List<T>>();
    final receivePort = ReceivePort();

    // Spawn the isolate
    Isolate.spawn<_IsolateInput<T>>(
      _isolateEntry,
      _IsolateInput<T>(
        jsonString,
        receivePort.sendPort,
        chunkSize,
        mapper,
      ),
    ).then((isolate) {
      // Listen for messages from the isolate
      receivePort.listen(
        (dynamic message) {
          if (message is List) {
            // Received a chunk of data
            try {
              // Cast the incoming list to List<T>
              final typedChunk = message.cast<T>();
              controller.add(typedChunk);
            } catch (e, s) {
              controller.addError(
                Exception('Data type mismatch in isolate response'),
                s,
              );
            }
          } else if (message is _IsolateError) {
            // Received an error
            controller.addError(message.error, message.stackTrace);
            receivePort.close();
            isolate.kill();
            controller.close();
          } else if (message == null) {
            // Completion signal
            receivePort.close();
            isolate.kill();
            controller.close();
          }
        },
        onError: (Object error, StackTrace stack) {
          controller.addError(error, stack);
          receivePort.close();
          isolate.kill();
          controller.close();
        },
      );
    });

    return controller.stream;
  }

  /// The entry point for the isolate.
  static void _isolateEntry<T>(_IsolateInput<T> input) {
    try {
      final jsonStr = input.jsonString;
      final currentChunk = <T>[];

      // Manual JSON Scanner variables
      var braceDepth = 0;
      var inString = false;
      var isEscaped = false;
      var startIndex = -1;

      // Iterate through the string characters
      for (var i = 0; i < jsonStr.length; i++) {
        final char = jsonStr[i];

        // Handle Escape Characters inside strings (e.g. "He said \"Hello\"")
        if (isEscaped) {
          isEscaped = false;
          continue;
        }

        if (char == r'\') {
          isEscaped = true;
          continue;
        }

        // Handle String Boundaries
        if (char == '"') {
          inString = !inString;
          continue;
        }

        // If we are inside a string value, ignore braces
        if (inString) continue;

        // Detect Object Start
        if (char == '{') {
          if (braceDepth == 0) {
            startIndex = i; // Mark the start of an object
          }
          braceDepth++;
        }
        // Detect Object End
        else if (char == '}') {
          braceDepth--;

          // If depth returns to 0, we found a complete JSON object {...}
          if (braceDepth == 0 && startIndex != -1) {
            final objectString = jsonStr.substring(startIndex, i + 1);

            try {
              // Parse ONLY this small piece
              final dynamic map = jsonDecode(objectString);
              if (map is Map<String, dynamic>) {
                currentChunk.add(input.mapper(map));
              }
            } catch (e) {
              // Skip malformed objects or continue
              // print('Error parsing chunk: $e');
            }

            // Check Chunk Size
            if (currentChunk.length >= input.chunkSize) {
              input.sendPort.send(List<T>.from(currentChunk));
              currentChunk.clear();
            }

            startIndex = -1; // Reset start index
          }
        }
      }

      // Send any remaining items
      if (currentChunk.isNotEmpty) {
        input.sendPort.send(currentChunk);
      }

      // Signal completion
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
