// ignore_for_file: document_ignores

import 'dart:async';

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/const/url_const.dart';
import 'package:blockly/feature/enums/socket_status_enum.dart';
import 'package:blockly/feature/env/env.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/feature/models/mini_ticker.dart';
import 'package:blockly/feature/services/network/dio_service.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';

/// [MarketManager] organizes the data flow between REST API (Snapshot) and WebSocket (Real-time updates).
/// It implements a throttling mechanism to batch UI updates for performance.
class MarketManager {
  /// Constructor
  MarketManager({
    required DioService dioService,
    required WebSocketService<MiniTicker> socketService,
  }) : _dioService = dioService,
       _socketService = socketService;

  final DioService _dioService;
  final WebSocketService<MiniTicker> _socketService;
  final CustomLogger _logger = CustomLogger('MarketManager');

  final Map<String, CoinTicker> _tickerMap = {};

  final Map<String, MiniTicker> _pendingUpdates = {};

  Timer? _throttleTimer;
  static const Duration _throttleDuration = Duration(milliseconds: 1000);

  final StreamController<MarketState> _marketStreamController =
      StreamController<MarketState>.broadcast();

  /// Public stream of the unified Coin list
  Stream<MarketState> get marketStream => _marketStreamController.stream;

  /// Exposes the WebSocket connection status stream.
  Stream<SocketStatus> get socketStatusStream => _socketService.statusStream;

  /// Returns the current cached ticker for a given symbol, or null if not found.
  CoinTicker? getTicker(String symbol) => _tickerMap[symbol];

  /// Returns a stream for a specific coin's updates derived from the main market stream.
  Stream<CoinTicker> getCoinStream(String symbol) {
    return marketStream
        .where(
          (state) =>
              state.changedTickers.isEmpty ||
              state.changedTickers.contains(symbol),
        )
        .map((_) => _tickerMap[symbol])
        .where((t) => t != null)
        .cast<CoinTicker>()
        .distinct();
  }

  /// Initializes the manager by fetching the initial snapshot and setting up the WebSocket connection.
  Future<void> init() async {
    _logger.info('Initializing MarketManager...');
    await _fetchInitialSnapshot();
    _setupWebSocket();
    _startThrottleTimer();
  }

  Future<void> _fetchInitialSnapshot() async {
    try {
      _logger.info('Fetching snapshot from ${UrlConst.ticker24hr}');

      final stream = _dioService.requestStreaming<CoinTicker>(
        url: UrlConst.ticker24hr,
        fromJson: CoinTicker.fromJson,
        chunkSize: 500,
      );

      await for (final chunk in stream) {
        for (final ticker in chunk) {
          if (ticker.symbol != null) {
            _tickerMap[ticker.symbol!] = ticker;
          }
        }
        _emitState();
      }

      _logger.info('Snapshot loaded. Total coins: ${_tickerMap.length}');
    } catch (e, s) {
      _logger.error('Failed to fetch snapshot', error: e, stackTrace: s);
      rethrow;
    }
  }

  void _setupWebSocket() {
    _socketService.messages.listen(
      (miniTicker) {
        if (miniTicker.s != null) {
          _pendingUpdates[miniTicker.s!] = miniTicker;
        }
      },
      onError: (Object error) {
        _logger.error('WebSocket stream error', error: error);
      },
    );

    unawaited(
      _socketService.connect(
        Env.binancePriceSocketUrl + UrlConst.miniTicker,
        useIsolate: true,
      ),
    );
  }

  void _startThrottleTimer() {
    _throttleTimer?.cancel();
    _throttleTimer = Timer.periodic(_throttleDuration, (_) {
      _processPendingUpdates();
    });
  }

  void _processPendingUpdates() {
    if (_pendingUpdates.isEmpty) return;

    final changedSymbols = <String>{};

    for (final entry in _pendingUpdates.entries) {
      final symbol = entry.key;
      final miniTicker = entry.value;

      final currentTicker = _tickerMap[symbol];
      if (currentTicker != null) {
        _tickerMap[symbol] = currentTicker.copyWithMiniTicker(miniTicker);
        changedSymbols.add(symbol);
      }
    }

    _pendingUpdates.clear();

    if (changedSymbols.isNotEmpty) {
      _emitState(changedTickers: changedSymbols);
    }
  }

  void _emitState({Set<String> changedTickers = const {}}) {
    if (!_marketStreamController.isClosed) {
      _marketStreamController.add(
        MarketState(
          allTickers: _tickerMap.values.toList(),
          changedTickers: changedTickers,
        ),
      );
    }
  }

  /// Disposes resources when the manager is no longer needed.
  void dispose() {
    _throttleTimer?.cancel();
    _socketService.dispose();
    unawaited(_marketStreamController.close());
    _logger.info('MarketManager disposed');
  }

  /// Reconnects the WebSocket after a manual disconnect/retry.
  Future<void> reconnect() async {
    _logger.info('Manual reconnect requested');
    unawaited(_socketService.manualRetry());
  }
}
