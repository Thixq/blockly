import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:equatable/equatable.dart';

/// [MarketState] represents the state of the market data stream.
/// It contains the full list of tickers and a set of symbols that have changed
/// since the last emission.
class MarketState extends Equatable {
  /// Constructor for creating a new `MarketState` instance with required `allTickers`
  const MarketState({
    required this.allTickers,
    this.changedTickers = const {},
  });

  /// The complete list of coin tickers handling the "Single Source of Truth".
  final List<CoinTicker> allTickers;

  /// The set of symbols that were updated in the most recent batch.
  /// UI components can check this set to decide whether to rebuild.
  final Set<String> changedTickers;

  @override
  List<Object?> get props => [allTickers, changedTickers];
}
