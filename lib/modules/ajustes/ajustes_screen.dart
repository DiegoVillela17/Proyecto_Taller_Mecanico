import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = AdaptiveTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Apariencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<AdaptiveThemeMode>(
              valueListenable: tema.modeChangeNotifier,
              builder: (context, modo, _) {
                return SegmentedButton<AdaptiveThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: AdaptiveThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Claro'),
                    ),
                    ButtonSegment(
                      value: AdaptiveThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Oscuro'),
                    ),
                    ButtonSegment(
                      value: AdaptiveThemeMode.system,
                      icon: Icon(Icons.settings_suggest),
                      label: Text('Sistema'),
                    ),
                  ],
                  selected: {modo},
                  onSelectionChanged: (seleccion) {
                    switch (seleccion.first) {
                      case AdaptiveThemeMode.light:
                        tema.setLight();
                      case AdaptiveThemeMode.dark:
                        tema.setDark();
                      case AdaptiveThemeMode.system:
                        tema.setSystem();
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Ayuda',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Ver tutorial'),
                subtitle: const Text('Repasa cómo funciona la aplicación'),
                trailing: const Icon(Icons.chevron_right),
                // Regresa a la pantalla principal indicando que se
                // quiere ver el tutorial.
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}