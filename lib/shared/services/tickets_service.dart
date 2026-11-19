import 'package:supabase_flutter/supabase_flutter.dart';

class TicketsService {
  final _client = Supabase.instance.client;

  Future<Map<String, List<Map<String, dynamic>>>> obtenerOpciones() async {
    final resultados = await Future.wait([
      _client
          .from('vehiculos')
          .select(
            'id_vehiculo, marca, modelo, anio, placas, '
            'cliente:usuarios!vehiculos_id_cliente_fkey(nombre, apellidos)',
          )
          .order('marca'),
      _client.from('sucursales').select('id_sucursal, nombre').order('nombre'),
      _client
          .from('usuarios')
          .select('id_usuario, nombre, apellidos, id_sucursal')
          .eq('rol', 'mecanico')
          .eq('activo', true)
          .order('nombre'),
    ]);

    return {
      'vehiculos': resultados[0],
      'sucursales': resultados[1],
      'mecanicos': resultados[2],
    };
  }

  Future<Map<String, dynamic>> crearTicket({
    required String idVehiculo,
    required String idSucursal,
    required String motivoIngreso,
    String? idMecanicoRevision,
  }) async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw StateError('No hay una sesión activa.');
    }

    return await _client
        .from('tickets')
        .insert({
          'id_vehiculo': idVehiculo,
          'id_sucursal': idSucursal,
          'id_administrador': usuario.id,
          'id_mecanico_revision': idMecanicoRevision,
          'motivo_ingreso': motivoIngreso.trim(),
          'estado': 'recibido',
        })
        .select('id_ticket, folio')
        .single();
  }

  static String nombrePersona(Map<String, dynamic> persona) {
    final nombre = '${persona['nombre'] ?? ''} ${persona['apellidos'] ?? ''}'
        .trim();

    return nombre.isEmpty ? 'Sin nombre registrado' : nombre;
  }

  static String mensajeError(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501':
          return 'Tu cuenta no tiene permiso para realizar esta operación.';
        case '23503':
          return 'Uno de los registros seleccionados ya no está disponible. '
              'Vuelve a cargar las opciones.';
        case '23514':
          return 'Revisa los datos del ticket.';
        case 'PGRST116':
          return 'El registro cambió o ya no está disponible. Actualiza la pantalla e inténtalo otra vez.';
        case 'P0001':
          return error.message;
      }
    }

    return 'No se pudo completar la operación. '
        'Revisa tu conexión e inténtalo otra vez.';
  }
}
