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
  const azulNoche = Color(0xFF142B45);
  const azul = Color(0xFF245B86);
  const ambar = Color(0xFFF2A900);

  final base = ColorScheme.fromSeed(seedColor: azul, brightness: brillo);
  final colores = base.copyWith(
    primary: oscuro ? const Color(0xFF8DBCE4) : azulNoche,
    onPrimary: Colors.white,
    secondary: ambar,
    onSecondary: const Color(0xFF241A00),
    surface: oscuro ? const Color(0xFF182638) : Colors.white,
    surfaceContainerHighest:
        oscuro ? const Color(0xFF26384C) : const Color(0xFFEAF0F6),
  );
  final texto = Typography.material2021().black.apply(
    bodyColor: colores.onSurface,
    displayColor: colores.onSurface,
    fontFamily: 'Roboto',
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colores,
    textTheme: texto.copyWith(
      headlineSmall: texto.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    scaffoldBackgroundColor:
        oscuro ? const Color(0xFF101B29) : const Color(0xFFF3F6FA),
    appBarTheme: AppBarTheme(
      backgroundColor: oscuro ? const Color(0xFF142438) : azulNoche,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: colores.surface,
      elevation: oscuro ? 0 : 1.5,
      shadowColor: const Color(0x1A142B45),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: oscuro ? const Color(0xFF2B4056) : const Color(0xFFE5EBF2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: oscuro ? const Color(0xFF1B2A3B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: TextStyle(
        color: colores.onSurfaceVariant.withValues(alpha: 0.75),
      ),
      labelStyle: TextStyle(color: colores.onSurfaceVariant),
      prefixIconColor: colores.primary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colores.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colores.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: azul, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colores.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: azulNoche,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colores.surfaceContainerHighest,
        disabledForegroundColor: colores.onSurfaceVariant,
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: colores.primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: colores.surface,
      indicatorColor:
          oscuro ? const Color(0xFF29445F) : const Color(0xFFFFE9B3),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w500,
      )),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: colores.outlineVariant, thickness: 1),
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