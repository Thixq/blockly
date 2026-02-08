import 'dart:async';

import 'package:blockly/feature/const/url_const.dart';
import 'package:blockly/feature/env/env.dart';
import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/feature/models/mini_ticker.dart';
import 'package:blockly/feature/services/network/dio_service.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'market_manager_test.mocks.dart';

@GenerateMocks(
  [DioService],
  customMocks: [
    MockSpec<WebSocketService<MiniTicker>>(as: #MockTickerWebSocketService),
  ],
)
void main() {
  late MarketManager manager;
  late MockDioService mockDioService;
  late MockTickerWebSocketService mockSocketService;
  late StreamController<MiniTicker> socketStreamController;

  const btcTicker = CoinTicker(
    symbol: 'BTCUSDT',
    lastPrice: '50000.00',
    openPrice: '48000.00',
    volume: '1000',
  );

  const ethTicker = CoinTicker(
    symbol: 'ETHUSDT',
    lastPrice: '3000.00',
    openPrice: '2900.00',
    volume: '5000',
  );

  const miniUpdate = MiniTicker(
    s: 'BTCUSDT',
    c: '51000.00',
    o: '48000.00',
    h: '52000.00',
    l: '47000.00',
    v: '1200',
    q: '60000000',
    e: 123456789,
  );

  setUp(() {
    mockDioService = MockDioService();
    mockSocketService = MockTickerWebSocketService();
    socketStreamController = StreamController<MiniTicker>.broadcast();

    when(
      mockSocketService.messages,
    ).thenAnswer((_) => socketStreamController.stream);
    when(
      mockSocketService.connect(any, useIsolate: anyNamed('useIsolate')),
    ).thenAnswer((_) async {});
    when(mockSocketService.setParser(any)).thenReturn(null);
    when(mockSocketService.dispose()).thenReturn(null);

    manager = MarketManager(
      dioService: mockDioService,
      socketService: mockSocketService,
    );
  });

  tearDown(() {
    unawaited(socketStreamController.close());
    manager.dispose();
  });

  group('MarketManager Tests', () {
    test('init() should fetch snapshot and connect to socket', () async {
      final snapshotStream = Stream.fromIterable([
        [btcTicker, ethTicker],
      ]);

      when(
        mockDioService.requestStreaming<CoinTicker>(
          url: anyNamed('url'),
          fromJson: anyNamed('fromJson'),
          chunkSize: anyNamed('chunkSize'),
        ),
      ).thenAnswer((_) => snapshotStream);

      final expectation = expectLater(
        manager.marketStream,
        emits(isA<MarketState>()),
      );

      await manager.init();

      await expectation;

      verify(
        mockDioService.requestStreaming<CoinTicker>(
          url: UrlConst.ticker24hr,
          fromJson: anyNamed('fromJson'),
          chunkSize: 500,
        ),
      ).called(1);

      verify(
        mockSocketService.connect(
          Env.binancePriceSocketUrl + UrlConst.miniTicker,
          useIsolate: true,
        ),
      ).called(1);
    });

    test('Should buffer and throttle socket updates', () async {
      final snapshotStream = Stream.fromIterable([
        [btcTicker],
      ]);

      when(
        mockDioService.requestStreaming<CoinTicker>(
          url: anyNamed('url'),
          fromJson: anyNamed('fromJson'),
          chunkSize: anyNamed('chunkSize'),
        ),
      ).thenAnswer((_) => snapshotStream);

      await manager.init();

      final emissions = <MarketState>[];
      final subscription = manager.marketStream.listen(emissions.add);

      socketStreamController.add(miniUpdate);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        emissions.length,
        lessThanOrEqualTo(1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 800));

      final latestList = emissions.last.allTickers;
      final updatedBtc = latestList.firstWhere((t) => t.symbol == 'BTCUSDT');

      expect(updatedBtc.lastPrice, '51000.00');
      expect(updatedBtc.volume, '1200');

      await subscription.cancel();
    });

    test('Should batch updates for multiple coins simultaneously', () async {
      final snapshotStream = Stream.fromIterable([
        [btcTicker, ethTicker],
      ]);

      when(
        mockDioService.requestStreaming<CoinTicker>(
          url: anyNamed('url'),
          fromJson: anyNamed('fromJson'),
          chunkSize: anyNamed('chunkSize'),
        ),
      ).thenAnswer((_) => snapshotStream);

      await manager.init();

      final emissions = <MarketState>[];
      final subscription = manager.marketStream.listen(emissions.add);

      const btcUpdate = miniUpdate;
      const ethUpdate = MiniTicker(
        s: 'ETHUSDT',
        c: '3100.00',
        o: '2900.00',
        h: '3200.00',
        l: '2800.00',
        v: '5000',
        q: '15000000',
        e: 123456790,
      );

      socketStreamController
        ..add(btcUpdate)
        ..add(ethUpdate);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      final latestList = emissions.last.allTickers;
      final updatedBtc = latestList.firstWhere((t) => t.symbol == 'BTCUSDT');
      final updatedEth = latestList.firstWhere((t) => t.symbol == 'ETHUSDT');

      expect(updatedBtc.lastPrice, '51000.00');
      expect(updatedEth.lastPrice, '3100.00');

      await subscription.cancel();
    });

    test('Should ignore updates for unknown coins not in snapshot', () async {
      final snapshotStream = Stream.fromIterable([
        [btcTicker],
      ]);

      when(
        mockDioService.requestStreaming<CoinTicker>(
          url: anyNamed('url'),
          fromJson: anyNamed('fromJson'),
          chunkSize: anyNamed('chunkSize'),
        ),
      ).thenAnswer((_) => snapshotStream);

      await manager.init();

      final emissions = <MarketState>[];
      final subscription = manager.marketStream.listen(emissions.add);

      const dogeUpdate = MiniTicker(
        s: 'DOGEUSDT',
        c: '0.25',
        o: '0.20',
        h: '0.26',
        l: '0.19',
        v: '10000',
        q: '2500',
        e: 123456799,
      );
      socketStreamController.add(dogeUpdate);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should NOT have emitted a new state solely for the unknown coin.
      // If emissions occurred (e.g. initial snapshot), ensure DOGE is not present.
      if (emissions.isNotEmpty) {
        final lastList = emissions.last.allTickers;
        expect(lastList.any((t) => t.symbol == 'DOGEUSDT'), false);
      }

      await subscription.cancel();
    });

    test(
      'Stress Test: Should handle high-frequency updates for single coin',
      () async {
        final snapshotStream = Stream.fromIterable([
          [btcTicker],
        ]);

        when(
          mockDioService.requestStreaming<CoinTicker>(
            url: anyNamed('url'),
            fromJson: anyNamed('fromJson'),
            chunkSize: anyNamed('chunkSize'),
          ),
        ).thenAnswer((_) => snapshotStream);

        await manager.init();

        final emissions = <MarketState>[];
        final subscription = manager.marketStream.listen(emissions.add);

        //Send 50 updates in a loop (simulating rapid socket burst)
        for (var i = 0; i < 50; i++) {
          socketStreamController.add(
            MiniTicker(
              s: 'BTCUSDT',
              c: '${50000 + i}',
              e: 1000 + i,
              o: '48000.00',
              h: '52000.00',
              l: '47000.00',
              v: '1200',
              q: '60000000',
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 600));

        final latestList = emissions.last.allTickers;
        final updatedBtc = latestList.firstWhere((t) => t.symbol == 'BTCUSDT');

        expect(updatedBtc.lastPrice, '50049');

        await subscription.cancel();
      },
    );
  });
}
