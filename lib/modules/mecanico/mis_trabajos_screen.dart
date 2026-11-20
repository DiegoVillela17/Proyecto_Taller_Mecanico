import '../../shared/widgets/foto_vehiculo.dart';
import '../../shared/widgets/encabezado_seccion.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/tickets_service.dart';

class MisTrabajosScreen extends StatefulWidget {
  const MisTrabajosScreen({super.key});

  @override
  State<MisTrabajosScreen> createState() => _MisTrabajosScreenState();
}

class _MisTrabajosScreenState extends State<MisTrabajosScreen> {
  final _client = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _trabajos;

  String _busqueda = '';
  String _filtro = 'Todos';

  @override
  void initState() {
    super.initState();
    _trabajos = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    final usuario = _client.auth.currentUser;

    if (usuario == null) {
      throw StateError('No hay una sesión activa.');
    }

    final servicios = await _client
        .from('detalle_ticket')
        .select(
          'id_detalle, descripcion_trabajo, observaciones, '
          'fecha_inicio, fecha_fin, '
          'servicio:servicios(nombre), '
          'ticket:tickets('
          'folio, motivo_ingreso, diagnostico, '
          'vehiculo:vehiculos(marca, modelo, anio, placas, foto_path), '
          'sucursal:sucursales(nombre)'
          ')',
        )
        .eq('id_mecanico', usuario.id)
        .order('creado_en', ascending: false);
    final revisiones = await _client
        .from('tickets')
        .select(
          'id_ticket,folio,motivo_ingreso,diagnostico,estado,fecha_recibido,fecha_finalizado,'
          'vehiculo:vehiculos(marca,modelo,anio,placas,foto_path),sucursal:sucursales(nombre)',
        )
        .eq('id_mecanico_revision', usuario.id)
        .order('creado_en', ascending: false);
    return [
      ...revisiones.map(
        (t) => <String, dynamic>{
          'ticket': t,
          'servicio': {'nombre': 'Revisión inicial'},
          'descripcion_trabajo': t['motivo_ingreso'],
          'observaciones': t['diagnostico'],
          'fecha_inicio': null,
          'fecha_fin': null,
          'es_revision': true,
        },
      ),
      ...servicios,
    ];
  }

  Future<void> _recargar() async {
    final consulta = _consultar();

    setState(() => _trabajos = consulta);

    try {
      await consulta;
    } catch (_) {}
  }

  String _avance(Map<String, dynamic> trabajo) {
    if (trabajo['es_revision'] == true) {
      final estado = (trabajo['ticket'] as Map<String, dynamic>)['estado'];
      return estado == 'recibido'
          ? 'Pendiente'
          : estado == 'en_revision'
          ? 'En proceso'
          : 'Finalizado';
    }
    if (trabajo['fecha_fin'] != null) {
      return 'Finalizado';
    }
    if (trabajo['fecha_inicio'] != null) {
      return 'En proceso';
    }

    return 'Pendiente';
  }

