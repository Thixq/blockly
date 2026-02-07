import 'package:blockly/feature/components/smart_coin_row.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [HomeView] is the main screen of the app that displays a list of coins and a search bar.
class HomeView extends StatelessWidget {
  /// Constructor with optional key parameter
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            onChanged: (value) =>
                context.read<HomeViewModel>().updateSearchText(value),
            decoration: InputDecoration(
              hintText: 'Search Coin...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
        ),
      ),
      body: Selector<HomeViewModel, List<CoinTicker>>(
        selector: (_, vm) => vm.tickerList,
        shouldRebuild: (previous, next) => previous.length != next.length,
        builder: (context, tickerList, child) {
          return ListView.builder(
            itemCount: tickerList.length,
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final symbol = tickerList[index].symbol!;
              return SmartCoinRow(symbol: symbol);
            },
          );
        },
      ),
    );
  }
}
