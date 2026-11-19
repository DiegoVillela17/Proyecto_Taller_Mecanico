import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehiculosService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listar({
    required bool esAdministrador,
  }) async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw StateError('No hay una sesión activa.');
    }

    var consulta = _client
        .from('vehiculos')
        .select(
          'id_vehiculo, id_cliente, marca, modelo, anio, placas, foto_path, actualizado_en, '
          'cliente:usuarios!vehiculos_id_cliente_fkey(nombre, apellidos)',
        );

    if (!esAdministrador) {
      consulta = consulta.eq('id_cliente', usuario.id);
    }

    return await consulta.order('creado_en', ascending: false);
  }

  Future<List<Map<String, dynamic>>> listarClientes() async {
    return await _client
        .from('usuarios')
        .select('id_usuario, nombre, apellidos')
        .eq('rol', 'cliente')
        .order('nombre');
  }

  Future<void> guardar({
    String? idVehiculo,
    required String idCliente,
    required String marca,
    required String modelo,
    required int anio,
    required String placas,
    Uint8List? foto,
    String? tipoFoto,
    String? fotoAnterior,
    String? actualizadoEn,
    bool quitarFoto = false,
  }) async {
    final datos = <String, dynamic>{
      'marca': marca.trim(),
      'modelo': modelo.trim(),
      'anio': anio,
      'placas': placas.trim().toUpperCase(),
    };

    String? nuevaRuta;
    if (foto != null) {
      final extension = tipoFoto == 'image/png'
          ? 'png'
          : tipoFoto == 'image/webp'
          ? 'webp'
          : 'jpg';
      nuevaRuta =
          '${_client.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage
          .from('vehiculos')
          .uploadBinary(
            nuevaRuta,
            foto,
            fileOptions: FileOptions(contentType: tipoFoto, upsert: false),
          );
      datos['foto_path'] = nuevaRuta;
    } else if (quitarFoto) {
      datos['foto_path'] = null;
    }
    try {
      if (idVehiculo == null) {
        datos['id_cliente'] = idCliente;
        await _client
            .from('vehiculos')
            .insert(datos)
            .select('id_vehiculo')
            .single();
      } else {
        var consulta = _client
            .from('vehiculos')
            .update(datos)
            .eq('id_vehiculo', idVehiculo);
        if (actualizadoEn != null) {
          consulta = consulta.eq('actualizado_en', actualizadoEn);
        }
        await consulta.select('id_vehiculo').single();
      }
    } on PostgrestException {
      if (nuevaRuta != null) {
        try {
          await _client.storage.from('vehiculos').remove([nuevaRuta]);
        } catch (_) {}
      }
      rethrow;
    } catch (_) {
      // No borrar el archivo si la respuesta se perdió: podría haberse guardado
      // la referencia. Evita dejar un vehículo apuntando a una foto eliminada.
      rethrow;
    }
    if ((nuevaRuta != null || quitarFoto) && fotoAnterior != null) {
      try {
        await _client.storage.from('vehiculos').remove([fotoAnterior]);
      } catch (_) {
        /* La foto actual ya quedó guardada. */
      }
    }
  }

  static String nombreCliente(Map<String, dynamic>? cliente) {
    if (cliente == null) {
      return 'Cliente sin información';
    }

    final nombre = '${cliente['nombre'] ?? ''} ${cliente['apellidos'] ?? ''}'
        .trim();

    return nombre.isEmpty ? 'Cliente sin nombre' : nombre;
  }

  static String mensajeError(Object error) {
    if (error is StorageException) {
      return 'No se pudo guardar la foto. Usa JPG, PNG o WebP de máximo 5 MB y verifica el almacenamiento.';
    }
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501':
          return 'Tu cuenta no tiene permiso para realizar esta operación.';
        case '23503':
          return 'El registro relacionado ya no está disponible. Actualiza e inténtalo otra vez.';
        case '23514':
          return 'Revisa los datos: alguno no cumple las condiciones del registro.';
        case 'PGRST116':
          return 'El vehículo no está disponible o no tienes permiso para modificarlo.';
      }
    }

    return 'No se pudo completar la operación. Revisa tu conexión e inténtalo otra vez.';
  }
}
