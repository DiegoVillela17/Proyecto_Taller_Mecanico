import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class OpcionVehiculo {
  final int id;
  final String nombre;

  const OpcionVehiculo({required this.id, required this.nombre});
}

class VehiculosApiException implements Exception {
  final String mensaje;
  const VehiculosApiException(this.mensaje);

  @override
  String toString() => mensaje;
}

class VehiculosApiService {
  final http.Client _client;
  final Map<int, List<OpcionVehiculo>> _modelos = {};
  List<OpcionVehiculo>? _marcas;

  VehiculosApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<OpcionVehiculo>> _consultar(
    String ruta,
    String campoId,
    String campoNombre,
  ) async {
    try {
      final respuesta = await _client.get(Uri.https(
        'vpic.nhtsa.dot.gov',
        '/api/vehicles/$ruta',
        {'format': 'json'},
      )).timeout(const Duration(seconds: 20));
      if (respuesta.statusCode != 200) {
        throw const VehiculosApiException(
          'El catálogo no está disponible. Puedes escribir el dato manualmente.',
        );
      }
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (json is! Map || json['Results'] is! List) {
        throw const FormatException();
      }
      final opciones = <int, OpcionVehiculo>{};
      for (final fila in json['Results'] as List) {
        if (fila is! Map) continue;
        final id = int.tryParse('${fila[campoId]}');
        final nombre = fila[campoNombre]?.toString().trim() ?? '';
        if (id != null && nombre.isNotEmpty) {
          opciones[id] = OpcionVehiculo(id: id, nombre: nombre);
        }
      }
      return opciones.values.toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    } on TimeoutException {
      throw const VehiculosApiException(
        'El catálogo tardó demasiado. Puedes escribir el dato manualmente.',
      );
    } on http.ClientException {
      throw const VehiculosApiException(
        'Sin conexión con el catálogo. Puedes escribir el dato manualmente.',
      );
    } on FormatException {
      throw const VehiculosApiException(
        'No se pudo leer el catálogo. Puedes escribir el dato manualmente.',
      );
    }
  }

  Future<List<OpcionVehiculo>> obtenerMarcas() async {
    return _marcas ??= await _consultar(
      'GetMakesForVehicleType/car', 'MakeId', 'MakeName',
    );
  }

  Future<List<OpcionVehiculo>> obtenerModelos(int idMarca) async {
    return _modelos[idMarca] ??= await _consultar(
      'GetModelsForMakeId/$idMarca', 'Model_ID', 'Model_Name',
    );
  }

  void dispose() => _client.close();
}
