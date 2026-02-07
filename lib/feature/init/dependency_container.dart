import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/models/mini_ticker.dart';
import 'package:blockly/feature/services/network/dio_config.dart';
import 'package:blockly/feature/services/network/dio_service.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

/// [DependencyContainer] is a centralized place to manage all dependencies using GetIt.
/// It ensures that services and managers are properly instantiated and can be easily accessed throughout the app.
final class DependencyContainer {
  const DependencyContainer._();

  /// Singleton instance
  static const instance = DependencyContainer._();
  static final GetIt _getIt = GetIt.instance;

  /// Configures all dependencies including services and managers.
  void configure() {
    _configureService();
    _configureManagers();
  }

  /// Helper to read dependencies easily
  static T read<T extends Object>() => instance.get<T>();

  void _configureService() {
    _getIt
      ..registerLazySingleton<Dio>(
        () => DioConfig.dio,
      )
      ..registerLazySingleton<DioService>(
        () => DioService(dioInstance: _getIt<Dio>()),
      )
      ..registerFactory<WebSocketService<MiniTicker>>(
        WebSocketService<MiniTicker>.new,
      );
  }

  void _configureManagers() {
    _getIt.registerLazySingleton<MarketManager>(
      () => MarketManager(
        dioService: _getIt<DioService>(),
        socketService: _getIt<WebSocketService<MiniTicker>>(),
      ),
    );
  }

  /// Generic method to retrieve any registered dependency.
  T get<T extends Object>() => _getIt.get<T>();
}
