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
  static T read<T extends Object>() => _getIt<T>();

  /// Retrieves the dependency if registered; otherwise registers it as a lazy singleton and returns it.
  /// Useful for generic services created at runtime.
  static T readOrCreate<T extends Object>(T Function() factory) {
    if (!_getIt.isRegistered<T>()) {
      _getIt.registerLazySingleton<T>(factory);
    }
    return _getIt<T>();
  }

  void _configureService() {
    _getIt
      ..registerLazySingleton<Dio>(
        () => DioConfig.dio,
      )
      ..registerLazySingleton<DioService>(
        () => DioService(dioInstance: _getIt<Dio>()),
      );
  }

  void _configureManagers() {
    _getIt.registerLazySingleton<MarketManager>(
      () => MarketManager(
        dioService: _getIt<DioService>(),
        // Burada doğrudan tip belirterek çağırıyoruz.
        // WebSocketService içindeki factory sayesinde eğer MiniTicker
        // havuzda varsa o gelecek, yoksa yeni oluşacak.
        socketService: readOrCreate<WebSocketService<MiniTicker>>(
          () => WebSocketService<MiniTicker>(
            parser: MiniTicker.fromJson,
            manuellyRetry: true,
          ),
        ),
      ),
    );
  }
}
