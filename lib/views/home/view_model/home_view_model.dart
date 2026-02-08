// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';

import 'package:blockly/feature/enums/socket_status_enum.dart';
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

  /// Disconnected state (socket connection lost)
  disconnected,

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
  StreamSubscription<SocketStatus>? _socketStatusSubscription;

  List<CoinTicker> _displayList = [];
  List<CoinTicker> _allTickers = [];

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
    await _socketStatusSubscription?.cancel();

    // Listen to socket disconnections
    _socketStatusSubscription = _manager.socketStatusStream.listen((status) {
      if (status == SocketStatus.disconnected &&
          _state == HomeViewState.loaded) {
        _state = HomeViewState.disconnected;
        _errorMessage = 'Connection lost. Please check your internet.';
        notifyListeners();
      } else if (status == SocketStatus.connected &&
          _state == HomeViewState.disconnected) {
        _state = HomeViewState.loaded;
        _errorMessage = null;
        notifyListeners();
      }
    });

    _subscription = _manager.marketStream.listen((state) {
      final isSnapshotEmission = state.changedTickers.isEmpty;

      if (isSnapshotEmission) {
        _allTickers = state.allTickers;
        _applyFilter();
      }

      final stateChanged = _state == HomeViewState.loading;
      if (stateChanged) {
        _state = HomeViewState.loaded;
      }

      // Only notify UI when list structure changed or view state changed.
      // Price-only updates are handled by SmartCoinRow via MarketManager.getTicker().
      if (isSnapshotEmission || stateChanged) {
        notifyListeners();
      }
    });

    try {
      await _manager.init();
    } catch (e) {
      _state = HomeViewState.error;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
    }
  }

  /// Retries the initialization or reconnection process.
  Future<void> retry() async {
    if (_state == HomeViewState.disconnected) {
      _state = HomeViewState.loaded;
      _errorMessage = null;
      notifyListeners();
      await _manager.reconnect();
    } else {
      await _init();
    }
  }

  /// Retrieves the CoinTicker for a specific symbol. Returns null if not found.
  /// Delegates to [MarketManager.getTicker] to avoid duplicate map storage.
  CoinTicker? getTickerBySymbol(String symbol) {
    return _manager.getTicker(symbol);
  }

  /// Returns the list of CoinTickers to be displayed in the UI, filtered by the current search text.
  List<CoinTicker> get tickerList => _displayList;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_socketStatusSubscription?.cancel());
    super.dispose();
  }
}
