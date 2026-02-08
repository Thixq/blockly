import 'package:blockly/views/coin_detail/view_model/coin_detail_view_model.dart';
import 'package:blockly/views/coin_detail/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Displays a 2-column grid of detail cards (high, low, volume, etc.).
class DetailGrid extends StatelessWidget {
  /// Constructor
  const DetailGrid({super.key});

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
          builder: (_, val, _) => DetailCard(
            title: '24h Highest',
            value: val ?? '-',
            valueColor: Colors.green,
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.lowPrice,
          builder: (_, val, _) => DetailCard(
            title: '24h Lowest',
            value: val ?? '-',
            valueColor: Colors.red,
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.volume,
          builder: (_, val, _) => DetailCard(
            title: 'Volume',
            value: double.tryParse(val ?? '0')?.toStringAsFixed(2) ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.quoteVolume,
          builder: (_, val, _) => DetailCard(
            title: 'Quote Volume',
            value: double.tryParse(val ?? '0')?.toStringAsFixed(2) ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.openPrice,
          builder: (_, val, _) => DetailCard(
            title: 'Open Price',
            value: val ?? '-',
          ),
        ),
        Selector<CoinDetailViewModel, String?>(
          selector: (_, vm) => vm.ticker?.weightedAvgPrice,
          builder: (_, val, _) => DetailCard(
            title: 'Weighted Avg.',
            value: val ?? '-',
          ),
        ),
      ],
    );
  }
}
