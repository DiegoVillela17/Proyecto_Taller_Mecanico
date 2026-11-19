import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/foto_vehiculo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/services/vehiculos_service.dart';
import '../../shared/widgets/campos_vehiculo_api.dart';

class VehiculoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? vehiculo;

  const VehiculoFormScreen({super.key, this.vehiculo});

  @override
  State<VehiculoFormScreen> createState() => _VehiculoFormScreenState();
}

class _VehiculoFormScreenState extends State<VehiculoFormScreen> {
  final _service = VehiculosService();
  final _form = GlobalKey<FormState>();

  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _placas = TextEditingController();

  late Future<List<Map<String, dynamic>>> _clientes;
  String? _idCliente;
  bool _guardando = false;
  bool _seleccionando = false;
  Uint8List? _foto;
  String? _tipoFoto;
  bool _quitarFoto = false;
  String? _error;

  bool get _editando => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();

    final vehiculo = widget.vehiculo;

    if (vehiculo != null) {
      _marca.text = vehiculo['marca'] as String;
      _modelo.text = vehiculo['modelo'] as String;
      _anio.text = vehiculo['anio'].toString();
      _placas.text = vehiculo['placas'] as String;
      _idCliente = vehiculo['id_cliente'] as String;
      _clientes = Future.value(<Map<String, dynamic>>[]);
    } else {
      _clientes = _service.listarClientes();
    }
  }

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _placas.dispose();
    super.dispose();
  }

  void _recargarClientes() {
    setState(() {
      _clientes = _service.listarClientes();
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
      await _service.guardar(
        idVehiculo: widget.vehiculo?['id_vehiculo'] as String?,
        idCliente: _idCliente!,
        marca: _marca.text,
        modelo: _modelo.text,
        anio: int.parse(_anio.text),
        placas: _placas.text,
        foto: _foto,
        tipoFoto: _tipoFoto,
        fotoAnterior: widget.vehiculo?['foto_path'] as String?,
        actualizadoEn: widget.vehiculo?['actualizado_en'] as String?,
        quitarFoto: _quitarFoto,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = VehiculosService.mensajeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _elegirFoto() async {
    setState(() => _seleccionando = true);
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (archivo == null) {
        return;
      }
      if (await archivo.length() > 5 * 1024 * 1024) {
        throw const FormatException('La foto debe pesar como máximo 5 MB.');
      }
      final bytes = await archivo.readAsBytes();
      String? tipo;
      if (bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        tipo = 'image/jpeg';
      }
      if (bytes.length > 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        tipo = 'image/png';
      }
      if (bytes.length > 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
        tipo = 'image/webp';
      }
      if (tipo == null) {
        throw const FormatException('Selecciona una imagen JPG, PNG o WebP.');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _foto = bytes;
        _tipoFoto = tipo;
        _quitarFoto = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'No se pudo abrir la imagen.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _seleccionando = false);
      }
    }
  }

  Widget _aviso(String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _recargarClientes,
              child: const Text('Actualizar clientes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando && !_seleccionando,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar vehículo' : 'Registrar vehículo'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _clientes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _aviso(
                'No se pudieron cargar los clientes. Revisa tu conexión.',
              );
            }

            final clientes = snapshot.data ?? [];

            if (!_editando && clientes.isEmpty) {
              return _aviso(
                'Todavía no hay clientes registrados. '
                'Primero crea una cuenta con rol cliente.',
              );
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_editando)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: const Text('Dueño del vehículo'),
                              subtitle: Text(
                                VehiculosService.nombreCliente(
                                  widget.vehiculo!['cliente']
                                      as Map<String, dynamic>?,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: DropdownButtonFormField<String>(
                              initialValue: _idCliente,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Cliente dueño',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              items: clientes.map((cliente) {
                                final id = cliente['id_usuario'] as String;
                                final nombre = VehiculosService.nombreCliente(
                                  cliente,
                                );

                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(
                                    '$nombre · ${id.substring(0, 8)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _guardando
                                  ? null
                                  : (value) {
                                      setState(() => _idCliente = value);
                                    },
                              validator: (value) {
                                return value == null
                                    ? 'Selecciona un cliente.'
                                    : null;
                              },
                            ),
                          ),
                        const Text('Foto del vehículo (opcional)'),
                        if (_foto != null)
                          Image.memory(
                            _foto!,
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (_, error, stack) => const Text(
                              'No se puede previsualizar esta imagen.',
                            ),
                          )
                        else
                          FotoVehiculo(
                            path: _quitarFoto
                                ? null
                                : widget.vehiculo?['foto_path'] as String?,
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _guardando || _seleccionando
                                  ? null
                                  : _elegirFoto,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Elegir foto'),
                            ),
                            if (_foto != null ||
                                (!_quitarFoto &&
                                    widget.vehiculo?['foto_path'] != null))
                              TextButton(
                                onPressed: _guardando || _seleccionando
                                    ? null
                                    : () => setState(() {
                                        _foto = null;
                                        _tipoFoto = null;
                                        _quitarFoto = true;
                                      }),
                                child: const Text('Quitar foto'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CamposVehiculoApi(
                          marca: _marca,
                          modelo: _modelo,
                          enabled: !_guardando,
                        ),
                        TextFormField(
                          controller: _anio,
                          enabled: !_guardando,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Año',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (value) {
                            final anio = int.tryParse(value ?? '');
                            final maximo = DateTime.now().year + 1;

                            if (anio == null || anio < 1886 || anio > maximo) {
                              return 'Escribe un año entre 1886 y $maximo.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _placas,
                          enabled: !_guardando,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Placas',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (value) {
                            return value == null || value.trim().isEmpty
                                ? 'Escribe las placas.'
                                : null;
                          },
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: _guardando || _seleccionando
                              ? null
                              : _guardar,
                          child: _guardando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _editando
                                      ? 'Guardar cambios'
                                      : 'Registrar vehículo',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
