import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/auth_service.dart';
import '../ajustes/ajustes_screen.dart';
import '../../modules/mapa/mapa_screens.dart';
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

class _Destino {
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;

  const _Destino({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.pantalla,
  });
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

  // Tutorial (showcaseview).
  final _claveTitulo = GlobalKey();
  final _claveAjustes = GlobalKey();
  final _claveActualizar = GlobalKey();
  final _claveSalir = GlobalKey();
  final _clavesDestinos = <String, GlobalKey>{};
  String? _rol;

  GlobalKey _claveDestino(String etiqueta) {
    return _clavesDestinos.putIfAbsent(etiqueta, () => GlobalKey());
  }

  @override
  void initState() {
    super.initState();

    ShowcaseView.register();

    _perfil = _auth.obtenerPerfil();

    // Cuando carga el perfil se sabe el rol; si el usuario es nuevo
    // se muestra el tutorial automáticamente.
    _perfil.then((perfil) {
      _rol = perfil['rol'] as String?;
      return _tutorialSiEsNuevo();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    ShowcaseView.get().unregister();
    super.dispose();
  }

  Future<void> _tutorialSiEsNuevo() async {
    final idUsuario = Supabase.instance.client.auth.currentUser?.id;

    if (idUsuario == null) return;

    final prefs = await SharedPreferences.getInstance();
    final clave = 'tutorial_visto_$idUsuario';

    if (prefs.getBool(clave) ?? false) return;

    // Se marca como visto al iniciarlo, así no se repite en cada sesión.
    await prefs.setBool(clave, true);

    _iniciarTutorial();
  }

  Future<void> _iniciarTutorial() async {
    final rol = _rol;

    if (rol == null) return;

    // Pequeña espera para que termine de construirse la pantalla
    // (o la animación al volver desde Ajustes).
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final destinos = _destinos(rol);

    ShowcaseView.get().startShowCase([
      _claveTitulo,
      if (destinos.length > 1)
        for (final destino in destinos) _claveDestino(destino.etiqueta),
      _claveAjustes,
      _claveActualizar,
      _claveSalir,
    ]);
  }

  String _descripcionDestino(String rol, String etiqueta) {
    switch (etiqueta) {
      case 'Vehículos':
        return rol == 'administrador'
            ? 'Consulta, agrega y edita los vehículos de los clientes.'
            : 'Consulta la información de tus vehículos y sus servicios.';
      case 'Tickets':
        return rol == 'administrador'
            ? 'Revisa los tickets de ingreso, sus servicios y su estado.'
            : 'Consulta el estado, los servicios y el costo de los '
                'tickets de tus vehículos.';
      case 'Mis trabajos':
        return 'Consulta los servicios que tienes asignados.';
      case 'Talleres':
        return 'Mira en el mapa tu ubicación y los talleres cercanos. '
            'Toca uno para ver su información.';
      default:
        return '';
    }
  }

  // Envuelve un widget con un paso del tutorial usando los colores del tema.
  Widget _paso({
    required GlobalKey clave,
    required String titulo,
    required String descripcion,
    required Widget hijo,
  }) {
    final colores = Theme.of(context).colorScheme;

    return Showcase(
      key: clave,
      title: titulo,
      description: descripcion,
      tooltipBackgroundColor: colores.surface,
      textColor: colores.onSurface,
      child: hijo,
    );
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

  // Botones de la barra inferior según el rol.
  List<_Destino> _destinos(String rol) {
    const talleres = _Destino(
      etiqueta: 'Talleres',
      icono: Icons.map_outlined,
      iconoActivo: Icons.map,
      pantalla: MapaScreen(key: ValueKey('mapa')),
    );

    switch (rol) {
      case 'administrador':
        return const [
          _Destino(
            etiqueta: 'Vehículos',
            icono: Icons.directions_car_outlined,
            iconoActivo: Icons.directions_car,
            pantalla: VehiculosScreen(
              key: ValueKey('vehiculos_admin'),
              esAdministrador: true,
            ),
          ),
          _Destino(
            etiqueta: 'Tickets',
            icono: Icons.receipt_long_outlined,
            iconoActivo: Icons.receipt_long,
            pantalla: TicketsScreen(key: ValueKey('tickets_admin')),
          ),
          talleres,
        ];

      case 'cliente':
        return const [
          _Destino(
            etiqueta: 'Vehículos',
            icono: Icons.directions_car_outlined,
            iconoActivo: Icons.directions_car,
            pantalla: VehiculosScreen(
              key: ValueKey('vehiculos_cliente'),
              esAdministrador: false,
            ),
          ),
          talleres,
          _Destino(
            etiqueta: 'Tickets',
            icono: Icons.receipt_long_outlined,
            iconoActivo: Icons.receipt_long,
            pantalla: TicketsScreen(
              key: ValueKey('tickets_cliente'),
              soloLectura: true,
            ),
          ),
        ];

      case 'mecanico':
        return const [
          _Destino(
            etiqueta: 'Mis trabajos',
            icono: Icons.build_outlined,
            iconoActivo: Icons.build,
            pantalla: MisTrabajosScreen(key: ValueKey('trabajos_mecanico')),
          ),
          talleres,
        ];

      default:
        return const [];
    }
  }

  Widget _contenido(List<_Destino> destinos) {
    if (destinos.isEmpty) {
      return const Center(
        child: Text('Acceso denegado: el rol no es válido.'),
      );
    }

    final indice = _pestana < destinos.length ? _pestana : 0;

    return destinos[indice].pantalla;
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

        final destinos = rol == null ? <_Destino>[] : _destinos(rol);

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
          contenido = _contenido(destinos);
        }

        return Scaffold(
          appBar: AppBar(
            title: _paso(
              clave: _claveTitulo,
              titulo: '¡Bienvenido a Mi Taller!',
              descripcion: 'Aquí ves tu nombre y tu rol. '
                  'Te mostramos rápido cómo usar la aplicación.',
              hijo: Column(
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
            ),
            actions: [
              _paso(
                clave: _claveAjustes,
                titulo: 'Ajustes',
                descripcion: 'Cambia entre modo claro y oscuro y '
                    'vuelve a ver este tutorial cuando quieras.',
                hijo: IconButton(
                  tooltip: 'Ajustes',
                  onPressed: () async {
                    final verTutorial =
                        await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const AjustesScreen(),
                      ),
                    );

                    if (verTutorial == true) {
                      _iniciarTutorial();
                    }
                  },
                  icon: const Icon(Icons.settings),
                ),
              ),
              _paso(
                clave: _claveActualizar,
                titulo: 'Actualizar perfil',
                descripcion: 'Vuelve a cargar tu perfil y tu rol '
                    'si algo cambió.',
                hijo: IconButton(
                  tooltip: 'Actualizar perfil',
                  onPressed: cargando ? null : _recargarPerfil,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              _paso(
                clave: _claveSalir,
                titulo: 'Cerrar sesión',
                descripcion: 'Sal de tu cuenta cuando termines.',
                hijo: IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: _cerrando ? null : _salir,
                  icon: const Icon(Icons.logout),
                ),
              ),
            ],
          ),
          body: SafeArea(child: contenido),
          bottomNavigationBar: destinos.length > 1
              ? NavigationBar(
                  selectedIndex:
                      _pestana < destinos.length ? _pestana : 0,
                  onDestinationSelected: (index) {
                    setState(() => _pestana = index);
                  },
                  destinations: [
                    for (final destino in destinos)
                      _paso(
                        clave: _claveDestino(destino.etiqueta),
                        titulo: destino.etiqueta,
                        descripcion: _descripcionDestino(
                          rol ?? '',
                          destino.etiqueta,
                        ),
                        hijo: NavigationDestination(
                          icon: Icon(destino.icono),
                          selectedIcon: Icon(destino.iconoActivo),
                          label: destino.etiqueta,
                        ),
                      ),
                  ],
                )
              : null,
        );
      },
    );
  }
}