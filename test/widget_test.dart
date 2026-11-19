import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_app/shared/widgets/foto_vehiculo.dart';

void main() {
  testWidgets('Un vehículo sin foto funciona sin inicializar Storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FotoVehiculo())),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
  });
}
