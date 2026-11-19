import 'package:flutter/material.dart';

import '../../shared/services/tickets_service.dart';

class TicketFormScreen extends StatefulWidget {
  final String? idSucursal;
  const TicketFormScreen({super.key, this.idSucursal});

  @override
  State<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends State<TicketFormScreen> {
  final _service = TicketsService();
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  late Future<Map<String, List<Map<String, dynamic>>>> _opciones;

  String? _idVehiculo;
  String? _idSucursal;
  String? _idMecanico;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _idSucursal = widget.idSucursal;
    _opciones = _service.obtenerOpciones();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _idVehiculo = null;
      _idSucursal = null;
      _idMecanico = null;
      _error = null;
      _opciones = _service.obtenerOpciones();
    });
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final ticket = await _service.crearTicket(
        idVehiculo: _idVehiculo!,
        idSucursal: _idSucursal!,
        idMecanicoRevision: _idMecanico,
        motivoIngreso: _motivo.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(ticket);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = TicketsService.mensajeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Widget _aviso(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Volver a cargar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ticket')),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _opciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _aviso(TicketsService.mensajeError(snapshot.error!));
          }

          final opciones = snapshot.data!;
          final vehiculos = opciones['vehiculos']!;
          final sucursales = opciones['sucursales']!;
          final mecanicos = opciones['mecanicos']!
              .where((m) => m['id_sucursal'] == _idSucursal)
              .toList();

          if (vehiculos.isEmpty) {
            return _aviso(
              'Primero registra un vehículo para poder crear su ticket.',
            );
          }

          if (sucursales.isEmpty) {
            return _aviso(
              'No hay sucursales disponibles. '
              'Registra una sucursal antes de crear tickets.',
            );
          }

          Map<String, dynamic>? seleccionado;

          for (final vehiculo in vehiculos) {
            if (vehiculo['id_vehiculo'] == _idVehiculo) {
              seleccionado = vehiculo;
              break;
            }
          }

          final cliente = seleccionado?['cliente'] as Map<String, dynamic>?;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Recepción del vehículo',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Registra el ingreso al taller. '
                        'Después podrás agregar los servicios necesarios.',
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _idVehiculo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehículo',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                        items: vehiculos.map((vehiculo) {
                          return DropdownMenuItem<String>(
                            value: vehiculo['id_vehiculo'] as String,
                            child: Text(
                              '${vehiculo['placas']} · '
                              '${vehiculo['marca']} ${vehiculo['modelo']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _guardando
                            ? null
                            : (value) {
                                setState(() => _idVehiculo = value);
                              },
                        validator: (value) {
                          return value == null
                              ? 'Selecciona un vehículo.'
                              : null;
                        },
                      ),
                      if (cliente != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Cliente: ${TicketsService.nombrePersona(cliente)}',
                            style: TextStyle(
                              color: colores.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _idSucursal,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                        items: sucursales.map((sucursal) {
                          return DropdownMenuItem<String>(
                            value: sucursal['id_sucursal'] as String,
                            child: Text(
                              sucursal['nombre'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _guardando
                            ? null
                            : (value) {
                                setState(() {
                                  _idSucursal = value;
                                  _idMecanico = null;
                                });
                              },
                        validator: (value) {
                          return value == null
                              ? 'Selecciona una sucursal.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_idSucursal),
                        initialValue: _idMecanico ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Mecánico de revisión',
                          prefixIcon: Icon(Icons.build_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Asignar después'),
                          ),
                          ...mecanicos.map((mecanico) {
                            final id = mecanico['id_usuario'] as String;
                            final nombre = TicketsService.nombrePersona(
                              mecanico,
                            );

                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                '$nombre · ${id.substring(0, 8)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: _guardando
                            ? null
                            : (value) {
                                setState(() {
                                  _idMecanico = value == '' ? null : value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mecanicos.isEmpty
                            ? 'Selecciona una sucursal con mecánicos activos o asigna la revisión después.'
                            : 'El mecánico de revisión puede ser distinto '
                                  'de los responsables de cada servicio.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _motivo,
                        enabled: !_guardando,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de ingreso',
                          hintText:
                              'Ejemplo: ruido al frenar y vibración '
                              'en el volante.',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Describe el motivo de ingreso.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'El ticket se registrará con estado “Recibido”.',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colores.error),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Crear ticket'),
                      ),
                    ],
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
