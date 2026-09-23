import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../models/meta_goal.dart';
import 'sync_service.dart';

class StorageService {
  static const String _nombreArchivo = 'odontometas_data.json';

  /// En la web no existe un sistema de archivos real, así que mientras la
  /// pestaña sigue abierta se guarda una copia en memoria (la nube sigue
  /// siendo la fuente real de la verdad para la versión web).
  static List<MetaGoal>? _cacheWeb;

  static Future<File> _archivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_nombreArchivo');
  }

  static Future<List<MetaGoal>> cargarMetas() async {
    if (kIsWeb) {
      return _cacheWeb ?? [];
    }
    try {
      final file = await _archivo();
      if (!await file.exists()) {
        return [];
      }
      final contenido = await file.readAsString();
      if (contenido.trim().isEmpty) {
        return [];
      }
      final data = jsonDecode(contenido) as List;
      return data
          .map((e) => MetaGoal.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Guarda localmente (como siempre) y además respalda en la nube en el
  /// momento, sin bloquear ni depender de que haya conexión.
  static Future<void> guardarMetas(List<MetaGoal> metas) async {
    await guardarSoloLocal(metas);
    unawaited(SyncService.subirNube(metas));
  }

  static Future<void> guardarSoloLocal(List<MetaGoal> metas) async {
    if (kIsWeb) {
      _cacheWeb = metas;
      return;
    }
    final file = await _archivo();
    final data = metas.map((m) => m.toMap()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  /// Se llama una vez al iniciar sesión (o al abrir la app con sesión ya
  /// iniciada): si hay un respaldo en la nube, lo trae y reemplaza lo local
  /// (útil al cambiar de teléfono, o al abrir la versión web). Si todavía
  /// no hay nada en la nube, sube lo que ya existe localmente (en Android)
  /// para dejarlo respaldado desde ahora.
  static Future<List<MetaGoal>> sincronizarAlIniciarSesion() async {
    final locales = await cargarMetas();
    final remotas = await SyncService.descargarNube();
    if (remotas != null) {
      await guardarSoloLocal(remotas);
      return remotas;
    } else if (locales.isNotEmpty) {
      unawaited(SyncService.subirNube(locales));
    }
    return locales;
  }
}
