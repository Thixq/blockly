import 'package:blockly/feature/services/network/dio_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'dio_network_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Dio>(),
])
void main() {
  late MockDio mockDio;
  late DioNetwork dioNetwork;

  setUp(() {
    mockDio = MockDio();
    // Stub the options getter to avoid NPE when DioNetwork accesses it.
    when(mockDio.options).thenReturn(BaseOptions());

    dioNetwork = DioNetwork(dioInstance: mockDio);
  });

  // Pass-through model for testing normal request (must accept nullable)
  Map<String, dynamic> testModelFromJsonNullable(Map<String, dynamic> json) =>
      json;

  // Pass-through model for testing streaming request (non-nullable input as per definition)
  Map<String, dynamic> testModelFromJson(Map<String, dynamic> json) => json;

  group('DioNetwork', () {
    const tUrl = 'https://example.com/api';

    test('request returns parsed data (T) when call is successful', () async {
      // Arrange
      final responseData = {'id': 1, 'name': 'Test'};

      when(
        mockDio.request<Map<String, dynamic>?>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: responseData,
          statusCode: 200,
        ),
      );

      // Act
      final result = await dioNetwork.request<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJsonNullable,
      );

      // Assert
      expect(result, responseData);
      verify(
        mockDio.request<Map<String, dynamic>?>(
          tUrl,
          options: anyNamed('options'),
        ),
      ).called(1);
    });

    test(
      'request rethrows exception when Dio fails',
      () async {
        // Arrange
        when(
          mockDio.request<Map<String, dynamic>?>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: tUrl),
            error: 'Some Network Error',
          ),
        );

        // Act & Assert
        expect(
          () => dioNetwork.request<Map<String, dynamic>>(
            url: tUrl,
            fromJson: testModelFromJsonNullable,
          ),
          throwsA(isA<DioException>()),
        );
      },
    );

    test(
      'requestStreaming yields correct chunks when call is successful',
      () async {
        // Arrange
        // A JSON string representing a list of 3 items
        const jsonString = '[{"id":1},{"id":2},{"id":3}]';

        when(
          mockDio.request<String>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: tUrl),
            data: jsonString,
            statusCode: 200,
          ),
        );

        // Act
        final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
          url: tUrl,
          fromJson: testModelFromJson,
          chunkSize: 2, // Should split into [1,2] and [3]
        );

        // Assert
        final chunks = await stream.toList();

        expect(chunks.length, 2);
        expect(chunks[0], [
          {'id': 1},
          {'id': 2},
        ]);
        expect(chunks[1], [
          {'id': 3},
        ]);
      },
    );

    test('requestStreaming yields empty list when response is empty', () async {
      // Arrange
      when(
        mockDio.request<String>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: '',
          statusCode: 200,
        ),
      );

      // Act
      final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJson,
      );

      // Assert
      final chunks = await stream.toList();
      expect(chunks.length, 1);
      expect(chunks[0], isEmpty);
    });

    test('requestStreaming emits error when Dio throws exception', () async {
      // Arrange
      final exception = DioException(
        requestOptions: RequestOptions(path: tUrl),
        message: 'Stream failed',
      );

      when(
        mockDio.request<String>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenThrow(exception);

      // Act
      final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJson,
      );

      // Assert
      expect(stream, emitsError(isA<DioException>()));
    });

    test('request passes headers and query params correctly', () async {
      // Arrange
      final headers = {'Authorization': 'Bearer token'};
      final queryParams = {'limit': 10};

      when(
        mockDio.request<Map<String, dynamic>?>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: {'success': true},
          statusCode: 200,
        ),
      );

      // Act
      await dioNetwork.request<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJsonNullable,
        headers: headers,
        queryParameters: queryParams,
      );

      // Assert
      verify(
        mockDio.request<Map<String, dynamic>?>(
          tUrl,
          queryParameters: queryParams,
          options: argThat(
            predicate<Options>((options) {
              return options.headers?['Authorization'] == 'Bearer token';
            }),
            named: 'options',
          ),
        ),
      ).called(1);
    });

    test('requestStreaming handles malformed JSON gracefully', () async {
      // Arrange
      // Invalid JSON: Missing closing bracket and property quotes
      const malformedJson = '[{id: 1, name: "test"';

      when(
        mockDio.request<String>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: malformedJson,
          statusCode: 200,
        ),
      );

      // Act
      final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJson,
      );

      // Assert
      // The parser isolate or the stream controller should emit an error
      expect(stream, emitsError(anything));
    });

    test('requestStreaming respects custom chunkSize behavior', () async {
      // Arrange
      // 5 items
      const jsonString = '[{"i":1},{"i":2},{"i":3},{"i":4},{"i":5}]';

      when(
        mockDio.request<String>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: jsonString,
          statusCode: 200,
        ),
      );

      // Act
      // Request chunks of size 2. Expected: [1,2], [3,4], [5]
      final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJson,
        chunkSize: 2,
      );

      // Assert
      final chunks = await stream.toList();
      expect(chunks.length, 3);
      expect(chunks[0].length, 2);
      expect(chunks[1].length, 2);
      expect(chunks[2].length, 1);

      expect(chunks[0].first['i'], 1);
      expect(chunks[2].first['i'], 5);
    });

    test('requestStreaming handles complex nested JSON structure', () async {
      // Arrange
      const jsonString = '''
        [
          {
            "id": 1,
            "metadata": {
              "tags": ["a", "b"],
              "info": {"active": true}
            }
          },
          {
            "id": 2,
            "metadata": null
          }
        ]
      ''';

      when(
        mockDio.request<String>(
          any,
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: tUrl),
          data: jsonString,
          statusCode: 200,
        ),
      );

      // Act
      final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
        url: tUrl,
        fromJson: testModelFromJson,
      );

      final chunks = await stream.toList();

      // Assert
      expect(chunks.length, 1); // Default chunk size is 100, so 1 chunk
      final items = chunks.first;
      expect(items.length, 2);

      // Check deep nesting
      expect(items[0]['metadata']['tags'], ['a', 'b']);
      expect(items[0]['metadata']['info']['active'], true);
      expect(items[1]['metadata'], isNull);
    });

    test(
      'requestStreaming handles single object JSON (not wrapped in list) correctly',
      () async {
        // Arrange
        // Input is a single object, not an array.
        // User expects this to be treated as a stream of 1 item.
        const jsonString = '{"id": 1, "name": "Single Item"}';

        when(
          mockDio.request<String>(
            any,
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: tUrl),
            data: jsonString,
            statusCode: 200,
          ),
        );

        // Act
        final stream = dioNetwork.requestStreaming<Map<String, dynamic>>(
          url: tUrl,
          fromJson: testModelFromJson,
        );

        // Assert
        final chunks = await stream.toList();
        expect(chunks.length, 1); // Should be 1 chunk
        expect(chunks[0].length, 1); // Containing 1 item
        expect(chunks[0].first['id'], 1);
        expect(chunks[0].first['name'], 'Single Item');
      },
    );
  });
}

