import 'dart:async';

import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._manager) {
    _init();
  }
  final MarketManager _manager;
  StreamSubscription<MarketState>? _subscription;

  // 1. Tüm liste (Sıralama ve Listeleme için)
  List<CoinTicker> _displayList = [];

  // 2. Hızlı Erişim Haritası (Smart Row'ların veriyi O(1) ile bulması için)
  Map<String, CoinTicker> _tickerMap = {};

  void _init() {
    _subscription = _manager.marketStream.listen((state) {
      // Gelen listeyi hızlı erişim için Map'e çeviriyoruz
      // Bu işlem çok hızlıdır (3000 elemanda bile ms sürer)
      _tickerMap = {for (final t in state.allTickers) t.symbol!: t};

      // Eğer arama/filtreleme yoksa listeyi direkt güncelle
      // (Burada arama mantığı varsa filter işlemi yapılır)
      _displayList = state.allTickers;

      // UI'a haber ver
      notifyListeners();
    });

    _manager.init();
  }

  /// UI'daki her bir satırın kendi verisini çekmesi için metot
  CoinTicker? getTickerBySymbol(String symbol) {
    return _tickerMap[symbol];
  }

  /// ListView'in kaç eleman çizeceğini bilmesi için
  List<CoinTicker> get tickerList => _displayList;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
