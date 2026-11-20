import 'package:flutter/material.dart';

import '../../shared/services/auth_service.dart';

class AccesoScreen extends StatefulWidget {
  const AccesoScreen({super.key});

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  final _auth = AuthService();
  final _form = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();

  bool _registro = false;
  bool _ocupado = false;
  bool _ocultar = true;
  String? _mensaje;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_ocupado || !_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _ocupado = true;
      _mensaje = null;
    });

    try {
      if (_registro) {
        final respuesta = await _auth.registrar(
          nombre: _nombre.text,
          apellidos: _apellidos.text,
          telefono: _telefono.text,
          correo: _correo.text,
          password: _password.text,
        );

        if (!mounted) return;

        if (respuesta.session == null) {
          setState(() {
            _registro = false;
            _password.clear();
            _mensaje =
                'Si el registro procede, recibirás un correo de confirmación. '
                'Revísalo antes de iniciar sesión.';
          });
        }
      } else {
        await _auth.iniciarSesion(_correo.text, _password.text);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _mensaje = AuthService.mensajeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Widget _campo(
    TextEditingController controller,
    String etiqueta,
    IconData icono, {
    TextInputType teclado = TextInputType.text,
    int? maximo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_ocupado,
        keyboardType: teclado,
        maxLength: maximo,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          counterText: '',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Completa este campo.';
          }

          if (teclado == TextInputType.emailAddress &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                  .hasMatch(value.trim())) {
            return 'Escribe un correo válido.';
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 22,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF193B5C), Color(0xFF10243A)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x24142B45),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2A900),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Icon(
                              Icons.car_repair_rounded,
                              size: 43,
                              color: Color(0xFF142B45),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'MI TALLER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _registro
                                ? 'Crea tu cuenta de cliente'
                                : 'Tu vehículo, en buenas manos',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD5E2EF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_registro) ...[
                      _campo(
                        _nombre,
                        'Nombre',
                        Icons.person_outline,
                        maximo: 100,
                      ),
                      _campo(
                        _apellidos,
                        'Apellidos',
                        Icons.badge_outlined,
                        maximo: 150,
                      ),
                      _campo(
                        _telefono,
                        'Teléfono',
                        Icons.phone_outlined,
                        teclado: TextInputType.phone,
                        maximo: 30,
                      ),
                    ],
                    _campo(
                      _correo,
                      'Correo electrónico',
                      Icons.email_outlined,
                      teclado: TextInputType.emailAddress,
                    ),
                    TextFormField(
                      controller: _password,
                      enabled: !_ocupado,
                      obscureText: _ocultar,
                      autocorrect: false,
                      enableSuggestions: false,
                      onFieldSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _ocultar
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () {
                            setState(() => _ocultar = !_ocultar);
                          },
                          icon: Icon(
                            _ocultar
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Escribe tu contraseña.';
                        }

                        if (_registro && value.length < 8) {
                          return 'Usa al menos 8 caracteres.';
                        }

                        return null;
                      },
                    ),
                    if (_mensaje != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _mensaje!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _ocupado ? null : _enviar,
                      child: _ocupado
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _registro ? 'Crear cuenta' : 'Iniciar sesión',
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _ocupado
                          ? null
                          : () {
                              _form.currentState?.reset();

                              setState(() {
                                _registro = !_registro;
                                _mensaje = null;
                                _password.clear();
                              });
                            },
                      child: Text(
                        _registro
                            ? 'Ya tengo cuenta. Iniciar sesión'
                            : '¿No tienes cuenta? Regístrate',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}