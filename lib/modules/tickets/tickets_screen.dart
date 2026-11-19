import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/tickets_service.dart';
import '../../shared/widgets/foto_vehiculo.dart';
import 'ticket_detalle_screen.dart';
import 'ticket_form_screen.dart';

class TicketsScreen extends StatefulWidget {
  // En modo solo lectura (clientes) no se pueden crear tickets.
  final bool soloLectura;
  final String? idSucursal;

  const TicketsScreen({super.key, this.soloLectura = false, this.idSucursal});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _tickets;
  String _busqueda = '';
  String? _idSucursal;
  List<Map<String, dynamic>> _sucursales = [];

  bool get _mostrarSelector => !widget.soloLectura && widget.idSucursal == null;

  @override
  void initState() {
    super.initState();
    _idSucursal = widget.idSucursal;
    _tickets = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    String? sucursal = widget.idSucursal;
    if (_mostrarSelector) {
      final lista = await _client
          .from('sucursales')
          .select('id_sucursal, nombre')
          .order('nombre');
      if (!mounted) {
        return [];
      }
      sucursal = lista.any((s) => s['id_sucursal'] == _idSucursal)
          ? _idSucursal
          : lista.isEmpty
          ? null
          : lista.first['id_sucursal'] as String;
      setState(() {
        _sucursales = lista;
        _idSucursal = sucursal;
      });
      if (sucursal == null) {
        return [];
      }
    }
    var consulta = _client
        .from('tickets')
        .select(
          'id_ticket, folio, estado, motivo_ingreso, '
          'vehiculo:vehiculos(marca, modelo, placas, foto_path), '
          'sucursal:sucursales(nombre)',
        );
    if (sucursal != null) {
      consulta = consulta.eq('id_sucursal', sucursal);
    }
    return await consulta.order('folio', ascending: false);
  }

  Future<void> _recargar() async {
    final consulta = _consultar();

    setState(() => _tickets = consulta);

    try {
      await consulta;
    } catch (_) {}
  }

  Future<void> _abrirDetalle(String idTicket) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetalleScreen(
          idTicket: idTicket,
          soloLectura: widget.soloLectura,
        ),
      ),
    );

    if (mounted) {
      await _recargar();
    }
  }

  Future<void> _crear() async {
    final ticket = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => TicketFormScreen(idSucursal: _idSucursal),
      ),
    );

    if (!mounted || ticket == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ticket #${ticket['folio']} creado.')),
    );

    await _abrirDetalle(ticket['id_ticket'] as String);
  }

  bool _coincide(Map<String, dynamic> ticket) {
    final vehiculo = ticket['vehiculo'] as Map<String, dynamic>?;

    final texto = [
      ticket['folio'],
      vehiculo?['marca'],
      vehiculo?['modelo'],
      vehiculo?['placas'],
    ].join(' ').toLowerCase();

    return texto.contains(_busqueda.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.soloLectura ? 'Mis tickets' : 'Tickets del taller',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (_mostrarSelector && _sucursales.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_idSucursal),
                  initialValue: _idSucursal,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  items: _sucursales
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id_sucursal'] as String,
                          child: Text(
                            s['nombre'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null || id == _idSucursal) {
                      return;
                    }
                    setState(() {
                      _idSucursal = id;
                      _tickets = _consultar();
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por folio, placas o vehículo',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => _busqueda = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.soloLectura)
                    const Spacer()
                  else
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _idSucursal == null ? null : _crear,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo ticket'),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Actualizar tickets',
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _tickets,
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
                  child: Text(
                    todos.isEmpty
                        ? widget.soloLectura
                              ? 'Todavía no tienes tickets registrados.'
                              : _idSucursal == null
                              ? 'No hay sucursales disponibles.'
                              : 'Todavía no hay tickets en esta sucursal.'
                        : 'No hay resultados para esa búsqueda.',
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
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    final ticket = resultados[index];
                    final vehiculo =
                        ticket['vehiculo'] as Map<String, dynamic>?;
                    final sucursal =
                        ticket['sucursal'] as Map<String, dynamic>?;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            _abrirDetalle(ticket['id_ticket'] as String),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final anchoFoto = (constraints.maxWidth * 0.28)
                                  .clamp(80.0, 160.0)
                                  .toDouble();
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ticket #${ticket['folio']} · ${vehiculo?['placas'] ?? ''}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${vehiculo?['marca'] ?? ''} ${vehiculo?['modelo'] ?? ''}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          sucursal?['nombre']?.toString() ?? '',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Estado: ${ticket['estado'].toString().replaceAll('_', ' ')}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: anchoFoto,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ColoredBox(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        child: FotoVehiculo(
                                          key: ValueKey(ticket['id_ticket']),
                                          path:
                                              vehiculo?['foto_path'] as String?,
                                          altura: anchoFoto * 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
