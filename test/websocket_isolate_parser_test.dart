import 'dart:async';

import 'package:blockly/feature/services/json_parser/websocket_isolate_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple model for testing
class TestMessage {
  TestMessage({required this.id, required this.content});

  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(
      id: json['id'] as int,
      content: json['content'] as String,
    );
  }
  final int id;
  final String content;

  @override
  String toString() => 'TestMessage(id: $id, content: $content)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestMessage && other.id == id && other.content == content;
  }

  @override
  int get hashCode => id.hashCode ^ content.hashCode;
}

// Top-level parser function for Isolate compatibility
TestMessage parseTestMessage(Map<String, dynamic> json) {
  return TestMessage.fromJson(json);
}

void main() {
  late WebSocketIsolateParser<TestMessage> parser;

  setUp(() async {
    // Initialize with a small chunk size to test chunking easily
    parser = WebSocketIsolateParser<TestMessage>(
      parseTestMessage,
      chunkSize: 2,
    );
    await parser.spawn();
  });

  tearDown(() {
    parser.dispose();
  });

  test('Should parse a single JSON object correctly', () async {
    const jsonStr = '{"id": 1, "content": "Hello World"}';

    // Expect the first event to be a single TestMessage
    final future = expectLater(
      parser.output,
      emits(
        predicate<dynamic>((item) {
          return item is TestMessage &&
              item.id == 1 &&
              item.content == 'Hello World';
        }),
      ),
    );

    parser.parse(jsonStr);
    await future;
  });

  test('Should ignore pong messages', () async {
    const jsonStr = '{"type": "pong"}';

    // We expect no emission. We wait a bit to ensure nothing comes through.
    var received = false;
    final sub = parser.output.listen((_) => received = true);

    parser.parse(jsonStr);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(received, isFalse);
  });

  test('Should parse a JSON list and emit chunks', () async {
    // 5 items, chunkSize is 2.
    // Expected behavior:
    // 1. Chunk of 2 items
    // 2. Chunk of 2 items
    // 3. Chunk of 1 item
    const jsonListStr = '''
    [
      {"id": 1, "content": "One"},
      {"id": 2, "content": "Two"},
      {"id": 3, "content": "Three"},
      {"id": 4, "content": "Four"},
      {"id": 5, "content": "Five"}
    ]
    ''';

    final controller = StreamController<dynamic>();
    parser.output.pipe(controller);

    final events = <dynamic>[];
    controller.stream.listen(events.add);

    parser.parse(jsonListStr);

    // Wait for isolates to process
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(events.length, 3); // 3 chunks

    // Check Chunk 1
    expect(events[0], isA<List<TestMessage>>());
    expect((events[0] as List).length, 2);
    expect((events[0] as List)[0].id, 1);
    expect((events[0] as List)[1].id, 2);

    // Check Chunk 2
    expect(events[1], isA<List<TestMessage>>());
    expect((events[1] as List).length, 2);
    expect((events[1] as List)[0].id, 3);
    expect((events[1] as List)[1].id, 4);

    // Check Chunk 3 (Remaining)
    expect(events[2], isA<List<TestMessage>>());
    expect((events[2] as List).length, 1);
    expect((events[2] as List)[0].id, 5);
  });

  test('Should handle manual scanner string parsing (nested braces)', () async {
    // Testing the scanner logic with tricky spacing and nested objects if any (though flat here)
    const jsonListStr =
        '[ {"id": 1, "content": "A"},   {"id": 2, "content": "B"} ]';

    final outputFuture = parser.output.first;
    parser.parse(jsonListStr);

    final result = await outputFuture;
    expect(result, isA<List<TestMessage>>());
    expect((result as List).length, 2);
    expect(result[0].content, 'A');
    expect(result[1].content, 'B');
  });

  test(
    'Should be robust against malformed JSON item (balanced structure) in list',
    () async {
      // Item 2 has syntax error (missing value) but braces are balanced and strings are closed.
      // Scanner extracts it, but jsonDecode fails.
      const jsonListStr = '''
    [
      {"id": 1, "content": "Valid"},
      {"id": 2, "content": "Valid String", "broken_key": },
      {"id": 3, "content": "Valid 3"}
    ]
    ''';

      final controller = StreamController<dynamic>();
      parser.output.pipe(controller);

      final events = <dynamic>[];
      controller.stream.listen(events.add);

      parser.parse(jsonListStr);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Result should be a list (or chunks) containing items 1 and 3.
      // Item 2 fails decode and is skipped.

      final allItems = events
          .expand((element) => element as List<TestMessage>)
          .toList();

      expect(allItems.length, 2);
      expect(allItems.any((m) => m.id == 1), isTrue);
      expect(allItems.any((m) => m.id == 3), isTrue);
    },
  );
}
