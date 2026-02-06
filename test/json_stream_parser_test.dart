// ignore_for_file: avoid_print, document_ignores

import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/feature/services/json_parser/json_stream_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late JsonStreamParser parser;

  setUp(() {
    parser = JsonStreamParser();
  });

  // Real Binance API Response Example
  const mockJsonString = '''
  [
    {
      "symbol": "BTCUSDT",
      "priceChange": "-120.00000000",
      "priceChangePercent": "-1.250",
      "weightedAvgPrice": "0.00000000",
      "prevClosePrice": "0.00000000",
      "lastPrice": "9500.00000000",
      "lastQty": "0.00000000",
      "bidPrice": "0.00000000",
      "bidQty": "0.00000000",
      "askPrice": "0.00000000",
      "askQty": "0.00000000",
      "openPrice": "0.00000000",
      "highPrice": "0.00000000",
      "lowPrice": "0.00000000",
      "volume": "15000.00000000",
      "quoteVolume": "0.00000000",
      "openTime": 1765689187103,
      "closeTime": 1765775587103,
      "firstId": -1,
      "lastId": -1,
      "count": 0
    },
    {
      "symbol": "ETHUSDT",
      "priceChange": "50.00000000",
      "priceChangePercent": "2.5",
      "lastPrice": "2500.00000000",
      "volume": "50000.00000000",
      "openTime": 1765689187103,
      "closeTime": 1765775587103,
      "count": 100
    },
    {
      "symbol": "BNBUSDT",
      "lastPrice": "300.00",
      "count": 50
    },
    {
      "symbol": "LTCUSDT",
      "lastPrice": "150.00",
      "count": 20
    },
    {
      "symbol": "ADAUSDT",
      "lastPrice": "1.20",
      "count": 1000
    }
  ]
  ''';

  group('JsonStreamParser Tests with CoinTicker', () {
    test('should parse real CoinTicker list correctly', () async {
      final stream = parser.parse<CoinTicker>(
        mockJsonString,
        CoinTicker.fromJson,
      );

      final result = await stream.toList();

      expect(result.length, 1); // Should receive single chunk (small data)
      expect(result.first.length, 5); // 5 CoinTicker mapped?

      final btc = result.first[0];
      expect(btc.symbol, 'BTCUSDT');
      expect(btc.lastPrice, '9500.00000000');

      final eth = result.first[1];
      expect(eth.symbol, 'ETHUSDT');
    });

    test('should working with chunks for CoinTicker', () async {
      final stream = parser.parse<CoinTicker>(
        mockJsonString,
        CoinTicker.fromJson,
        chunkSize: 2, // 2 items per chunk
      );

      final result = await stream.toList();

      // Total 5 items. Chunk size 2.
      // Expected: [2, 2, 1] -> 3 packets.
      expect(result.length, 3);
      expect(result[0].length, 2);
      expect(result[1].length, 2);
      expect(result[2].length, 1);

      expect(result[0].first.symbol, 'BTCUSDT');
      expect(result[2].first.symbol, 'ADAUSDT');
    });

    test(
      'should parse BIG JSON without errors (Stress & Benchmark Test)',
      () async {
        // Manually create a massive JSON String with 300000 items.
        final buffer = StringBuffer();
        buffer.write('[');
        for (var i = 0; i < 300000; i++) {
          buffer.write('''
          {
            "symbol": "COIN$i",
            "priceChange": "0.00",
            "lastPrice": "${100 + i}.00",
            "volume": "1000",
            "count": $i
          }
         ''');
          if (i < 299999) buffer.write(',');
        }
        buffer.write(']');

        print('--- Benchmark Starting ---');
        final stopwatch = Stopwatch()..start();

        final stream = parser.parse<CoinTicker>(
          buffer.toString(),
          CoinTicker.fromJson,
        );

        var totalItems = 0;
        var totalChunks = 0;
        var firstChunkReceived = false;

        await for (final chunk in stream) {
          if (!firstChunkReceived) {
            print(
              'Time to First Chunk (Latency): ${stopwatch.elapsedMilliseconds}ms',
            );
            firstChunkReceived = true;
          }
          totalChunks++;
          totalItems += chunk.length;

          // Verify data correctness within each chunk
          expect(chunk.first, isA<CoinTicker>());
        }

        stopwatch.stop();
        print('Total Parsing Time: ${stopwatch.elapsedMilliseconds}ms');
        print('Total Items: $totalItems');

        expect(totalItems, 300000);
        expect(totalChunks, 3000); // 300000 / 100 = 3000 chunk
      },
    );
  });
}
