// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/const/url_const.dart';
import 'package:blockly/feature/managers/market_state.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/feature/models/mini_ticker.dart';
import 'package:blockly/feature/services/network/dio_service.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';

/// [MarketManager] organizes the data flow between REST API (Snapshot) and WebSocket (Real-time updates).
/// It implements a throttling mechanism to batch UI updates for performance.
class MarketManager {
  /// Constructor allowing dependency injection
  MarketManager({
    required DioService dioService,
    required WebSocketService<MiniTicker> socketService,
  }) : _dioService = dioService,
       _socketService = socketService;

  final DioService _dioService;
  final WebSocketService<MiniTicker> _socketService;
  final CustomLogger _logger = CustomLogger('MarketManager');

  /// Main data source (Snapshot)
  /// Key: Symbol (e.g. BTCUSDT), Value: CoinTicker object
  final Map<String, CoinTicker> _tickerMap = {};

  /// Buffer for incoming high-frequency updates
  final Map<String, MiniTicker> _pendingUpdates = {};

  /// Throttle timer
  Timer? _throttleTimer;
  static const Duration _throttleDuration = Duration(milliseconds: 500);

  /// Stream controller for UI consumption
  final StreamController<MarketState> _marketStreamController =
      StreamController<MarketState>.broadcast();

  /// Public stream of the unified Coin list
  Stream<MarketState> get marketStream => _marketStreamController.stream;

  /// Initializes the manager:
  /// 1. Fetches initial snapshot via REST
  /// 2. Sets up WebSocket connection
  /// 3. Starts throttling timer
  Future<void> init() async {
    _logger.info('Initializing MarketManager...');

    // 1. Fetch Snapshot
    await _fetchInitialSnapshot();

    // 2. Setup Socket
    _setupWebSocket();

    // 3. Start Throttle Timer
    _startThrottleTimer();
  }

  Future<void> _fetchInitialSnapshot() async {
    try {
      _logger.info('Fetching snapshot from ${UrlConst.ticker24hr}');

      // Using requestStreaming to handle large list efficiently
      final stream = _dioService.requestStreaming<CoinTicker>(
        url: UrlConst.ticker24hr,
        fromJson: CoinTicker.fromJson,
        chunkSize: 500, // Large chunks for initial load
      );

      await for (final chunk in stream) {
        for (final ticker in chunk) {
          if (ticker.symbol != null) {
            _tickerMap[ticker.symbol!] = ticker;
          }
        }
        // Emit partial updates during load if desired,
        // or wait until end. Here we emit per chunk to show progress.
        _emitState();
      }

      _logger.info('Snapshot loaded. Total coins: ${_tickerMap.length}');
    } catch (e, s) {
      _logger.error('Failed to fetch snapshot', error: e, stackTrace: s);
      // Depending on requirements, we might want to rethrow or retry
    }
  }

  void _setupWebSocket() {
    _socketService.setParser(MiniTicker.fromJson);

    // Listen to socket messages
    _socketService.messages.listen(
      (miniTicker) {
        // Add to buffer (Last Write Wins strategy)
        if (miniTicker.s != null) {
          _pendingUpdates[miniTicker.s!] = miniTicker;
        }
      },
      onError: (Object error) {
        _logger.error('WebSocket stream error', error: error);
      },
    );

    // Connect
    // Note: unawaited allows init() to complete without waiting for connection
    unawaited(_socketService.connect(UrlConst.miniTicker));
  }

  void _startThrottleTimer() {
    _throttleTimer?.cancel();
    _throttleTimer = Timer.periodic(_throttleDuration, (_) {
      _processPendingUpdates();
    });
  }

  void _processPendingUpdates() {
    if (_pendingUpdates.isEmpty) return;

    // Apply batched updates to the main state
    final changedSymbols = <String>{};

    for (final entry in _pendingUpdates.entries) {
      final symbol = entry.key;
      final miniTicker = entry.value;

      final currentTicker = _tickerMap[symbol];
      if (currentTicker != null) {
        // Merge logic inside CoinTicker
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

  /// Closes streams and timers
  void dispose() {
    _throttleTimer?.cancel();
    _socketService.dispose();
    unawaited(_marketStreamController.close());
    _logger.info('MarketManager disposed');
  }
}
