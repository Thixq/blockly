import 'package:blockly/core/logging/error_handler.dart';
import 'package:dio/dio.dart';

///Basic HTTP Request Management Class
class DioNetwork {
  /// Constructor with Dio instance injection
  DioNetwork({required Dio dioInstance}) : _dio = dioInstance;

  final Dio _dio;
  final _errorHandler = ErrorHandler('DioNetwork');

  /// Base Options Config Get
  BaseOptions get baseOptions => _dio.options;

  /// Base Options Config Set
  set baseOptions(BaseOptions option) => _dio.options = option;

  /// Generic Request Method
  Future<T?> request<T>({
    required String url,
    required T? Function(Map<String, dynamic>? json) fromJson,
    Map<String, dynamic>? queryParameters,
    Object? data,
    String requestType = 'GET',
    Map<String, dynamic>? headers,
  }) async {
    return _errorHandler.executeSafely<T?>(
      () async {
        final response = await _dio.request<Map<String, dynamic>?>(
          url,
          data: data,
          queryParameters: queryParameters,
          options: Options(method: requestType, headers: headers),
        );

        return fromJson(response.data);
      },
      errorMessage: 'Request execution failed for url: $url',
    );
  }
}
