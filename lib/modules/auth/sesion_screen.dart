import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/auth_service.dart';
import '../mecanico/mis_trabajos_screen.dart';
import '../tickets/tickets_screen.dart';
import '../vehiculos/vehiculos_screen.dart';
import 'acceso_screen.dart';

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
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    _perfil = _auth.obtenerPerfil();
  }

  void _recargarPerfil() {
    setState(() {
      _pestana = 0;
      _perfil = _auth.obtenerPerfil();
    });
  }

  Future<void> _salir() async {
    if (_cerrando) return;

    setState(() => _cerrando = true);

    try {
      await _auth.cerrarSesion();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cerrar la sesión. Inténtalo otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cerrando = false);
      }
    }
  }

  Widget _contenido(String rol) {
    switch (rol) {
      case 'administrador':
        if (_pestana == 0) {
          return const VehiculosScreen(
            key: ValueKey('vehiculos_admin'),
            esAdministrador: true,
          );
        }

        return const TicketsScreen(
          key: ValueKey('tickets_admin'),
        );

      case 'cliente':
        return const VehiculosScreen(
          key: ValueKey('vehiculos_cliente'),
          esAdministrador: false,
        );

      case 'mecanico':
        return const MisTrabajosScreen(
          key: ValueKey('trabajos_mecanico'),
        );

      default:
        return const Center(
          child: Text('Acceso denegado: el rol no es válido.'),
        );
    }
  }

  String _nombreRol(String rol) {
    switch (rol) {
      case 'administrador':
        return 'Administrador';
      case 'mecanico':
        return 'Mecánico';
      case 'cliente':
        return 'Cliente';
      default:
        return 'Sin acceso';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _perfil,
      builder: (context, snapshot) {
        final cargando =
            snapshot.connectionState != ConnectionState.done;

        final perfil = !cargando && !snapshot.hasError
            ? snapshot.data
            : null;

        final rol = perfil?['rol'] as String?;

        final nombre = [
          perfil?['nombre'] ?? '',
          perfil?['apellidos'] ?? '',
        ].join(' ').trim();

        Widget contenido;

        if (cargando) {
          contenido = const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError || perfil == null) {
          contenido = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudo cargar tu perfil. '
                    'Revisa tu conexión e inténtalo otra vez.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _recargarPerfil,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        } else {
          contenido = _contenido(rol ?? '');
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mi Taller'),
                if (rol != null)
                  Text(
                    nombre.isEmpty
                        ? _nombreRol(rol)
                        : '$nombre · ${_nombreRol(rol)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar perfil',
                onPressed: cargando ? null : _recargarPerfil,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _cerrando ? null : _salir,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: SafeArea(child: contenido),
          bottomNavigationBar: rol == 'administrador'
              ? NavigationBar(
                  selectedIndex: _pestana,
                  onDestinationSelected: (index) {
                    setState(() => _pestana = index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.directions_car_outlined),
                      selectedIcon: Icon(Icons.directions_car),
                      label: 'Vehículos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Tickets',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}