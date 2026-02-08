import 'package:blockly/views/coin_detail/view_model/coin_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Displays the current price and percentage change for the selected coin.
class PriceSection extends StatelessWidget {
  /// Constructor
  const PriceSection({super.key});

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
