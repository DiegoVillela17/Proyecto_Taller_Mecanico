import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'modules/auth/sesion_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sddqmjbyzoalcfkembgy.supabase.co',
    publishableKey: 'sb_publishable_sqClz4zFRZhjGQvZfjOMeg_VlMmTrXH',
  );

  final modoGuardado = await AdaptiveTheme.getThemeMode();

  runApp(MyApp(modoGuardado: modoGuardado));
}

ThemeData _crearTema(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;

  final colores = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    brightness: brillo,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colores,
    scaffoldBackgroundColor:
        oscuro ? const Color(0xFF0F1722) : const Color(0xFFF3F6FB),
    appBarTheme: AppBarTheme(
      backgroundColor:
          oscuro ? const Color(0xFF0B2545) : const Color(0xFF103B70),
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: oscuro ? const Color(0xFF1B2533) : Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AdaptiveThemeMode? modoGuardado;

  const MyApp({super.key, this.modoGuardado});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: _crearTema(Brightness.light),
      dark: _crearTema(Brightness.dark),
      initial: modoGuardado ?? AdaptiveThemeMode.light,
      builder: (tema, temaOscuro) => MaterialApp(
        title: 'Mi Taller',
        debugShowCheckedModeBanner: false,
        theme: tema,
        darkTheme: temaOscuro,
        home: const SesionScreen(),
      ),
    );
  }
}