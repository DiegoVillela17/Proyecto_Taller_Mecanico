import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/tickets_service.dart';
import 'ticket_detalle_screen.dart';
import 'ticket_form_screen.dart';

class TicketsScreen extends StatefulWidget {
  // En modo solo lectura (clientes) no se pueden crear tickets.
  final bool soloLectura;

  const TicketsScreen({super.key, this.soloLectura = false});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _tickets;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _tickets = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    return await _client
        .from('tickets')
        .select(
          'id_ticket, folio, estado, motivo_ingreso, '
          'vehiculo:vehiculos(marca, modelo, placas), '
          'sucursal:sucursales(nombre)',
        )
        .order('folio', ascending: false);
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
    final ticket =
        await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const TicketFormScreen(),
      ),
    );

    if (!mounted || ticket == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ticket #${ticket['folio']} creado.'),
      ),
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
                        onPressed: _crear,
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
                        ? 'Todavía no hay tickets registrados.'
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          'Ticket #${ticket['folio']} · '
                          '${vehiculo?['placas'] ?? ''}',
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${vehiculo?['marca'] ?? ''} '
                            '${vehiculo?['modelo'] ?? ''}\n'
                            '${sucursal?['nombre'] ?? ''}\n'
                            'Estado: ${ticket['estado'].toString().replaceAll('_', ' ')}',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrirDetalle(
                          ticket['id_ticket'] as String,
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