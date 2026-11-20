import 'package:flutter/material.dart';

/// Encabezado visual reutilizable para las secciones de cada perfil.
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Widget? accion;

  const EncabezadoSeccion({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colores.primaryContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icono, color: colores.onPrimaryContainer, size: 25),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                descripcion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colores.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (accion != null) ...[
          const SizedBox(width: 8),
          accion!,
        ],
      ],
    );
  }
}
