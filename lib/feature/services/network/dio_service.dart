// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/json_parser/json_stream_parser.dart';
import 'package:dio/dio.dart';

///Basic HTTP Request Management Class
class DioService {
  /// Constructor with Dio instance injection
  DioService({required Dio dioInstance}) : _dio = dioInstance;

  final Dio _dio;
  final _logger = CustomLogger('DioService');

  /// Base Options Config Get
  BaseOptions get baseOptions => _dio.options;

  /// Base Options Config Set
  set baseOptions(BaseOptions option) => _dio.options = option;

  /// Generic Request Method
  Future<T?> request<T>({
    required String url,
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, dynamic>? queryParameters,
    Object? data,
    String requestType = 'GET',
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>?>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: requestType,
          headers: headers,
        ),
      );

      final responseData = response.data;
      if (responseData == null) {
        return null;
      }

      return fromJson(responseData);
    } catch (e, s) {
      _logger.error('Request failed for url: $url', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Generic Streaming Request Method
  /// Spawns an isolate to parse large lists in chunks to avoid UI jank.
  /// Returns a stream of chunked lists of [T].
  Stream<List<T>> requestStreaming<T>({
    required String url,
    required T Function(Map<String, dynamic> json) fromJson,
    Object? data,
    Map<String, dynamic>? queryParameters,
    String requestType = 'GET',
    Map<String, dynamic>? headers,
    int chunkSize = 100,
  }) async* {
    try {
      final response = await _dio.request<String>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: requestType,
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );

      final jsonString = response.data;
      if (jsonString == null || jsonString.isEmpty) {
        yield [];
        return;
      }

      final parser = JsonStreamParser();

      yield* parser.parse<T>(
        jsonString,
        fromJson,
        chunkSize: chunkSize,
      );
    } catch (e, s) {
      _logger.error(
        'Streaming request failed for url: $url',
        error: e,
        stackTrace: s,
      );
      yield* Stream.error(e, s);
    }
  }
}
