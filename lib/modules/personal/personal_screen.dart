import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/tickets_service.dart';

class PersonalScreen extends StatefulWidget {
  final String? idSucursal;
  const PersonalScreen({super.key, this.idSucursal});
  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _personal;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _personal = _consultar();
  }

  Future<List<Map<String, dynamic>>> _consultar() async {
    var q = _client
        .from('usuarios')
        .select(
          'id_usuario,nombre,apellidos,telefono,id_sucursal,activo,sucursal:sucursales(nombre)',
        )
        .eq('rol', 'mecanico');
    if (widget.idSucursal != null) {
      q = q.eq('id_sucursal', widget.idSucursal!);
    }
    return await q.order('nombre');
  }

  Future<void> _recargar() async {
    final consulta = _consultar();
    setState(() => _personal = consulta);
    try {
      await consulta;
    } catch (_) {}
  }

  Future<void> _editar([Map<String, dynamic>? persona]) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PersonalFormScreen(persona: persona, idSucursal: widget.idSucursal),
      ),
    );
    if (mounted && cambio == true) {
      await _recargar();
    }
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
                'Personal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Cada mecánico pertenece a una sucursal. Conservamos el historial al desactivarlo.',
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar mecánico',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => _busqueda = v.trim().toLowerCase()),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _editar(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Registrar mecánico'),
                    ),
                  ),
                  IconButton(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar personal',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _personal,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: _recargar,
                    child: const Text(
                      'No se pudo cargar el personal. Reintentar',
                    ),
                  ),
                );
              }
              final lista = snapshot.data!
                  .where(
                    (p) => TicketsService.nombrePersona(
                      p,
                    ).toLowerCase().contains(_busqueda),
                  )
                  .toList();
              if (lista.isEmpty) {
                return const Center(
                  child: Text('No hay mecánicos para mostrar.'),
                );
              }
              return RefreshIndicator(
                onRefresh: _recargar,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    final sucursal = p['sucursal'] as Map<String, dynamic>?;
                    return Card(
                      child: ListTile(
                        title: Text(TicketsService.nombrePersona(p)),
                        subtitle: Text(
                          '${sucursal?['nombre'] ?? 'Asigna una sucursal'} · ${p['activo'] == true ? 'Activo' : 'Inactivo'}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editar(p),
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

class PersonalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? persona;
  final String? idSucursal;
  const PersonalFormScreen({super.key, this.persona, this.idSucursal});
  @override
  State<PersonalFormScreen> createState() => _PersonalFormScreenState();
}

class _PersonalFormScreenState extends State<PersonalFormScreen> {
  final _client = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  late Future<List<Map<String, dynamic>>> _sucursales;
  String? _sucursal;
  bool _activo = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _nombre.text = p?['nombre'] as String? ?? '';
    _apellidos.text = p?['apellidos'] as String? ?? '';
    _telefono.text = p?['telefono'] as String? ?? '';
    _sucursal = p?['id_sucursal'] as String? ?? widget.idSucursal;
    _activo = p?['activo'] as bool? ?? true;
    _sucursales = _cargarSucursales();
  }

  Future<List<Map<String, dynamic>>> _cargarSucursales() async => await _client
      .from('sucursales')
      .select('id_sucursal,nombre')
      .order('nombre');

  @override
  void dispose() {
    for (final c in [_nombre, _apellidos, _telefono, _correo, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final datos = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'telefono': _telefono.text.trim(),
        'id_sucursal': _sucursal,
      };
      if (widget.persona == null) {
        await _client.functions.invoke(
          'crear-mecanico',
          body: {
            ...datos,
            'correo': _correo.text.trim(),
            'password': _password.text,
          },
        );
      } else {
        await _client
            .from('usuarios')
            .update({...datos, 'activo': _activo})
            .eq('id_usuario', widget.persona!['id_usuario'])
            .select('id_usuario')
            .single();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.persona == null
                ? 'Mecánico creado. Ya puede entrar con su correo y contraseña.'
                : 'Personal actualizado.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      String mensaje = TicketsService.mensajeError(e);
      if (e is FunctionException) {
        final detalles = e.details;
        mensaje = detalles is Map && detalles['error'] is String
            ? detalles['error'] as String
            : 'No se pudo registrar. Revisa que la función crear-mecanico esté publicada y consulta Personal antes de reintentar.';
      }
      setState(() => _error = mensaje);
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    int maximo = 100,
    bool requerido = true,
    bool ocultar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        enabled: !_guardando,
        obscureText: ocultar,
        maxLength: maximo,
        decoration: InputDecoration(labelText: etiqueta),
        validator: (v) {
          if (requerido && (v == null || v.trim().isEmpty)) {
            return 'Completa este campo.';
          }
          if (ocultar && (v?.length ?? 0) < 8) {
            return 'Usa al menos 8 caracteres.';
          }
          if (c == _correo &&
              !RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(v?.trim() ?? '')) {
            return 'Escribe un correo válido.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.persona == null ? 'Registrar mecánico' : 'Editar mecánico',
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _sucursales,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _sucursales = _cargarSucursales()),
                  child: const Text('Reintentar carga de sucursales'),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _campo(_nombre, 'Nombre'),
                          _campo(_apellidos, 'Apellidos', maximo: 150),
                          _campo(
                            _telefono,
                            'Teléfono (opcional)',
                            maximo: 30,
                            requerido: false,
                          ),
                          if (widget.persona == null) ...[
                            _campo(_correo, 'Correo', maximo: 254),
                            _campo(
                              _password,
                              'Contraseña de acceso',
                              maximo: 128,
                              ocultar: true,
                            ),
                            const Text(
                              'Esta cuenta será de mecánico. El administrador conserva su sesión.',
                            ),
                            const SizedBox(height: 16),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: _sucursal,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sucursal',
                            ),
                            items: snapshot.data!
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s['id_sucursal'] as String,
                                    child: Text(s['nombre'] as String),
                                  ),
                                )
                                .toList(),
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _sucursal = v),
                            validator: (v) =>
                                v == null ? 'Selecciona una sucursal.' : null,
                          ),
                          if (widget.persona != null)
                            SwitchListTile(
                              title: const Text('Empleado activo'),
                              value: _activo,
                              onChanged: _guardando
                                  ? null
                                  : (v) => setState(() => _activo = v),
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
                              _guardando ? 'Guardando...' : 'Guardar',
                            ),
                          ),
                        ],
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
}
