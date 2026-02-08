import 'dart:async';

import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:flutter/material.dart';

/// [CoinDetailViewModel] listens to the MarketManager's stream for a specific coin symbol and manages the state for the CoinDetailView.
class CoinDetailViewModel extends ChangeNotifier {
  /// Constructor with dependency injection
  CoinDetailViewModel(this._marketManager);

  final MarketManager _marketManager;
  String? _symbol;

  /// Returns the current symbol being observed, or an empty string if none is set.
  String get symbol => _symbol ?? '';

  CoinTicker? _ticker;

  /// Returns the current ticker data for the observed symbol, or null if not available.
  CoinTicker? get ticker => _ticker;

  StreamSubscription<CoinTicker>? _subscription;

  /// Sets the symbol to observe and initializes the stream subscription for that symbol.
  void setSymbol(String symbol) {
    if (_symbol == symbol) return;
    _symbol = symbol;
    _init();
  }

  void _init() {
    if (_symbol == null) return;
    final symbol = _symbol!;

    // Başlangıç verisini al
    _ticker = _marketManager.getTicker(symbol);

    // Stream dinlemeyi başlat
    unawaited(_subscription?.cancel());
    _subscription = _marketManager.getCoinStream(symbol).listen((newTicker) {
      _ticker = newTicker;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
