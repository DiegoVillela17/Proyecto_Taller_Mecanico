import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taller_app/shared/services/vehiculos_api_service.dart';

void main() {
  test('Consulta, ordena, elimina duplicados y reutiliza marcas', () async {
    var llamadas = 0;
    final api = VehiculosApiService(client: MockClient((request) async {
      llamadas++;
      expect(request.url.path, '/api/vehicles/GetMakesForVehicleType/car');
      expect(request.url.queryParameters['format'], 'json');
      return http.Response(jsonEncode({'Results': [
        {'MakeId': 448, 'MakeName': 'TOYOTA'},
        {'MakeId': 474, 'MakeName': 'HONDA'},
        {'MakeId': 448, 'MakeName': 'TOYOTA'},
      ]}), 200);
    }));
    addTearDown(api.dispose);
    expect((await api.obtenerMarcas()).map((e) => e.nombre), ['HONDA', 'TOYOTA']);
    await api.obtenerMarcas();
    expect(llamadas, 1);
  });

  test('Los modelos se consultan y almacenan por marca', () async {
    var llamadas = 0;
    final api = VehiculosApiService(client: MockClient((request) async {
      llamadas++;
      return http.Response(jsonEncode({'Results': [
        {'Model_ID': 1, 'Model_Name': request.url.pathSegments.last},
      ]}), 200);
    }));
    addTearDown(api.dispose);
    expect((await api.obtenerModelos(448)).single.nombre, '448');
    expect((await api.obtenerModelos(474)).single.nombre, '474');
    await api.obtenerModelos(448);
    expect(llamadas, 2);
  });

  test('No almacena errores: permite reintentar la consulta', () async {
    var llamadas = 0;
    final api = VehiculosApiService(client: MockClient((_) async {
      llamadas++;
      return llamadas == 1
          ? http.Response('Unavailable', 503)
          : http.Response('{"Results": []}', 200);
    }));
    addTearDown(api.dispose);
    await expectLater(api.obtenerMarcas(), throwsA(isA<VehiculosApiException>()));
    expect(await api.obtenerMarcas(), isEmpty);
    expect(llamadas, 2);
  });

  test('Rechaza una respuesta sin Results', () async {
    final api = VehiculosApiService(client: MockClient((_) async {
      return http.Response('{}', 200);
    }));
    addTearDown(api.dispose);
    await expectLater(api.obtenerMarcas(), throwsA(isA<VehiculosApiException>()));
  });
}
