// ignore_for_file: unnecessary_underscores, document_ignores

import 'dart:async';

import 'package:blockly/views/coin_detail/view_model/coin_detail_view_model.dart';
import 'package:blockly/views/coin_detail/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [CoinDetailView] is the main view for displaying detailed information about a specific coin.
/// It uses a [CoinDetailViewModel] to manage the state and data for the coin details, and displays various pieces of information such as price, volume, and price changes in a structured
class CoinDetailView extends StatefulWidget {
  /// Constructor with required symbol parameter
  const CoinDetailView({required this.symbol, super.key});

  /// The symbol of the coin to display details for (e.g. BTCUSDT)
  final String symbol;

  @override
  State<CoinDetailView> createState() => _CoinDetailViewState();
}

class _CoinDetailViewState extends State<CoinDetailView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "setState() or markNeedsBuild() called during build" hatasını önlemek için
    // güncelleme işlemini frame sonuna erteliyoruz.
    unawaited(
      Future.microtask(() {
        if (mounted) {
          context.read<CoinDetailViewModel>().setSymbol(widget.symbol);
        }
      }),
    );
  }

  @override
  void dispose() {
    context.read<CoinDetailViewModel>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} Detay'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 20),
            _PriceSection(),
            SizedBox(height: 40),
            Expanded(child: _DetailGrid()),
          ],
        ),
      ),
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection();

  @override
  Widget build(BuildContext context) {
    // LastPrice veya PriceChange değişirse burası render olur.
    return Selector<CoinDetailViewModel, (String?, String?)>(
      selector: (_, vm) =>
          (vm.ticker?.lastPrice, vm.ticker?.priceChangePercent),
      builder: (context, data, _) {
        final lastPrice = data.$1 ?? '0.00';
        final priceChangePercentStr = data.$2 ?? '0';
        final priceChangePercent = double.tryParse(priceChangePercentStr) ?? 0;
        final isPositive = priceChangePercent >= 0;
        final color = isPositive ? Colors.green : Colors.red;

        return Column(
          children: [
            Text(
              lastPrice,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$priceChangePercentStr%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.highPrice,
          builder: (_, val, __) => DetailCard(
            title: '24s En Yüksek',
            value: val ?? '-',
            valueColor: Colors.green,
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.lowPrice,
          builder: (_, val, __) => DetailCard(
            title: '24s En Düşük',
            value: val ?? '-',
            valueColor: Colors.red,
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.volume,
          builder: (_, val, __) => DetailCard(
            title: 'Hacim',
            value: double.tryParse(val ?? '0')?.toStringAsFixed(2) ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.quoteVolume,
          builder: (_, val, __) => DetailCard(
            title: 'Quote Hacim',
            value: double.tryParse(val ?? '0')?.toStringAsFixed(2) ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.openPrice,
          builder: (_, val, __) => DetailCard(
            title: 'Açılış Fiyatı',
            value: val ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.weightedAvgPrice,
          builder: (_, val, __) => DetailCard(
            title: 'Ağırlıklı Ort.',
            value: val ?? '-',
          ),
        ),
      ],
    );
  }
}
