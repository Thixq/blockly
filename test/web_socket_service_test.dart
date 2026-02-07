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

// Mock için: WebSocketChannel ve WebSocketSink
// Not: Sink generic olduğu için StreamSink<dynamic> olarak mockluyoruz
@GenerateMocks([WebSocketChannel, WebSocketSink])
void main() {
  late MockWebSocketChannel mockChannel;
  late MockWebSocketSink mockSink;
  late StreamController<dynamic> channelStreamController;

  setUp(() {
    // 0. Global state temizliği (Managed Pool)
    WebSocketService.resetInstance();

    // 1. Mock hazırlıkları
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();
    channelStreamController = StreamController<dynamic>.broadcast();

    // Mock Kanal davranışları
    when(mockChannel.stream).thenAnswer((_) => channelStreamController.stream);
    when(mockChannel.sink).thenReturn(mockSink);
    when(mockChannel.ready).thenAnswer((_) => Future.value());

    // Kapatma davranışı
    when(mockSink.close(any, any)).thenAnswer((_) async {
      return null;
    });
    when(mockSink.add(any)).thenReturn(null);
  });

  tearDown(() {
    unawaited(channelStreamController.close());
    WebSocketService.resetInstance();
  });

  group('Managed Pool (Multiton) Tests', () {
    test('Should return the same instance for the same Type T', () {
      final s1 = WebSocketService<TestModel>();
      final s2 = WebSocketService<TestModel>();

      expect(s1, equals(s2)); // Referans eşitliği (Aynı obje mi?)
    });

    test('Should return different instances for different Types', () {
      final s1 = WebSocketService<TestModel>();
      final s2 = WebSocketService<AnotherTestModel>();

      expect(s1, isNot(equals(s2)));
    });

    test('Should clean up pool on dispose', () {
      final service = WebSocketService<TestModel>()
        ..dispose(); // dispose() havuzdan silmeli

      final newService = WebSocketService<TestModel>(); // Yeni instance gelmeli
      expect(service, isNot(equals(newService)));
    });
  });

  group('WebSocketService Standard Tests', () {
    late WebSocketService<dynamic> webSocketService;

    setUp(() {
      webSocketService = WebSocketService<dynamic>()
        ..setParser((json) => json)
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

      // Mesajın UI stream'ine düştüğünü test et
      final messageExpectation = expectLater(
        webSocketService.messages,
        emits(
          predicate<dynamic>((data) {
            return data is Map && data['price'] == 100;
          }),
        ),
      );

      // Mock kanaldan mesaj gönder
      channelStreamController.add(testJson);

      await messageExpectation;
    });

    test('Should filter PONG messages', () async {
      await webSocketService.connect('wss://test.com');

      var messageReceived = false;
      final sub = webSocketService.messages.listen((_) {
        messageReceived = true;
      });

      // Pong mesajı gönder
      channelStreamController.add('{"type": "pong"}');

      // Bekle ve kontrol et (Isolate asenkron olduğu için biraz bekleme payı)
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(messageReceived, isFalse);

      // Normal mesaj gönderip çalıştığını teyit et
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
      webSocketService = WebSocketService<dynamic>()
        ..setParser((json) => json)
        ..channelFactory = (uri) => mockChannel;
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

      // 1000 adet mesajı arka arkaya bas
      // Bu, isolate'in kuyruklama ve işleme performansını test eder.
      for (var i = 0; i < messageCount; i++) {
        channelStreamController.add('{"id": $i, "data": "stress_test"}');
      }

      // Bitmesini bekle (Timeout koyarak sonsuz döngüyü engelle)
      await completer.future.timeout(
        const Duration(seconds: 10),
      ); // Isolate olduğu için biraz süre tanıyoruz
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

      // Hatalı JSON gönder
      channelStreamController
        ..add('{bad_json: true') // Tırnak yok
        // Hemen ardından düzgün JSON gönder
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

      // Hata olsa bile servis çalışmaya devam etmeli ve sıradaki doğru mesajı işlemeli
      expect(crashed, isFalse);
    });
  });

  group('Generics Support', () {
    test('Should parse into Type T', () async {
      // Setup typed service
      final typedService = WebSocketService<TestModel>()
        ..setParser(TestModel.fromJson)
        ..channelFactory = (uri) => mockChannel;

      // Re-configure connection stubs manually just in case
      // Note: mockChannel is shared but StreamController is broadcast, so it's fine.

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

class AnotherTestModel {}
