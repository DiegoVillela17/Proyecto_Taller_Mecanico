import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/auth_service.dart';
import 'acceso_screen.dart';

import '../vehiculos/vehiculos_screen.dart';

class SesionScreen extends StatefulWidget {
  const SesionScreen({super.key});

  @override
  State<SesionScreen> createState() => _SesionScreenState();
}

class _SesionScreenState extends State<SesionScreen> {
  final _auth = AuthService();
  late final Stream<AuthState> _eventos;

  @override
  void initState() {
    super.initState();
    _eventos = _auth.cambiosSesion;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _eventos,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo actualizar la sesión. '
                  'Revisa tu conexión y vuelve a abrir la aplicación.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final sesion = _auth.sesion;

        if (sesion == null) {
          return const AccesoScreen();
        }

        return InicioRolScreen(
          key: ValueKey(sesion.user.id),
        );
      },
    );
  }
}

class InicioRolScreen extends StatefulWidget {
  const InicioRolScreen({super.key});

  @override
  State<InicioRolScreen> createState() => _InicioRolScreenState();
}

class _InicioRolScreenState extends State<InicioRolScreen> {
  final _auth = AuthService();
  late Future<Map<String, dynamic>> _perfil;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _perfil = _auth.obtenerPerfil();
  }

  void _recargar() {
    setState(() {
      _perfil = _auth.obtenerPerfil();
    });
  }

  Future<void> _salir() async {
    setState(() => _cerrando = true);

    try {
      await _auth.cerrarSesion();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la sesión. Inténtalo otra vez.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cerrando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Taller'),
        actions: [
          IconButton(
            tooltip: 'Actualizar perfil',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrando ? null : _salir,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _perfil,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo cargar tu perfil. '
                      'Comprueba tu conexión y que exista tu registro '
                      'en la tabla usuarios.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _recargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final perfil = snapshot.data!;
          final rol = perfil['rol'] as String?;
          if (rol == 'administrador' || rol == 'cliente') {
          return VehiculosScreen(
            key: ValueKey('${perfil['id_usuario']}-$rol'),
            esAdministrador: rol == 'administrador',
          );
        }
          final nombre =
              '${perfil['nombre'] ?? ''} ${perfil['apellidos'] ?? ''}'.trim();

          final String titulo;
          final String descripcion;
          final IconData icono;

          switch (rol) {
            case 'administrador':
              titulo = 'Panel del administrador';
              descripcion =
                  'Desde este perfil gestionarás vehículos, tickets, '
                  'servicios, precios y asignaciones.';
              icono = Icons.admin_panel_settings_outlined;
              break;
            case 'mecanico':
              titulo = 'Panel del mecánico';
              descripcion =
                  'Desde este perfil consultarás los trabajos '
                  'y las revisiones que tienes asignados.';
              icono = Icons.build_outlined;
              break;
            case 'cliente':
              titulo = 'Panel del cliente';
              descripcion =
                  'Desde este perfil consultarás tus vehículos, '
                  'servicios y el avance de tus tickets.';
              icono = Icons.directions_car_outlined;
              break;
            default:
              return const Center(
                child: Text('Acceso denegado: el rol no es válido.'),
              );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icono,
                          size: 64,
                          color: const Color(0xFF1565C0),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          nombre.isEmpty ? 'Bienvenido' : 'Hola, $nombre',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          descripcion,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const Chip(
                          avatar: Icon(Icons.check_circle_outline),
                          label: Text('Cuenta conectada'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}