import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/tickets_service.dart';

class TicketDetalleScreen extends StatefulWidget {
  final String idTicket;

  // En modo solo lectura (clientes) no se pueden agregar servicios.
  final bool soloLectura;

  const TicketDetalleScreen({
    super.key,
    required this.idTicket,
    this.soloLectura = false,
  });

  @override
  State<TicketDetalleScreen> createState() => _TicketDetalleScreenState();
}

class _TicketDetalleScreenState extends State<TicketDetalleScreen> {
  final _client = Supabase.instance.client;
  late Future<Map<String, dynamic>> _datos;
  bool _abriendoFormulario = false;

  @override
  void initState() {
    super.initState();
    _datos = _consultar();
  }

  Future<Map<String, dynamic>> _consultar() async {
    final ticket = await _client
        .from('tickets')
        .select(
          '*, '
          'vehiculo:vehiculos(marca, modelo, anio, placas), '
          'sucursal:sucursales(nombre)',
        )
        .eq('id_ticket', widget.idTicket)
        .single();

    final detalles = await _client
        .from('detalle_ticket')
        .select(
          '*, '
          'servicio:servicios(nombre), '
          'mecanico:usuarios!detalle_ticket_id_mecanico_fkey'
          '(nombre, apellidos)',
        )
        .eq('id_ticket', widget.idTicket)
        .order('creado_en');

    return {
      'ticket': ticket,
      'detalles': detalles,
    };
  }

  Future<void> _recargar() async {
    if (!mounted) return;

    final consulta = _consultar();
    setState(() => _datos = consulta);

    try {
      await consulta;
    } catch (_) {}
  }

  String _dinero(dynamic valor) {
    if (valor == null) return 'Por cotizar';
    return '\$${(valor as num).toStringAsFixed(2)} MXN';
  }

  String _fecha(dynamic valor) {
    if (valor == null) return 'Sin registrar';

    final fecha = DateTime.tryParse(valor.toString())?.toLocal();
    if (fecha == null) return 'Sin registrar';

    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> _agregarServicio() async {
    if (_abriendoFormulario) return;

    setState(() => _abriendoFormulario = true);

    try {
      final servicios = await _client
          .from('servicios')
          .select('id_servicio, nombre')
          .eq('activo', true)
          .order('nombre');

      final mecanicos = await _client
          .from('usuarios')
          .select('id_usuario, nombre, apellidos')
          .eq('rol', 'mecanico')
          .order('nombre');

      if (!mounted) return;

      if (servicios.isEmpty || mecanicos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Necesitas al menos un servicio activo '
              'y una cuenta con rol mecánico.',
            ),
          ),
        );
        return;
      }

