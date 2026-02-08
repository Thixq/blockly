import 'dart:async';

import 'package:blockly/core/extensions/context_extension.dart';
import 'package:blockly/feature/models/coin_ticker.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:blockly/views/home/widgets/smart_coin_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [HomeView] is the main screen of the app that displays a list of coins and a search bar.
class HomeView extends StatefulWidget {
  /// Constructor with optional key parameter
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late HomeViewModel _viewModel;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<HomeViewModel>();
    _searchController = TextEditingController(text: _viewModel.searchText);
    _viewModel.addListener(_onStateChanged);
    if (_viewModel.state == HomeViewState.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onStateChanged());
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    print('Home view state: ${_viewModel.state}');
    if (!mounted) return;
    if (_viewModel.state == HomeViewState.error ||
        _viewModel.state == HomeViewState.disconnected) {
      unawaited(
        showAdaptiveDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog.adaptive(
            title: Text(
              _viewModel.state == HomeViewState.disconnected
                  ? 'Connection Lost'
                  : 'Error',
            ),
            content: Text(
              _viewModel.errorMessage ??
                  'An unexpected error occurred. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_viewModel.retry());
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Performance fix: Prevents list rebuild on keyboard open
      appBar: AppBar(
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.colorScheme.surface,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => _viewModel.updateSearchText(value),
            decoration: InputDecoration(
              hintText: 'Search Coin...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: context.colorScheme.surfaceContainerHigh,
            ),
          ),
        ),
      ),
      body: Selector<HomeViewModel, HomeViewState>(
        selector: (_, vm) => vm.state,
        builder: (context, state, child) {
          switch (state) {
            case HomeViewState.loading:
              return const Center(child: CircularProgressIndicator.adaptive());
            case HomeViewState.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'There is a problem.',
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            case HomeViewState.loaded:
            case HomeViewState.disconnected:
              return Selector<HomeViewModel, List<CoinTicker>>(
                selector: (_, vm) => vm.tickerList,
                shouldRebuild: (previous, next) =>
                    previous.length != next.length,
                builder: (context, tickerList, child) {
                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: tickerList.length,
                    cacheExtent: 500,
                    itemBuilder: (context, index) {
                      final symbol = tickerList[index].symbol!;
                      return SmartCoinRow(symbol: symbol);
                    },
                  );
                },
              );
          }
        },
      ),
    );
  }
}
