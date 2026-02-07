import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SmartCoinRow extends StatelessWidget {
  const SmartCoinRow({required this.symbol, super.key});
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Selector<HomeViewModel, CoinTicker?>(
      // SELECTOR 2: SATIR BAZLI GÜNCELLEME
      // ViewModel'den sadece bu sembole ait veriyi çekiyoruz.
      selector: (_, vm) => vm.getTickerBySymbol(symbol),

      // Sadece bu coin'in verisi (fiyatı/yüzdesi) değiştiyse builder çalışır.
      // Diğer 2999 coin güncellense bile burası çalışmaz!
      builder: (context, ticker, child) {
        if (ticker == null) return const SizedBox();

        // Renk animasyonu için basit bir trick:
        // Fiyat arttıysa yeşil, düştüyse kırmızı yanıp sönebilir.
        return ListTile(
          title: Text(ticker.symbol ?? ''),
          subtitle: Text('Vol: ${ticker.volume}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  (double.tryParse(ticker.priceChangePercent ?? '0') ?? 0) >= 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ticker.lastPrice ?? '0.00',
              style: TextStyle(
                color:
                    (double.tryParse(ticker.priceChangePercent ?? '0') ?? 0) >=
                        0
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
