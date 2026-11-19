import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tickets/tickets_screen.dart';
import '../personal/personal_screen.dart';

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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Sucursales',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
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
                      child: ListTile(
                        leading: const Icon(Icons.store),
                        title: Text(s['nombre'] as String),
                        subtitle: Text(
                          '${s['direccion']}\n${s['abiertos']} tickets sin entregar · ${s['mecanicos']} mecánicos activos',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
