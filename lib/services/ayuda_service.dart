import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Recuerda qué guías de "primera vez" ya se mostraron, para no repetirlas.
class AyudaService {
  static const String _nombreArchivo = 'odontometas_ayuda.json';
  static Map<String, dynamic>? _cache;
  static bool mostrando = false;

  static Future<File> _archivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_nombreArchivo');
  }

  static Future<Map<String, dynamic>> _leer() async {
    if (_cache != null) {
      return _cache!;
    }
    if (kIsWeb) {
      return _cache = {};
    }
    try {
      final f = await _archivo();
      if (await f.exists()) {
        final txt = await f.readAsString();
        if (txt.trim().isNotEmpty) {
          return _cache = Map<String, dynamic>.from(jsonDecode(txt) as Map);
        }
      }
    } catch (_) {
      // Si no se puede leer, se empieza de cero.
    }
    return _cache = {};
  }

  static Future<void> _escribir() async {
    if (kIsWeb || _cache == null) {
      return;
    }
    try {
      final f = await _archivo();
      await f.writeAsString(jsonEncode(_cache));
    } catch (_) {
      // Guardar esto no es crítico.
    }
  }

  static Future<bool> yaVista(String clave) async {
    final datos = await _leer();
    return datos[clave] == true;
  }

  static Future<void> marcarVista(String clave) async {
    final datos = await _leer();
    datos[clave] = true;
    await _escribir();
  }

  /// Vuelve a mostrar todas las guías de primera vez.
  static Future<void> reiniciar() async {
    _cache = {};
    await _escribir();
  }
}
