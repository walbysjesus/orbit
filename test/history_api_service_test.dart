import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      final result = await HistoryApiService.fetchHistory(
        client: MockClient((_) async => http.Response('[]', 200)),
        networkService: networkService,
      );

      expect(result, isEmpty);
    });

    test('fetchHistory usa cache si el backend no responde', () async {
      final result = await HistoryApiService.fetchHistory(
        client: MockClient((_) async => http.Response('error', 500)),
      );

      expect(result, isEmpty);
    });

    test('fetchHistory retorna datos cuando backend responde correctamente',
        () async {
      final sampleData = [
        {'id': 1, 'message': 'Hola'},
      ];

      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/history'));
        return http.Response(jsonEncode(sampleData), 200);
      });

      final result = await HistoryApiService.fetchHistory(client: client);
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.first['message'], 'Hola');
    });
  });
}