      final guardado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AgregarServicioDialog(
          idTicket: widget.idTicket,
          servicios: servicios,
          mecanicos: mecanicos,
        ),
      );

      if (!mounted || guardado != true) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio agregado y mecánico asignado.'),
        ),
      );

      await _recargar();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TicketsService.mensajeError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _abriendoFormulario = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del ticket'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _datos,
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

          final datos = snapshot.data!;
          final ticket = datos['ticket'] as Map<String, dynamic>;
          final detalles = datos['detalles'] as List<Map<String, dynamic>>;
          final vehiculo = ticket['vehiculo'] as Map<String, dynamic>?;
          final sucursal = ticket['sucursal'] as Map<String, dynamic>?;

          final cotizacionCompleta = detalles.isNotEmpty &&
              detalles.every(
                (detalle) =>
                    detalle['precio_mano_obra'] != null &&
                    detalle['precio_refacciones'] != null,
              );

          final total = detalles.fold<num>(
            0,
            (suma, detalle) =>
                suma +
                ((detalle['precio_mano_obra'] as num?) ?? 0) +
                ((detalle['precio_refacciones'] as num?) ?? 0),
          );

          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Ticket #${ticket['folio']}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vehiculo?['marca'] ?? ''} '
                          '${vehiculo?['modelo'] ?? ''}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text('Placas: ${vehiculo?['placas'] ?? ''}'),
                        Text('Año: ${vehiculo?['anio'] ?? ''}'),
                        Text('Sucursal: ${sucursal?['nombre'] ?? ''}'),
                        Text(
                          'Estado: ${ticket['estado'].toString().replaceAll('_', ' ')}',
                        ),
                        Text(
                          'Recibido: ${_fecha(ticket['fecha_recibido'])}',
                        ),
                        const Divider(height: 28),
                        const Text(
                          'Motivo de ingreso',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(ticket['motivo_ingreso'] as String),
                        const SizedBox(height: 16),
                        const Text(
                          'Diagnóstico',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket['diagnostico']?.toString() ??
                              'Pendiente de registrar.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Servicios asignados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!widget.soloLectura) ...[
                  FilledButton.icon(
                    onPressed: _abriendoFormulario ? null : _agregarServicio,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _abriendoFormulario
                          ? 'Cargando...'
                          : 'Agregar servicio',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (detalles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Este ticket todavía no tiene servicios.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...detalles.map((detalle) {
                  final servicio = detalle['servicio'] as Map<String, dynamic>?;
                  final mecanico = detalle['mecanico'] as Map<String, dynamic>?;

                  final avance = detalle['fecha_fin'] != null
                      ? 'Finalizado'
                      : detalle['fecha_inicio'] != null
                          ? 'En proceso'
                          : 'Pendiente';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            servicio?['nombre']?.toString() ?? 'Servicio',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Responsable: ${mecanico == null ? 'Sin asignar' : TicketsService.nombrePersona(mecanico)}',
                          ),
                          Text('Avance: $avance'),
                          const SizedBox(height: 12),
                          Text(
                            detalle['descripcion_trabajo']?.toString() ?? '',
                          ),
                          const Divider(height: 24),
                          Text(
                            'Mano de obra: ${_dinero(detalle['precio_mano_obra'])}',
                          ),
                          Text(
                            'Refacciones: ${_dinero(detalle['precio_refacciones'])}',
                          ),
                          const SizedBox(height: 12),
                          Text('Inicio: ${_fecha(detalle['fecha_inicio'])}'),
                          Text('Fin: ${_fecha(detalle['fecha_fin'])}'),
                          if (detalle['observaciones'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Observaciones: ${detalle['observaciones']}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  detalles.isEmpty
                      ? 'Total: sin servicios'
                      : cotizacionCompleta
                          ? 'Total cotizado: ${_dinero(total)}'
                          : 'Cotización pendiente de completar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AgregarServicioDialog extends StatefulWidget {
  final String idTicket;
  final List<Map<String, dynamic>> servicios;
  final List<Map<String, dynamic>> mecanicos;

  const _AgregarServicioDialog({
    required this.idTicket,
    required this.servicios,
    required this.mecanicos,
  });

  @override
  State<_AgregarServicioDialog> createState() =>
      _AgregarServicioDialogState();
}

class _AgregarServicioDialogState extends State<_AgregarServicioDialog> {
  final _client = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _manoObra = TextEditingController();
  final _refacciones = TextEditingController();

  String? _idServicio;
  String? _idMecanico;
  String? _error;
  bool _guardando = false;
  bool _cerrando = false;

  @override
  void dispose() {
    _descripcion.dispose();
    _manoObra.dispose();
    _refacciones.dispose();
    super.dispose();
  }

  String? _validarPrecio(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) return null;

    if (!RegExp(r'^\d{1,10}([.,]\d{1,2})?$').hasMatch(texto)) {
      return 'Escribe un importe no negativo con máximo 2 decimales.';
    }

    return null;
  }

  num? _precio(String texto) {
    if (texto.trim().isEmpty) return null;
    return num.parse(texto.trim().replaceAll(',', '.'));
  }

  void _cancelar() {
    if (_guardando || _cerrando) return;

    setState(() => _cerrando = true);
    Navigator.of(context).pop(false);
  }

  Future<void> _guardar() async {
    if (_guardando || _cerrando) return;
    if (!_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _client
          .from('detalle_ticket')
          .insert({
            'id_ticket': widget.idTicket,
            'id_servicio': _idServicio,
            'id_mecanico': _idMecanico,
            'descripcion_trabajo': _descripcion.text.trim(),
            'precio_mano_obra': _precio(_manoObra.text),
            'precio_refacciones': _precio(_refacciones.text),
          })
          .select('id_detalle')
          .single();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _guardando = false;
        _error = TicketsService.mensajeError(error);
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _guardando = false;
      _cerrando = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = _guardando || _cerrando;

    return PopScope(
      canPop: !_guardando,
      child: AlertDialog(
        title: const Text('Agregar servicio'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Servicio',
                    ),
                    items: widget.servicios.map((servicio) {
                      return DropdownMenuItem<String>(
                        value: servicio['id_servicio'] as String,
                        child: Text(
                          servicio['nombre'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: bloqueado
                        ? null
                        : (value) => _idServicio = value,
                    validator: (value) =>
                        value == null ? 'Selecciona un servicio.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mecánico responsable',
                    ),
                    items: widget.mecanicos.map((mecanico) {
                      final id = mecanico['id_usuario'] as String;

                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          '${TicketsService.nombrePersona(mecanico)}'
                          ' · ${id.substring(0, 8)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: bloqueado
                        ? null
                        : (value) => _idMecanico = value,
                    validator: (value) =>
                        value == null ? 'Selecciona un mecánico.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descripcion,
                    enabled: !bloqueado,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del trabajo',
                      hintText:
                          'Indica qué se hará y las refacciones contempladas.',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      return value == null || value.trim().isEmpty
                          ? 'Describe el trabajo.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _manoObra,
                    enabled: !bloqueado,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Mano de obra',
                      prefixText: '\$ ',
                      suffixText: 'MXN',
                    ),
                    validator: _validarPrecio,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _refacciones,
                    enabled: !bloqueado,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Refacciones',
                      prefixText: '\$ ',
                      suffixText: 'MXN',
                    ),
                    validator: _validarPrecio,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vacío: pendiente de cotizar. Cero: sin cargo.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: bloqueado ? null : _cancelar,
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: bloqueado ? null : _guardar,
            child: Text(
              _guardando
                  ? 'Guardando...'
                  : _cerrando
                      ? 'Cerrando...'
                      : 'Agregar',
            ),
          ),
        ],
      ),
    );
  }
}