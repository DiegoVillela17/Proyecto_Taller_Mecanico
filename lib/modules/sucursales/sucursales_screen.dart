import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tickets/tickets_screen.dart';
import '../personal/personal_screen.dart';
import '../../shared/widgets/encabezado_seccion.dart';

class SucursalesScreen extends StatefulWidget {
  const SucursalesScreen({super.key});
  @override
  State<SucursalesScreen> createState() => _SucursalesScreenState();
}

class _SucursalesScreenState extends State<SucursalesScreen> {
  late Future<List<Map<String, dynamic>>> _datos;
  @override
  void initState() {
    super.initState();
    _datos = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    final datos = await Supabase.instance.client.rpc('resumen_sucursales');
    return (datos as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  Future<void> _recargar() async {
    final consulta = _consultar();
    setState(() => _datos = consulta);
    try {
      await consulta;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Row(
          children: [
            const Expanded(
              child: EncabezadoSeccion(
                titulo: 'Sucursales',
                descripcion: 'Consulta la actividad y el personal de cada taller.',
                icono: Icons.storefront_rounded,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar sucursales',
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: _recargar,
                  child: const Text(
                    'No se pudieron cargar las sucursales. Reintentar',
                  ),
                ),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                child: Text('No hay sucursales registradas.'),
              );
            }
            return RefreshIndicator(
              onRefresh: _recargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  for (final s in snapshot.data!)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _SucursalScreen(sucursal: s),
                            ),
                          );
                          if (mounted) {
                            await _recargar();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.storefront_rounded,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['nombre'] as String,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s['direccion']?.toString() ?? 'Dirección no disponible',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          avatar: const Icon(Icons.assignment_outlined, size: 16),
                                          label: Text('${s['abiertos']} tickets abiertos'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Chip(
                                          avatar: const Icon(Icons.engineering_outlined, size: 16),
                                          label: Text('${s['mecanicos']} mecánicos'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _SucursalScreen extends StatelessWidget {
  final Map<String, dynamic> sucursal;
  const _SucursalScreen({required this.sucursal});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(sucursal['nombre'] as String),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Tickets'),
            Tab(text: 'Mecánicos'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          TicketsScreen(idSucursal: sucursal['id_sucursal'] as String),
          PersonalScreen(idSucursal: sucursal['id_sucursal'] as String),
        ],
      ),
    ),
  );
}
