import 'package:blockly/feature/models/mini_ticker.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coin_ticker.g.dart';

/// Model class representing a coin ticker with various properties related to price and volume.
@JsonSerializable(
  createToJson: false,
  checked: true,
)
class CoinTicker extends Equatable {
  /// Constructor for creating a new `CoinTicker` instance with optional named parameters.
  const CoinTicker({
    this.symbol,
    this.priceChange,
    this.priceChangePercent,
    this.weightedAvgPrice,
    this.prevClosePrice,
    this.lastPrice,
    this.lastQty,
    this.bidPrice,
    this.bidQty,
    this.askPrice,
    this.askQty,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.volume,
    this.quoteVolume,
    this.openTime,
    this.closeTime,
    this.firstId,
    this.lastId,
    this.count,
  });

  /// Factory constructor for creating a new `CoinTicker` instance from a JSON map.
  factory CoinTicker.fromJson(Map<String, dynamic> json) =>
      _$CoinTickerFromJson(json);

  /// Creates a copy of this CoinTicker with updated fields from a MiniTicker.
  /// Also recalculates priceChange and priceChangePercent to maintain consistency.
  CoinTicker copyWithMiniTicker(MiniTicker mini) {
    // Use new values from MiniTicker or fallback to current values
    final newLastPriceStr = mini.c ?? lastPrice;
    final newOpenPriceStr = mini.o ?? openPrice;

    var newPriceChange = priceChange;
    var newPriceChangePercent = priceChangePercent;

    // Recalculate change statistics to prevent UI inconsistency
    // (e.g. Price updates but % change stays old)
    if (newLastPriceStr != null && newOpenPriceStr != null) {
      final last = double.tryParse(newLastPriceStr);
      final open = double.tryParse(newOpenPriceStr);

      if (last != null && open != null && open != 0) {
        final change = last - open;
        final percent = (change / open) * 100;

        // Keep precision reasonable
        newPriceChange = change.toString();
        newPriceChangePercent = percent.toStringAsFixed(3);
      }
    }

    return CoinTicker(
      symbol: symbol,
      priceChange: newPriceChange,
      priceChangePercent: newPriceChangePercent,
      weightedAvgPrice: weightedAvgPrice,
      prevClosePrice: prevClosePrice,
      lastPrice: newLastPriceStr,
      lastQty: lastQty,
      bidPrice: bidPrice,
      bidQty: bidQty,
      askPrice: askPrice,
      askQty: askQty,
      openPrice: newOpenPriceStr,
      highPrice: mini.h ?? highPrice,
      lowPrice: mini.l ?? lowPrice,
      volume: mini.v ?? volume,
      quoteVolume: mini.q ?? quoteVolume,
      openTime: openTime,
      closeTime: closeTime,
      firstId: firstId,
      lastId: lastId,
      count: count,
    );
  }

  /// The symbol of the trading pair, e.g., "BTCUSDT".
  final String? symbol;

  /// The price change over the last 24 hours.
  final String? priceChange;

  /// The percentage price change over the last 24 hours.
  final String? priceChangePercent;

  /// The weighted average price over the last 24 hours.
  final String? weightedAvgPrice;

  /// The previous closing price.
  final String? prevClosePrice;

  /// The last price.
  final String? lastPrice;

  /// The last quantity.
  final String? lastQty;

  /// The highest bid price.
  final String? bidPrice;

  /// The highest bid quantity.
  final String? bidQty;

  /// The lowest ask price.
  final String? askPrice;

  /// The lowest ask quantity.
  final String? askQty;

  /// The opening price.
  final String? openPrice;

  /// The highest price over the last 24 hours.
  final String? highPrice;

  /// The lowest price over the last 24 hours.
  final String? lowPrice;

  /// The total traded base asset volume over the last 24 hours.
  final String? volume;

  /// The total traded quote asset volume over the last 24 hours.
  final String? quoteVolume;

  /// The open time of the ticker data.
  final int? openTime;

  /// The close time of the ticker data.
  final int? closeTime;

  /// The ID of the first trade in the last 24 hours.
  final int? firstId;

  /// The ID of the last trade in the last 24 hours.
  final int? lastId;

  /// The total number of trades in the last 24 hours.
  final int? count;

  @override
  List<Object?> get props => [
    symbol,
    priceChange,
    priceChangePercent,
    weightedAvgPrice,
    prevClosePrice,
    lastPrice,
    lastQty,
    bidPrice,
    bidQty,
    askPrice,
    askQty,
    openPrice,
    highPrice,
    lowPrice,
    volume,
    quoteVolume,
    openTime,
    closeTime,
    firstId,
    lastId,
    count,
  ];
}
