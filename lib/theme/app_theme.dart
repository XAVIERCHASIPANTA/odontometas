import 'package:flutter/material.dart';

class AppTheme {
  static const Color rosaClaro = Color(0xFFFFE4EC);
  static const Color rosaPrincipal = Color(0xFFEC407A);
  static const Color rosaOscuro = Color(0xFFC2185B);
  static const Color mentaFresca = Color(0xFF4DB6AC);
  static const Color lavanda = Color(0xFF7E57C2);
  static const Color fondo = Color(0xFFFFF6F9);

  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: rosaPrincipal,
      scaffoldBackgroundColor: fondo,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rosaOscuro,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: rosaOscuro,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
      ),
    );
  }
}

/// AppBar con degradado de colores, usada en todas las pantallas para un
/// look más vistoso que un color plano.
AppBar appBarConGradiente({
  required String titulo,
  List<Widget>? acciones,
  List<Color>? colores,
  bool mostrarLogo = false,
}) {
  final degradado = colores ?? [AppTheme.rosaOscuro, AppTheme.lavanda];
  return AppBar(
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mostrarLogo) ...[
          CircleAvatar(
            radius: 16,
            backgroundImage: const AssetImage('assets/images/logo.jpg'),
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(titulo, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
    actions: acciones,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: degradado,
        ),
      ),
    ),
  );
}
