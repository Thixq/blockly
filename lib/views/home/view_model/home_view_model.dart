// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';

import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:flutter/foundation.dart';

/// App States for Home View
enum HomeViewState {
  /// Loading state
  loading,

  /// Loaded state
  loaded,

  /// Error state
  error,
}

/// [HomeViewModel] listens to the MarketManager's stream and manages the state for the HomeView.
class HomeViewModel extends ChangeNotifier {
  /// Constructor with dependency injection
  HomeViewModel(this._manager) {
    unawaited(_init());
  }
  final MarketManager _manager;

  /// Expose the MarketManager instance
  MarketManager get marketManager => _manager;

  StreamSubscription<MarketState>? _subscription;

  List<CoinTicker> _displayList = [];
  List<CoinTicker> _allTickers = [];

  Map<String, CoinTicker> _tickerMap = {};

  String _searchText = 'TRY';
  HomeViewState _state = HomeViewState.loading;
  String? _errorMessage;

  /// Returns the current state of the view
  HomeViewState get state => _state;

  /// Returns the error message if state is [HomeViewState.error]
  String? get errorMessage => _errorMessage;

  /// Returns the current search text
  String get searchText => _searchText;

  /// Updates the search text and filters the displayed list accordingly.
  void updateSearchText(String text) {
    _searchText = text.toUpperCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchText.isEmpty) {
      _displayList = _allTickers;
    } else {
      _displayList = _allTickers
          .where(
            (t) => t.symbol?.toUpperCase().contains(_searchText) ?? false,
          )
          .toList();
    }
  }

  Future<void> _init() async {
    _state = HomeViewState.loading;
    _errorMessage = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = _manager.marketStream.listen((state) {
      _tickerMap = {
        for (final t in state.allTickers)
          if (t.symbol != null) t.symbol!: t,
      };
      _allTickers = state.allTickers;

      if (_state == HomeViewState.loading) {
        _state = HomeViewState.loaded;
      }

      _applyFilter();

      notifyListeners();
    });

    try {
      await _manager.init();
    } catch (e) {
      _state = HomeViewState.error;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
    }
  }

  /// Retries the initialization process
  Future<void> retry() async {
    await _init();
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
