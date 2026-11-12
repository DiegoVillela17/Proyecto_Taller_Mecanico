import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Taller {
  final String id;
  final String nombre;
  final String direccion;
  final String? telefono;
  final LatLng punto;
  double? distanciaMetros;

  _Taller({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.punto,
  });
}

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  static const _centroPorDefecto = LatLng(22.1565, -100.9855);
  static const _distanciaMaximaCentrado = 50000.0;

  final _client = Supabase.instance.client;
  final _mapa = MapController();

  List<_Taller> _talleres = [];
  LatLng? _miUbicacion;
  String? _errorTalleres;
  String? _avisoUbicacion;
  String? _seleccionado;

  // Ruta "cómo llegar".
  List<LatLng> _ruta = [];
  String? _rutaDestino;
  double? _rutaMetros;
  double? _rutaSegundos;
  bool _calculandoRuta = false;

  bool _cargandoTalleres = true;
  bool _buscandoUbicacion = false;
  bool _mapaListo = false;
  bool _centradoInicial = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  double? _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse('$valor');
  }

  Future<void> _cargar() async {
    setState(() {
      _cargandoTalleres = true;
      _errorTalleres = null;
      _mapaListo = false;
      _centradoInicial = false;
    });

    // La ubicación se busca en paralelo a la consulta de talleres.
    final ubicacion = _obtenerUbicacion();

    try {
      final filas = await _client
          .from('sucursales')
          .select('id_sucursal, nombre, direccion, latitud, longitud, telefono')
          .order('nombre');

      final talleres = <_Taller>[];

      for (final fila in filas) {
        final lat = _numero(fila['latitud']);
        final lng = _numero(fila['longitud']);

        if (lat == null || lng == null) continue;

        talleres.add(
          _Taller(
            id: fila['id_sucursal'] as String,
            nombre: (fila['nombre'] ?? '') as String,
            direccion: (fila['direccion'] ?? '') as String,
            telefono: fila['telefono'] as String?,
            punto: LatLng(lat, lng),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _talleres = talleres;
        _cargandoTalleres = false;
      });

      _calcularDistancias();
      _centrarInicial();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorTalleres =
            'No se pudieron cargar los talleres. Revisa tu conexión e inténtalo otra vez.';
        _cargandoTalleres = false;
      });
    }

    await ubicacion;
  }

  Future<void> _obtenerUbicacion() async {
    if (mounted) {
      setState(() {
        _buscandoUbicacion = true;
        _avisoUbicacion = null;
      });
    }

    LatLng? punto;
    String? aviso;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        aviso = 'Activa el GPS del dispositivo para ver tu ubicación.';
      } else {
        var permiso = await Geolocator.checkPermission();

        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }

        if (permiso == LocationPermission.denied) {
          aviso = 'Sin permiso de ubicación: solo se muestran los talleres.';
        } else if (permiso == LocationPermission.deniedForever) {
          aviso = 'El permiso de ubicación está bloqueado. '
              'Actívalo en los ajustes del dispositivo.';
        } else {
          final posicion = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );

          punto = LatLng(posicion.latitude, posicion.longitude);
        }
      }
    } catch (_) {
      aviso = 'No se pudo obtener tu ubicación. Inténtalo otra vez.';
    }

    if (!mounted) return;

    setState(() {
      _miUbicacion = punto ?? _miUbicacion;
      _avisoUbicacion = aviso;
      _buscandoUbicacion = false;
    });

    _calcularDistancias();
    _centrarInicial();
  }

  void _calcularDistancias() {
    final mia = _miUbicacion;

    if (mia == null || _talleres.isEmpty) return;

    setState(() {
      for (final taller in _talleres) {
        taller.distanciaMetros = Geolocator.distanceBetween(
          mia.latitude,
          mia.longitude,
          taller.punto.latitude,
          taller.punto.longitude,
        );
      }
    });
  }

  // Centra una sola vez: en tu ubicación si hay talleres a menos de 50 km;
  // si no, en el taller más cercano.
  void _centrarInicial() {
    if (_centradoInicial || !_mapaListo) return;

    final mia = _miUbicacion;

    if (mia == null || _talleres.isEmpty) return;

    _centradoInicial = true;

    final cercano = _ordenados.first;
    final distancia = cercano.distanciaMetros ?? double.infinity;

    if (distancia <= _distanciaMaximaCentrado) {
      _mapa.move(mia, 14);
    } else {
      _mapa.move(cercano.punto, 14);
    }
  }

  Future<void> _irAMiUbicacion() async {
    await _obtenerUbicacion();

    final mia = _miUbicacion;

    if (mia != null && mounted) {
      _mapa.move(mia, 15);
    }
  }

  List<_Taller> get _ordenados {
    final lista = [..._talleres];

    lista.sort((a, b) {
      final da = a.distanciaMetros;
      final db = b.distanciaMetros;

      if (da == null || db == null) return a.nombre.compareTo(b.nombre);

      return da.compareTo(db);
    });

    return lista;
  }

  String _formatoDistancia(double? metros) {
    if (metros == null) return 'Distancia no disponible';
    if (metros < 1000) return '${metros.round()} m';

    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  void _mensaje(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  String _formatoDuracion(double? segundos) {
    if (segundos == null) return '';

    final minutos = (segundos / 60).round();

    if (minutos < 1) return 'menos de 1 min';
    if (minutos < 60) return '$minutos min';

    final horas = minutos ~/ 60;
    final resto = minutos % 60;

    return resto == 0 ? '$horas h' : '$horas h $resto min';
  }

  void _limpiarRuta() {
    setState(() {
      _ruta = [];
      _rutaDestino = null;
      _rutaMetros = null;
      _rutaSegundos = null;
    });
  }

  // Calcula la ruta en coche con OSRM. El motor de rutas usa las calles de
  // OpenStreetMap, así que respeta sentidos de circulación y giros
  // prohibidos.
  Future<void> _comoLlegar(_Taller taller) async {
    if (_calculandoRuta) return;

    if (_miUbicacion == null) {
      await _obtenerUbicacion();
    }

    final origen = _miUbicacion;

    if (origen == null) {
      _mensaje(
        _avisoUbicacion ??
            'Necesitamos tu ubicación para calcular la ruta.',
      );
      return;
    }

    setState(() => _calculandoRuta = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origen.longitude},${origen.latitude};'
        '${taller.punto.longitude},${taller.punto.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final respuesta = await http.get(url).timeout(
            const Duration(seconds: 15),
          );

      if (respuesta.statusCode != 200) {
        throw Exception('OSRM ${respuesta.statusCode}');
      }

      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final rutas = datos['routes'] as List<dynamic>?;

      if (datos['code'] != 'Ok' || rutas == null || rutas.isEmpty) {
        _mensaje('No se encontró una ruta hasta este taller.');
        return;
      }

      final ruta = rutas.first as Map<String, dynamic>;
      final coordenadas =
          (ruta['geometry'] as Map<String, dynamic>)['coordinates']
              as List<dynamic>;

      final puntos = [
        for (final c in coordenadas)
          LatLng(
            ((c as List<dynamic>)[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
      ];

      if (!mounted) return;

      setState(() {
        _ruta = puntos;
        _rutaDestino = taller.nombre;
        _rutaMetros = (ruta['distance'] as num).toDouble();
        _rutaSegundos = (ruta['duration'] as num).toDouble();
        _seleccionado = taller.id;
      });

      _mapa.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(puntos),
          padding: const EdgeInsets.fromLTRB(40, 90, 40, 40),
        ),
      );
    } catch (_) {
      _mensaje(
        'No se pudo calcular la ruta. Revisa tu conexión e inténtalo '
        'otra vez.',
      );
    } finally {
      if (mounted) {
        setState(() => _calculandoRuta = false);
      }
    }
  }

  void _seleccionar(_Taller taller) {
    setState(() => _seleccionado = taller.id);
    _mapa.move(taller.punto, 15);
    _mostrarDetalle(taller);
  }

  Widget _fila(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  void _mostrarDetalle(_Taller taller) {
    final telefono = taller.telefono?.trim();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taller.nombre,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _fila(Icons.place_outlined, taller.direccion),
                _fila(
                  Icons.straighten,
                  _formatoDistancia(taller.distanciaMetros),
                ),
                _fila(
                  Icons.phone_outlined,
                  telefono == null || telefono.isEmpty
                      ? 'Teléfono sin registrar'
                      : telefono,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _comoLlegar(taller);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _panelTalleres(List<_Taller> talleres) {
    final colores = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Talleres cercanos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 140,
          child: talleres.isEmpty
              ? const Center(
                  child: Text('Todavía no hay talleres registrados.'),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: talleres.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(width: 10);
                  },
                  itemBuilder: (context, index) {
                    final taller = talleres[index];
                    final activo = taller.id == _seleccionado;

                    return SizedBox(
                      width: 250,
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: activo ? colores.primaryContainer : null,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _seleccionar(taller),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.car_repair, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        taller.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatoDistancia(taller.distanciaMetros),
                                  style: TextStyle(
                                    color: colores.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  taller.direccion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoTalleres) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorTalleres != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorTalleres!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final colores = Theme.of(context).colorScheme;
    final ordenados = _ordenados;

    return Column(
      children: [
        if (_avisoUbicacion != null)
          Container(
            width: double.infinity,
            color: colores.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.location_off,
                  size: 18,
                  color: colores.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avisoUbicacion!,
                    style: TextStyle(
                      color: colores.onSecondaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: _talleres.isNotEmpty
                      ? _talleres.first.punto
                      : _centroPorDefecto,
                  initialZoom: 13,
                  onMapReady: () {
                    _mapaListo = true;
                    _centrarInicial();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'taller_app',
                  ),
                  if (_ruta.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _ruta,
                          strokeWidth: 6,
                          color: colores.primary,
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final taller in _talleres)
                        Marker(
                          point: taller.punto,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _seleccionar(taller),
                            child: Icon(
                              Icons.location_on,
                              size: 44,
                              color: taller.id == _seleccionado
                                  ? colores.primary
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      if (_miUbicacion != null)
                        Marker(
                          point: _miUbicacion!,
                          width: 22,
                          height: 22,
                          child: const _PuntoUsuario(),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: 'mi_ubicacion',
                  tooltip: 'Mi ubicación',
                  onPressed: _buscandoUbicacion ? null : _irAMiUbicacion,
                  child: _buscandoUbicacion
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
              if (_calculandoRuta)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_ruta.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 64,
                  top: 12,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _rutaDestino ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_formatoDuracion(_rutaSegundos)} · '
                                  '${_formatoDistancia(_rutaMetros)}',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar ruta',
                            onPressed: _limpiarRuta,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _panelTalleres(ordenados),
      ],
    );
  }
}

class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black38),
        ],
      ),
    );
  }
}