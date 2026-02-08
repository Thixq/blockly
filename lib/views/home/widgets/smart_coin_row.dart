import 'dart:async';

import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/views/coin_detail/view/coin_detail_view.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [SmartCoinRow] is a widget that represents a single row in the coin list.
/// It listens directly to [MarketManager.getCoinStream] for its specific symbol,
/// avoiding unnecessary rebuilds from the parent ViewModel.
class SmartCoinRow extends StatefulWidget {
  /// Constructor with required symbol parameter
  const SmartCoinRow({required this.symbol, super.key});

  /// The symbol of the coin this row represents (e.g. BTCUSDT)
  final String symbol;

  @override
  State<SmartCoinRow> createState() => _SmartCoinRowState();
}

class _SmartCoinRowState extends State<SmartCoinRow> {
  double? _prevPrice;
  Color _cachedTextColor = Colors.blue;
  Color _cachedContainerColor = Colors.transparent;

  late final MarketManager _marketManager;
  StreamSubscription<CoinTicker>? _subscription;
  CoinTicker? _ticker;

  @override
  void initState() {
    super.initState();
    _marketManager = context.read<HomeViewModel>().marketManager;
    _ticker = _marketManager.getTicker(widget.symbol);
    _subscription = _marketManager.getCoinStream(widget.symbol).listen((t) {
      if (mounted) setState(() => _ticker = t);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = _ticker;
    if (ticker == null) return const SizedBox();

    final currentPrice = double.tryParse(ticker.lastPrice ?? '0') ?? 0;

    if (_prevPrice != null) {
      if (currentPrice > _prevPrice!) {
        _cachedTextColor = Colors.green;
        _cachedContainerColor = Colors.green.withValues(alpha: 0.1);
      } else if (currentPrice < _prevPrice!) {
        _cachedTextColor = Colors.red;
        _cachedContainerColor = Colors.red.withValues(alpha: 0.1);
      }
    } else {
      final change24h = double.tryParse(ticker.priceChangePercent ?? '0') ?? 0;
      if (change24h >= 0) {
        _cachedTextColor = Colors.green;
        _cachedContainerColor = Colors.green.withValues(alpha: 0.1);
      } else {
        _cachedTextColor = Colors.red;
        _cachedContainerColor = Colors.red.withValues(alpha: 0.1);
      }
    }
    _prevPrice = currentPrice;
    return RepaintBoundary(
      child: ListTile(
        onTap: () {
          unawaited(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CoinDetailView(symbol: widget.symbol),
              ),
            ),
          );
        },
        title: Text(ticker.symbol ?? ''),
        subtitle: Text(
          '${double.tryParse(ticker.priceChangePercent ?? '0')?.toStringAsFixed(2) ?? '0.00'}%',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cachedContainerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ticker.lastPrice ?? '0.00',
            style: TextStyle(
              color: _cachedTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
