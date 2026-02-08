// ignore_for_file: document_ignores

import 'package:blockly/core/extensions/context_extension.dart';
import 'package:blockly/feature/init/dependency_instances.dart';
import 'package:blockly/views/coin_detail/view_model/coin_detail_view_model.dart';
import 'package:blockly/views/coin_detail/widgets/detail_grid.dart';
import 'package:blockly/views/coin_detail/widgets/price_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [CoinDetailView] is the main view for displaying detailed information about a specific coin.
/// It uses a [CoinDetailViewModel] to manage the state and data for the coin details,
/// and displays various pieces of information such as price, volume, and price changes.
class CoinDetailView extends StatelessWidget {
  /// Constructor with required symbol parameter
  const CoinDetailView({required this.symbol, super.key});

  /// The symbol of the coin to display details for (e.g. BTCUSDT)
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CoinDetailViewModel(
        DependencyInstances.manager.marketManager,
      )..setSymbol(symbol),
      child: CoinDetailBody(symbol: symbol),
    );
  }
}

/// The body content of the coin detail screen.
class CoinDetailBody extends StatelessWidget {
  /// Constructor with required symbol parameter
  const CoinDetailBody({required this.symbol, super.key});

  /// The symbol of the coin to display details for (e.g. BTCUSDT)
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('$symbol Detail'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 20),
            PriceSection(),
            SizedBox(height: 40),
            DetailGrid(),
          ],
        ),
      ),
    );
  }
}
