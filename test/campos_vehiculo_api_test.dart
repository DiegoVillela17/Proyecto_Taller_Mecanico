import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_app/shared/services/vehiculos_api_service.dart';
import 'package:taller_app/shared/widgets/campos_vehiculo_api.dart';

class ApiPrueba extends VehiculosApiService {
  final pendientes = <int, Completer<List<OpcionVehiculo>>>{};
  bool falla = false;

  @override
  Future<List<OpcionVehiculo>> obtenerMarcas() async {
    if (falla) throw const VehiculosApiException('Sin conexión');
    return const [
      OpcionVehiculo(id: 448, nombre: 'TOYOTA'),
      OpcionVehiculo(id: 474, nombre: 'HONDA'),
    ];
  }

  @override
  Future<List<OpcionVehiculo>> obtenerModelos(int idMarca) {
    return (pendientes[idMarca] = Completer<List<OpcionVehiculo>>()).future;
  }
}

void main() {
  late TextEditingController marca;
  late TextEditingController modelo;
  late ApiPrueba api;

  setUp(() {
    marca = TextEditingController();
    modelo = TextEditingController();
    api = ApiPrueba();
  });

  tearDown(() {
    marca.dispose();
    modelo.dispose();
    api.dispose();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: CamposVehiculoApi(marca: marca, modelo: modelo, api: api),
    ))));
    await tester.pump();
  }

  testWidgets('Filtra marcas y permite capturar valores fuera del catálogo', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextFormField).first, 'toy');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(ListTile, 'TOYOTA'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'HONDA'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Marca local');
    await tester.enterText(find.byType(TextFormField).last, 'Modelo local');
    await tester.pump(const Duration(milliseconds: 400));
    expect(marca.text, 'Marca local');
    expect(modelo.text, 'Modelo local');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Editar conserva el modelo y descarta respuestas de otra marca', (tester) async {
    marca.text = 'TOYOTA';
    modelo.text = 'Corolla';
    await abrir(tester);
    expect(modelo.text, 'Corolla');
    await tester.enterText(find.byType(TextFormField).first, 'HONDA');
    await tester.pump(const Duration(milliseconds: 400));
    expect(modelo.text, isEmpty);
    api.pendientes[474]!.complete(const [OpcionVehiculo(id: 2, nombre: 'Civic')]);
    await tester.pump();
    api.pendientes[448]!.complete(const [OpcionVehiculo(id: 1, nombre: 'Corolla')]);
    await tester.pump();
    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'Civic'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Corolla'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Con API caída siguen disponibles ambos campos', (tester) async {
    api.falla = true;
    await abrir(tester);
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Marca manual');
    await tester.enterText(find.byType(TextFormField).last, 'Modelo manual');
    await tester.pump(const Duration(milliseconds: 400));
    expect(modelo.text, 'Modelo manual');
    await tester.pumpWidget(const SizedBox());
  });
}
