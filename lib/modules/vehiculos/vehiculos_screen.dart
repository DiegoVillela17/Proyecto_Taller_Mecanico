import 'package:flutter/material.dart';

import '../../shared/services/vehiculos_service.dart';
import 'vehiculo_form_screen.dart';

class VehiculosScreen extends StatefulWidget {
  final bool esAdministrador;

  const VehiculosScreen({
    super.key,
    required this.esAdministrador,
  });

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final _service = VehiculosService();
  final _buscador = TextEditingController();

  late Future<List<Map<String, dynamic>>> _vehiculos;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _vehiculos = _consultar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _consultar() {
    return _service.listar(
      esAdministrador: widget.esAdministrador,
    );
  }

  Future<void> _recargar() async {
    final consulta = _consultar();

    setState(() {
      _vehiculos = consulta;
    });

    try {
      await consulta;
    } catch (_) {}
  }

  Future<void> _abrirFormulario({
    Map<String, dynamic>? vehiculo,
  }) async {
    if (!widget.esAdministrador) return;

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VehiculoFormScreen(vehiculo: vehiculo),
      ),
    );

    if (!mounted || guardado != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vehiculo == null
              ? 'Vehículo registrado correctamente.'
              : 'Vehículo actualizado correctamente.',
        ),
      ),
    );

    await _recargar();
  }

  bool _coincide(Map<String, dynamic> vehiculo) {
    final texto =
        '${vehiculo['marca']} ${vehiculo['modelo']} ${vehiculo['placas']}'
            .toLowerCase();

    return texto.contains(_busqueda.trim().toLowerCase());
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
              Text(
                widget.esAdministrador
                    ? 'Vehículos del taller'
                    : 'Mis vehículos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                widget.esAdministrador
                    ? 'Administra los vehículos y sus propietarios.'
                    : 'Estos son los vehículos registrados a tu nombre.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _buscador,
                decoration: InputDecoration(
                  hintText: 'Buscar por placas, marca o modelo',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busqueda.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _buscador.clear();
                            setState(() => _busqueda = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) {
                  setState(() => _busqueda = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.esAdministrador)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _abrirFormulario(),
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar vehículo'),
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip: 'Actualizar vehículos',
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
            future: _vehiculos,
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
                          VehiculosService.mensajeError(snapshot.error!),
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
                          ? widget.esAdministrador
                              ? 'Todavía no hay vehículos. Registra el primero.'
                              : 'Todavía no tienes vehículos registrados.'
                          : 'No hay vehículos que coincidan con tu búsqueda.',
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
                    final vehiculo = resultados[index];
                    final cliente =
                        vehiculo['cliente'] as Map<String, dynamic>?;

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colores.primaryContainer,
                                  child: Icon(
                                    Icons.directions_car,
                                    color: colores.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${vehiculo['marca']} ${vehiculo['modelo']}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (widget.esAdministrador)
                                  IconButton(
                                    tooltip: 'Editar vehículo',
                                    onPressed: () => _abrirFormulario(
                                      vehiculo: vehiculo,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text('Placas: ${vehiculo['placas']}'),
                            const SizedBox(height: 6),
                            Text('Año: ${vehiculo['anio']}'),
                            if (widget.esAdministrador) ...[
                              const Divider(height: 24),
                              Text(
                                'Cliente: ${VehiculosService.nombreCliente(cliente)}',
                              ),
                            ],
                          ],
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