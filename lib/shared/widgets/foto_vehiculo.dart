import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FotoVehiculo extends StatefulWidget {
  final String? path;
  final double altura;
  const FotoVehiculo({super.key, this.path, this.altura = 160});

  @override
  State<FotoVehiculo> createState() => _FotoVehiculoState();
}

class _FotoVehiculoState extends State<FotoVehiculo> {
  Future<String>? _url;

  void _cargar() {
    _url = widget.path == null
        ? null
        : Supabase.instance.client.storage
              .from('vehiculos')
              .createSignedUrl(widget.path!, 600);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant FotoVehiculo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vacio = SizedBox(
      height: widget.altura,
      child: const Center(child: Icon(Icons.directions_car, size: 48)),
    );
    if (_url == null) {
      return vacio;
    }
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: widget.altura,
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(_cargar),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar foto'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return vacio;
        }
        return Image.network(
          snapshot.data!,
          height: widget.altura,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => SizedBox(
            height: widget.altura,
            child: Center(
              child: TextButton(
                onPressed: () => setState(_cargar),
                child: const Text('Recargar foto'),
              ),
            ),
          ),
        );
      },
    );
  }
}
