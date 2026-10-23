import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  Session? get sesion => _client.auth.currentSession;

  Stream<AuthState> get cambiosSesion => _client.auth.onAuthStateChange;

  Future<void> iniciarSesion(String correo, String password) async {
    await _client.auth.signInWithPassword(
      email: correo.trim(),
      password: password,
    );
  }

  Future<AuthResponse> registrar({
    required String nombre,
    required String apellidos,
    required String telefono,
    required String correo,
    required String password,
  }) {
    return _client.auth.signUp(
      email: correo.trim(),
      password: password,
      data: {
        'nombre': nombre.trim(),
        'apellidos': apellidos.trim(),
        'telefono': telefono.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> obtenerPerfil() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw StateError('No hay una sesión activa.');
    }

    final perfil = await _client
        .from('usuarios')
        .select('id_usuario, nombre, apellidos, telefono, rol')
        .eq('id_usuario', usuario.id)
        .maybeSingle();

    if (perfil == null) {
      throw StateError('No se encontró el perfil del usuario.');
    }

    return perfil;
  }

  Future<void> cerrarSesion() async {
    await _client.auth.signOut();
  }

  static String mensajeError(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'El correo o la contraseña son incorrectos.';
        case 'email_not_confirmed':
          return 'Confirma tu correo antes de iniciar sesión.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Ya existe una cuenta con ese correo.';
        case 'weak_password':
          return 'La contraseña no cumple los requisitos de seguridad.';
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return 'Demasiados intentos. Espera unos minutos.';
        case 'signup_disabled':
          return 'El registro de cuentas está deshabilitado.';
        default:
          return 'No se pudo completar el acceso. Revisa tus datos e inténtalo otra vez.';
      }
    }

    return 'No se pudo conectar. Revisa tu conexión e inténtalo otra vez.';
  }
}