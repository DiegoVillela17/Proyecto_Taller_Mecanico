import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/tickets_service.dart';

class TicketEditarScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TicketEditarScreen({super.key, required this.ticket});
  @override
  State<TicketEditarScreen> createState() => _TicketEditarScreenState();
}

class _TicketEditarScreenState extends State<TicketEditarScreen> {
  final _client = Supabase.instance.client;
  final _diagnostico = TextEditingController();
  late Future<List<Map<String, dynamic>>> _mecanicos;
  late String _estado;
  String? _revision;
  String? _error;
  bool _guardando = false;
  static const _estados = [
    'recibido',
    'en_revision',
    'en_reparacion',
    'terminado',
    'entregado',
  ];

  @override
  void initState() {
    super.initState();
    _diagnostico.text = widget.ticket['diagnostico'] as String? ?? '';
    _estado = widget.ticket['estado'] as String;
    _revision = widget.ticket['id_mecanico_revision'] as String?;
    _mecanicos = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    final lista = await _client
        .from('usuarios')
        .select('id_usuario,nombre,apellidos')
        .eq('rol', 'mecanico')
        .eq('activo', true)
        .eq('id_sucursal', widget.ticket['id_sucursal'])
        .order('nombre');
    if (_revision != null && !lista.any((p) => p['id_usuario'] == _revision)) {
      final anterior = await _client
          .from('usuarios')
          .select('id_usuario,nombre,apellidos')
          .eq('id_usuario', _revision!)
          .maybeSingle();
      if (anterior != null) {
        lista.add(anterior);
      }
    }
    return lista;
  }

  @override
  void dispose() {
    _diagnostico.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) {
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _client
          .from('tickets')
          .update({
            'diagnostico': _diagnostico.text.trim(),
            'estado': _estado,
            'id_mecanico_revision': _revision,
          })
          .eq('id_ticket', widget.ticket['id_ticket'])
          .eq('actualizado_en', widget.ticket['actualizado_en'])
          .select('id_ticket')
          .single();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PostgrestException && e.code == 'PGRST116'
              ? 'El ticket cambió mientras lo editabas. Vuelve al detalle y actualiza.'
              : TicketsService.mensajeError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Actualizar ticket #${widget.ticket['folio']}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mecanicos,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _mecanicos = _consultar()),
                child: const Text('Reintentar carga'),
              ),
            );
          }
          final original = widget.ticket['estado'] as String;
          final opciones = _estados
              .where(
                (e) =>
                    _estados.indexOf(e) >= _estados.indexOf(original) &&
                    (e != 'entregado' || original == 'terminado'),
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: opciones
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _estado = v!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _revision ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mecánico de revisión',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Sin asignar'),
                      ),
                      ...snapshot.data!.map(
                        (p) => DropdownMenuItem(
                          value: p['id_usuario'] as String,
                          child: Text(TicketsService.nombrePersona(p)),
                        ),
                      ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _revision = v == '' ? null : v),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _diagnostico,
                    enabled: !_guardando,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 3000,
                    decoration: const InputDecoration(
                      labelText: 'Diagnóstico',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const Text(
                    'Para terminar, todos los servicios deben estar finalizados. Para entregar, todos sus precios deben estar registrados.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(
                      _guardando ? 'Guardando...' : 'Guardar cambios',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
