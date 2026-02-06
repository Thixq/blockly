import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/env/env.dart';
import 'package:dio/dio.dart';

class DioConfig {
  DioConfig._();

  static final Dio dio = _createDio();
  static final CustomLogger _logger = CustomLogger('Dio Config');

  static String get baseUrl => Env.binanceTicker24hUrl;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        receiveTimeout: const Duration(
          seconds: 15,
        ),
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(_logInterceptor());

    return dio;
  }

  static Interceptor _logInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        _logger.info('Request: ${options.method} - ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.info(
          'Response: ${response.statusCode} - ${response.requestOptions.path}',
        );
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _logger.error(
          'Error: ${e.response?.statusCode} - ${e.requestOptions.path}\nMessage: ${e.message}',
          error: e,
          stackTrace: e.stackTrace,
        );
        return handler.next(e);
      },
    );
  }
}
