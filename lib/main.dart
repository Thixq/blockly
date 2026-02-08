import 'package:blockly/core/logging/log_manager.dart';
import 'package:blockly/core/logging/zone_manager.dart';
import 'package:blockly/feature/init/dependency_container.dart';
import 'package:blockly/feature/init/dependency_instances.dart';
import 'package:blockly/views/coin_detail/view_model/coin_detail_view_model.dart';
import 'package:blockly/views/home/view/home_view.dart';
import 'package:blockly/views/home/view_model/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  await ZoneManager.runAppInZone(() async {
    WidgetsFlutterBinding.ensureInitialized();
    LogManager.init();
    DependencyContainer.instance.configure();
    runApp(const MyApp());
  });
}

/// [MyApp] is the root widget of the application. It sets up the Provider for HomeViewModel and initializes the HomeView.
class MyApp extends StatelessWidget {
  /// Constructor with optional key parameter
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              HomeViewModel(DependencyInstances.manager.marketManager),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CoinDetailViewModel(DependencyInstances.manager.marketManager),
          lazy: true,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.from(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        darkTheme: ThemeData.from(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeView(),
      ),
    );
  }
}
