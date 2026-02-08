// ignore_for_file: avoid_print, document_ignores, avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';

import 'package:blockly/feature/enums/socket_status_enum.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'web_socket_service_test.mocks.dart';

@GenerateMocks([WebSocketChannel, WebSocketSink])
void main() {
  late MockWebSocketChannel mockChannel;
  late MockWebSocketSink mockSink;
  late StreamController<dynamic> channelStreamController;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();
    channelStreamController = StreamController<dynamic>.broadcast();

    when(mockChannel.stream).thenAnswer((_) => channelStreamController.stream);
    when(mockChannel.sink).thenReturn(mockSink);
    when(mockChannel.ready).thenAnswer((_) => Future.value());

    when(mockSink.close(any, any)).thenAnswer((_) async {
      return null;
    });
    when(mockSink.add(any)).thenReturn(null);
  });

  tearDown(() {
    unawaited(channelStreamController.close());
  });

  group('WebSocketService Standard Tests', () {
    late WebSocketService<dynamic> webSocketService;

    setUp(() {
      webSocketService = WebSocketService<dynamic>(parser: (json) => json)
        ..channelFactory = (uri) => mockChannel;
    });

    test('connect establishes connection and updates status', () async {
      final statusExpectation = expectLater(
        webSocketService.statusStream,
        emitsInOrder([
          SocketStatus.connecting,
          SocketStatus.connected,
        ]),
      );

      await webSocketService.connect('wss://test.com');

      await statusExpectation;
      verify(mockChannel.ready).called(1);
    });

    test('Should handle incoming messages correctly', () async {
      await webSocketService.connect('wss://test.com');

      const testJson = '{"price": 100, "symbol": "BTC"}';

      // Test that message falls into UI stream
      final messageExpectation = expectLater(
        webSocketService.messages,
        emits(
          predicate<dynamic>((data) {
            return data is Map && data['price'] == 100;
          }),
        ),
      );

      channelStreamController.add(testJson);

      await messageExpectation;
    });

    test('Should filter PONG messages', () async {
      await webSocketService.connect('wss://test.com');

      var messageReceived = false;
      final sub = webSocketService.messages.listen((_) {
        messageReceived = true;
      });

      channelStreamController.add('{"type": "pong"}');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(messageReceived, isFalse);

      channelStreamController.add('{"type": "data"}');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(messageReceived, isTrue);

      await sub.cancel();
    });

    test('Should decode byte messages (List<int>) correctly', () async {
      await webSocketService.connect('wss://test.com');

      const jsonStr = '{"isBytes": true}';
      final bytes = utf8.encode(jsonStr);

      final messageExpectation = expectLater(
        webSocketService.messages,
        emits(predicate((data) => data is Map && data['isBytes'] == true)),
      );

      channelStreamController.add(bytes);

      await messageExpectation;
    });
  });

  group('WebSocketService Performance & Stress Tests', () {
    late WebSocketService<dynamic> webSocketService;

    setUp(() {
      webSocketService = WebSocketService<dynamic>(
        parser: (json) => json,
      )..channelFactory = (uri) => mockChannel;
    });

    test('High Volume Message Processing (Stress Test)', () async {
      await webSocketService.connect('wss://stress.test');

      const messageCount = 1000;
      final stopwatch = Stopwatch()..start();

      var receivedCount = 0;
      final completer = Completer<void>();

      final sub = webSocketService.messages.listen((data) {
        receivedCount++;
        if (receivedCount >= messageCount) {
          completer.complete();
        }
      });

      for (var i = 0; i < messageCount; i++) {
        channelStreamController.add('{"id": $i, "data": "stress_test"}');
      }

      await completer.future.timeout(
        const Duration(seconds: 10),
      );
      stopwatch.stop();

      await sub.cancel();

      print(
        'Processed $messageCount messages in ${stopwatch.elapsedMilliseconds}ms via Isolate',
      );

      expect(receivedCount, messageCount);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('Parsing Error Resilience', () async {
      await webSocketService.connect('wss://error.test');

      var crashed = false;

      channelStreamController
        ..add('{bad_json: true')
        ..add('{"good_json": true}');

      final messageExpectation = expectLater(
        webSocketService.messages,
        emits(predicate((data) => data is Map && data['good_json'] == true)),
      );

      try {
        await messageExpectation;
      } catch (e) {
        crashed = true;
      }
      expect(crashed, isFalse);
    });
  });

  group('Generics Support', () {
    test('Should parse into Type T', () async {
      final typedService = WebSocketService<TestModel>(
        parser: TestModel.fromJson,
      )..channelFactory = (uri) => mockChannel;

      await typedService.connect('wss://typed.com');

      final expectation = expectLater(
        typedService.messages,
        emits(predicate<TestModel>((m) => m.id == 123)),
      );

      channelStreamController.add('{"id": 123}');

      await expectation;
      typedService.dispose();
    });
  });
}

class TestModel {
  TestModel(this.id);
  factory TestModel.fromJson(Map<String, dynamic> json) =>
      TestModel(json['id'] as int);
  final int id;
}
