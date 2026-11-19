import 'dart:async';

import 'package:flutter/material.dart';

import '../services/vehiculos_api_service.dart';

class CamposVehiculoApi extends StatefulWidget {
  final TextEditingController marca;
  final TextEditingController modelo;
  final bool enabled;
  final VehiculosApiService? api;

  const CamposVehiculoApi({
    super.key,
    required this.marca,
    required this.modelo,
    this.enabled = true,
    this.api,
  });

  @override
  State<CamposVehiculoApi> createState() => _CamposVehiculoApiState();
}

class _CamposVehiculoApiState extends State<CamposVehiculoApi> {
  late final VehiculosApiService _api;
  final _focoMarca = FocusNode();
  final _focoModelo = FocusNode();
  List<OpcionVehiculo> _marcas = [];
  List<OpcionVehiculo> _modelos = [];
  bool _cargandoMarcas = true;
  bool _cargandoModelos = false;
  String? _errorMarcas;
  String? _errorModelos;
  int _consulta = 0;
  Timer? _espera;
  late String _marcaAnterior;

  String _normalizar(String valor) => valor.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? VehiculosApiService();
    _marcaAnterior = _normalizar(widget.marca.text);
    widget.marca.addListener(_cambioMarca);
    widget.modelo.addListener(_actualizar);
    _focoMarca.addListener(_actualizar);
    _focoModelo.addListener(_actualizar);
    _cargarMarcas();
  }

  @override
  void dispose() {
    _espera?.cancel();
    widget.marca.removeListener(_cambioMarca);
    widget.modelo.removeListener(_actualizar);
    _focoMarca.dispose();
    _focoModelo.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  String _mensaje(Object error) => error is VehiculosApiException
      ? error.mensaje
      : 'No se pudo consultar el catálogo. Puedes escribir manualmente.';

  Future<void> _cargarMarcas() async {
    setState(() {
      _cargandoMarcas = true;
      _errorMarcas = null;
    });
    try {
      final marcas = await _api.obtenerMarcas();
      if (!mounted) return;
      setState(() {
        _marcas = marcas;
        _cargandoMarcas = false;
      });
      _buscarModelos();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMarcas = _mensaje(error);
        _cargandoMarcas = false;
      });
    }
  }

  void _cambioMarca() {
    final texto = _normalizar(widget.marca.text);
    if (texto == _marcaAnterior) return;
    _marcaAnterior = texto;
    _espera?.cancel();
    _consulta++;
    widget.modelo.clear();
    setState(() {
      _modelos = [];
      _errorModelos = null;
      _cargandoModelos = false;
    });
    _espera = Timer(const Duration(milliseconds: 350), _buscarModelos);
  }

  Future<void> _buscarModelos() async {
    final texto = _normalizar(widget.marca.text);
    final coincidencias = _marcas.where(
      (marca) => _normalizar(marca.nombre) == texto,
    );
    if (coincidencias.isEmpty) return;
    final id = ++_consulta;
    setState(() {
      _cargandoModelos = true;
      _errorModelos = null;
    });
    try {
      final modelos = await _api.obtenerModelos(coincidencias.first.id);
      if (!mounted || id != _consulta) return;
      setState(() {
        _modelos = modelos;
        _cargandoModelos = false;
      });
    } catch (error) {
      if (!mounted || id != _consulta) return;
      setState(() {
        _errorModelos = _mensaje(error);
        _cargandoModelos = false;
      });
    }
  }

  Widget _campo({
    required String etiqueta,
    required TextEditingController controller,
    required FocusNode foco,
    required List<OpcionVehiculo> opciones,
    required bool cargando,
    required String? error,
    required VoidCallback reintentar,
  }) {
    final texto = _normalizar(controller.text);
    final filtradas = opciones.where(
      (opcion) => _normalizar(opcion.nombre).contains(texto),
    ).toList();
    final mostrar = widget.enabled && foco.hasFocus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            focusNode: foco,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: etiqueta,
              hintText: 'Escribe para buscar o capturar manualmente',
              prefixIcon: const Icon(Icons.search),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe o selecciona ${etiqueta.toLowerCase()}.'
                : null,
          ),
          if (cargando) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(),
            Text('Consultando ${etiqueta.toLowerCase()}s...'),
          ],
          if (error != null) ...[
            Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.enabled && !cargando ? reintentar : null,
                child: const Text('Reintentar catálogo'),
              ),
            ),
          ],
          if (mostrar && filtradas.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  primary: false,
                  itemCount: filtradas.length,
                  itemBuilder: (context, index) {
                    final opcion = filtradas[index];
                    return ListTile(
                      dense: true,
                      title: Text(opcion.nombre),
                      onTap: () {
                        controller.value = TextEditingValue(
                          text: opcion.nombre,
                          selection: TextSelection.collapsed(offset: opcion.nombre.length),
                        );
                        foco.unfocus();
                      },
                    );
                  },
                ),
              ),
            ),
          if (mostrar && !cargando && filtradas.isEmpty && error == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Sin sugerencias. Puedes conservar el texto escrito.'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Busca una marca y elige una sugerencia para consultar sus modelos. '
            'Si no encuentras la marca o el modelo, escribe el nombre completo. '
            'Se guardará el texto que dejes en cada campo.',
          ),
        ),
        _campo(
          etiqueta: 'Marca', controller: widget.marca, foco: _focoMarca,
          opciones: _marcas, cargando: _cargandoMarcas, error: _errorMarcas,
          reintentar: _cargarMarcas,
        ),
        _campo(
          etiqueta: 'Modelo', controller: widget.modelo, foco: _focoModelo,
          opciones: _modelos, cargando: _cargandoModelos, error: _errorModelos,
          reintentar: _buscarModelos,
        ),
      ],
      ),
    );
  }
}
