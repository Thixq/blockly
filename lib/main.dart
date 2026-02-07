import 'package:blockly/core/logging/log_manager.dart';
import 'package:blockly/core/logging/zone_manager.dart';
import 'package:blockly/feature/init/dependency_container.dart';
import 'package:blockly/feature/init/dependency_instances.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              HomeViewModel(DependencyInstances.manager.marketManager),
        ),
      ],
      child: const MaterialApp(
        home: HomeView(),
      ),
    );
  }
}
