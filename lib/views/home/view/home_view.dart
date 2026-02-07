import 'package:blockly/feature/components/smart_coin_row.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Market List')),
      body: Selector<HomeViewModel, List<CoinTicker>>(
        // SELECTOR 1: LİSTE İSKELETİ
        // Sadece listenin kendisi (referansı) veya uzunluğu değişirse burası çalışır.
        // Fiyat değişimleri burayı TETİKLEMEZ.
        selector: (_, vm) => vm.tickerList,
        shouldRebuild: (previous, next) => previous.length != next.length,
        builder: (context, tickerList, child) {
          return ListView.builder(
            itemCount: tickerList.length,
            // CacheExtent performansı artırır (ekran dışındaki render payı)
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final symbol = tickerList[index].symbol!;

              // Her satıra sadece Symbol'ü (ID) veriyoruz.
              // Verinin kendisini değil!
              return SmartCoinRow(symbol: symbol);
            },
          );
        },
      ),
    );
  }
}