  String _fecha(dynamic valor) {
    if (valor == null) {
      return 'Sin registrar';
    }

    final fecha = DateTime.tryParse(valor.toString())?.toLocal();

    if (fecha == null) {
      return 'Sin registrar';
    }

    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  bool _coincide(Map<String, dynamic> trabajo) {
    final ticket = trabajo['ticket'] as Map<String, dynamic>?;
    final vehiculo = ticket?['vehiculo'] as Map<String, dynamic>?;
    final servicio = trabajo['servicio'] as Map<String, dynamic>?;

    final texto = [
      ticket?['folio'],
      vehiculo?['placas'],
      vehiculo?['marca'],
      vehiculo?['modelo'],
      servicio?['nombre'],
    ].join(' ').toLowerCase();

    final coincideBusqueda = texto.contains(_busqueda.trim().toLowerCase());

    final coincideFiltro = _filtro == 'Todos' || _avance(trabajo) == _filtro;

    return coincideBusqueda && coincideFiltro;
  }

  Widget _dato(String etiqueta, Object? valor) {
    final texto = valor?.toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(texto == null || texto.isEmpty ? 'Sin registrar' : texto),
        ],
      ),
    );
  }

  void _abrirDetalle(Map<String, dynamic> trabajo) {
    final ticket = trabajo['ticket'] as Map<String, dynamic>?;
    final vehiculo = ticket?['vehiculo'] as Map<String, dynamic>?;
    final sucursal = ticket?['sucursal'] as Map<String, dynamic>?;
    final servicio = trabajo['servicio'] as Map<String, dynamic>?;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        servicio?['nombre']?.toString() ?? 'Trabajo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar detalle',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _dato('Ticket', '#${ticket?['folio'] ?? '—'}'),
                _dato(
                  'Vehículo',
                  '${vehiculo?['marca'] ?? ''} '
                      '${vehiculo?['modelo'] ?? ''}',
                ),
                if (vehiculo?['foto_path'] != null)
                  FotoVehiculo(path: vehiculo!['foto_path'] as String),
                _dato('Año', vehiculo?['anio']),
                _dato('Placas', vehiculo?['placas']),
                _dato('Sucursal', sucursal?['nombre']),
                _dato('Avance del servicio', _avance(trabajo)),
                const Divider(),
                const SizedBox(height: 16),
                _dato('Motivo de ingreso', ticket?['motivo_ingreso']),
                _dato('Diagnóstico', ticket?['diagnostico']),
                _dato('Trabajo asignado', trabajo['descripcion_trabajo']),
                _dato('Observaciones', trabajo['observaciones']),
                if (trabajo['es_revision'] != true) ...[
                  _dato('Inicio', _fecha(trabajo['fecha_inicio'])),
                  _dato('Finalización', _fecha(trabajo['fecha_fin'])),
                ] else
                  const Text(
                    'El avance de la revisión corresponde al estado del ticket.',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoSeccion(
                titulo: 'Mis trabajos',
                descripcion: 'Organiza tus servicios y revisa su avance.',
                icono: Icons.handyman_rounded,
                accion: IconButton.filledTonal(
                  tooltip: 'Actualizar trabajos',
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por folio, placas o servicio',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => _busqueda = value);
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Todos', 'Pendiente', 'En proceso', 'Finalizado']
                      .map((filtro) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filtro),
                            selected: _filtro == filtro,
                            onSelected: (_) {
                              setState(() => _filtro = filtro);
                            },
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _trabajos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TicketsService.mensajeError(snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _recargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final todos = snapshot.data ?? [];
              final resultados = todos.where(_coincide).toList();

              if (resultados.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      todos.isEmpty
                          ? 'Todavía no tienes servicios asignados.'
                          : 'No hay trabajos que coincidan '
                                'con la búsqueda y el filtro.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _recargar,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: resultados.length,
                  separatorBuilder: (_, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final trabajo = resultados[index];
                    final ticket = trabajo['ticket'] as Map<String, dynamic>?;
                    final vehiculo =
                        ticket?['vehiculo'] as Map<String, dynamic>?;
                    final servicio =
                        trabajo['servicio'] as Map<String, dynamic>?;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _abrirDetalle(trabajo),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colores.primaryContainer,
                                    child: Icon(
                                      Icons.build_outlined,
                                      color: colores.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      servicio?['nombre']?.toString() ??
                                          'Servicio',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ticket #${ticket?['folio'] ?? '—'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Sucursal: ${(ticket?['sucursal'] as Map<String, dynamic>?)?['nombre'] ?? 'Sin información'}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${vehiculo?['marca'] ?? ''} '
                                '${vehiculo?['modelo'] ?? ''}',
                              ),
                              Text('Placas: ${vehiculo?['placas'] ?? '—'}'),
                              const SizedBox(height: 12),
                              Chip(label: Text(_avance(trabajo))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
