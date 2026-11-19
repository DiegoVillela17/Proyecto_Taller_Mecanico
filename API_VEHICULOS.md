# Marcas y modelos para el administrador

Implementado sobre `integracion-api`, commit base `3f8518c`.

En Vehículos → Registrar vehículo o Editar vehículo, escribir en Marca filtra
las sugerencias de vPIC. Elegir una marca (o escribir su nombre exacto) consulta
sus modelos. Modelo también filtra al escribir. Ambos campos admiten texto libre:
no es obligatorio elegir del catálogo. Se guarda el texto final en los campos
existentes de Supabase. No requiere migración SQL ni claves de API.

Cambiar la marca limpia el modelo. Abrir un vehículo existente conserva sus datos,
aunque no estén en el catálogo. Una respuesta atrasada de otra marca se descarta.
Las sugerencias tienen desplazamiento y se ocultan al salir del campo.

La consulta está integrada en el formulario al que solo accede el administrador
mediante los botones de registrar/editar. La seguridad de escrituras sigue
correspondiendo a las políticas RLS existentes de Supabase; esta modificación no
cambia esas políticas. No se agregan controles a cliente ni mecánico.

## API

https://vpic.nhtsa.dot.gov/api/

- `/vehicles/GetMakesForVehicleType/car?format=json`
- `/vehicles/GetModelsForMakeId/{id}?format=json`

Se consultan marcas de automóviles y modelos por marca, sin filtrar por año.
El catálogo no se trata como una lista exhaustiva del mercado mexicano.
Se reutilizan resultados en memoria mientras el formulario está abierto.
Esta caché no constituye persistencia offline. Si la API falla, se informa y
permanece disponible la captura manual. No se necesita modificar pubspec.yaml:
la rama ya declara http.

## Validación local

```powershell
flutter pub get
flutter analyze
flutter test test/vehiculos_api_service_test.dart test/campos_vehiculo_api_test.dart
flutter run -d chrome
```

Pruebas manuales:
1. Como administrador, escribir `toy`, seleccionar TOYOTA, buscar un modelo y guardar.
2. Confirmar los datos al volver a abrir el vehículo.
3. Cambiar marca y comprobar que se limpia el modelo anterior.
4. Registrar marca y modelo que no estén en el catálogo.
5. Editar un vehículo manual sin cambiar marca/modelo: deben conservarse.
6. Bloquear vpic.nhtsa.dot.gov en DevTools y verificar captura manual y reintento.
7. Revisar que cliente y mecánico no tengan botones de registrar/editar vehículos.
8. Probar a 400 px de ancho y con modo oscuro.

El test/widget_test.dart original sigue siendo la prueba del contador de Flutter;
no representa esta aplicación y no se modificó en este cambio.
