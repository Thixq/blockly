import 'package:blockly/feature/init/dependency_container.dart';
import 'package:blockly/feature/json_parser/websocket_isolate_parser.dart';
import 'package:blockly/feature/managers/market_manager.dart';
import 'package:blockly/feature/services/network/dio_service.dart';
import 'package:blockly/feature/services/web_socket/web_socket_service.dart';

/// [DependencyInstances] provides a convenient way to access all registered dependencies.
/// It abstracts away the underlying dependency injection mechanism (GetIt) and offers a clean API for retrieving services and managers.
final class DependencyInstances {
  const DependencyInstances._();

  /// Access to all service instances
  static DependencyServices get service => const DependencyServices._();

  /// Access to all manager instances
  static DependencyManagers get manager => const DependencyManagers._();
}

/// Example usage:
/// ```dart
/// final dio = DependencyInstances.service.dioService;
/// final socketService = DependencyInstances.service.webSocketService<MiniTicker>();
/// ```
/// This class serves as a single point of access for all dependencies, making it easier to manage and retrieve them throughout the app without directly coupling to the GetIt instance.
final class DependencyServices {
  const DependencyServices._();

  /// Retrieves the DioService instance from the DependencyContainer.
  DioService get dioService => DependencyContainer.read<DioService>();

  /// Retrieves a WebSocketService instance for the specified type [T] from the DependencyContainer.
  /// This allows for type-safe access to different WebSocketService instances if needed.
  WebSocketService<T> webSocketService<T>({required Parser<T> parser}) =>
      DependencyContainer.readOrCreate<WebSocketService<T>>(
        () => WebSocketService<T>(parser: parser),
      );
}

/// Example usage:
/// ```dart
/// final marketManager = DependencyInstances.manager.marketManager;
/// ```
/// This class provides access to all manager instances registered in the DependencyContainer. It abstracts away the retrieval logic and offers a clean API for accessing managers like MarketManager, UserManager, etc.
final class DependencyManagers {
  const DependencyManagers._();

  /// Retrieves the MarketManager instance from the DependencyContainer.
  MarketManager get marketManager => DependencyContainer.read<MarketManager>();
}
