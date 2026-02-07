import 'dart:async';

import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:flutter/foundation.dart';

/// [HomeViewModel] listens to the MarketManager's stream and manages the state for the HomeView.
class HomeViewModel extends ChangeNotifier {
  /// Constructor with dependency injection
  HomeViewModel(this._manager) {
    _init();
  }
  final MarketManager _manager;
  StreamSubscription<MarketState>? _subscription;

  List<CoinTicker> _displayList = [];
  List<CoinTicker> _allTickers = [];

  Map<String, CoinTicker> _tickerMap = {};

  String _searchText = '';

  /// Updates the search text and filters the displayed list accordingly.
  void updateSearchText(String text) {
    _searchText = text.toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchText.isEmpty) {
      _displayList = List.from(_allTickers);
    } else {
      _displayList = _allTickers
          .where(
            (t) => t.symbol?.toLowerCase().contains(_searchText) ?? false,
          )
          .toList();
    }
  }

  void _init() {
    _subscription = _manager.marketStream.listen((state) {
      _tickerMap = {for (final t in state.allTickers) t.symbol!: t};
      _allTickers = state.allTickers;

      _applyFilter();

      notifyListeners();
    });
    unawaited(_manager.init());
  }

  /// Retrieves the CoinTicker for a specific symbol. Returns null if not found.
  CoinTicker? getTickerBySymbol(String symbol) {
    return _tickerMap[symbol];
  }

  /// Returns the list of CoinTickers to be displayed in the UI, filtered by the current search text.
  List<CoinTicker> get tickerList => _displayList;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
