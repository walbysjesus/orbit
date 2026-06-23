import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/history_api_service.dart';
import 'package:orbit/services/network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeConnectivityProvider extends ConnectivityProvider {
  final ConnectivityResult _result;

  FakeConnectivityProvider(this._result);

  @override
  Future<dynamic> checkConnectivity() async {
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('HistoryApiService', () {
    test('fetchHistory usa cache si no hay conexión de red', () async {
      final networkService =
          NetworkService(FakeConnectivityProvider(ConnectivityResult.none));
      final mockDio = SimpleMockDio(
        responseData: [],
        statusCode: 200,
      );
      final result = await HistoryApiService.fetchHistory(
        client: mockDio,
        networkService: networkService,
      );

      expect(result, isEmpty);
    });

    test('fetchHistory usa cache si el backend no responde', () async {
      final mockDio = SimpleMockDio(
        responseData: 'error',
        statusCode: 500,
      );
      final result = await HistoryApiService.fetchHistory(
        client: mockDio,
      );

      expect(result, isEmpty);
    });

    test('fetchHistory retorna datos cuando backend responde correctamente',
        () async {
      final sampleData = [
        {'id': 1, 'message': 'Hola'},
      ];

      final mockDio = SimpleMockDio(
        responseData: sampleData,
        statusCode: 200,
      );

      final result = await HistoryApiService.fetchHistory(client: mockDio);
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.first['message'], 'Hola');
    });
  });
}

/// Simple mock implementation of Dio for testing
class SimpleMockDio implements Dio {
  final dynamic responseData;
  final int statusCode;

  SimpleMockDio({required this.responseData, required this.statusCode});

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      Options? options,
      CancelToken? cancelToken,
      ProgressCallback? onReceiveProgress,
      Object? data}) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: responseData as T,
      statusCode: statusCode,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
