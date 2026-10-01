import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../models/meta_goal.dart';
import 'sync_service.dart';

class StorageService {
  static const String _nombreArchivo = 'odontometas_data.json';
  static const String _archivoPreMigracion = 'odontometas_data.premigracion.json';
  static const String _archivoRespaldo = 'odontometas_data.respaldo.json';

  /// En la web no existe un sistema de archivos real, así que mientras la
  /// pestaña sigue abierta se guarda una copia en memoria (la nube sigue
  /// siendo la fuente real de la verdad para la versión web).
  static List<MetaGoal>? _cacheWeb;

  static Future<File> _archivo([String? nombre]) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${nombre ?? _nombreArchivo}');
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
  /// momento, sin bloquear ni depender de que haya conexión. Antes de
  /// subir anota que hay cambios pendientes: si la subida falla, al volver
  /// a abrir la app se conserva lo del teléfono en vez de pisarlo.
  static Future<void> guardarMetas(List<MetaGoal> metas) async {
    await guardarSoloLocal(metas);
    await SyncService.marcarPendiente();
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

  /// Copia de seguridad local antes de reemplazar el archivo con lo que
  /// viene de la nube. [unaVez] = solo si todavía no existe (copia previa a
  /// la migración, que nunca se sobrescribe).
  static Future<void> _respaldarLocal({required bool unaVez}) async {
    if (kIsWeb) {
      return;
    }
    try {
      final origen = await _archivo();
      if (!await origen.exists()) {
        return;
      }
      final destino = await _archivo(unaVez ? _archivoPreMigracion : _archivoRespaldo);
      if (unaVez && await destino.exists()) {
        return;
      }
      await origen.copy(destino.path);
    } catch (_) {
      // El respaldo es una ayuda extra: si falla, no se interrumpe el inicio.
    }
  }

  /// Se llama una vez al iniciar sesión (o al abrir la app con sesión ya
  /// iniciada).
  ///
  ///  - Si este teléfono tiene cambios que NO llegaron a la nube, se
  ///    conservan los del teléfono y se suben (nunca se pisan).
  ///  - Si no, y hay respaldo en la nube, se trae y reemplaza lo local (útil
  ///    al cambiar de teléfono o al abrir la versión web).
  ///  - Si la nube todavía está vacía, se sube lo que hay en el teléfono.
  ///  - Si el respaldo de la nube estaba en el formato anterior, se migra
  ///    solo al nuevo (un documento por paciente), sin borrar el anterior.
  static Future<List<MetaGoal>> sincronizarAlIniciarSesion() async {
    final locales = await cargarMetas();
    if (locales.isNotEmpty && await SyncService.hayCambiosSinSubir()) {
      unawaited(SyncService.subirNube(locales));
      return locales;
    }
    final remotas = await SyncService.descargarNube();
    if (remotas != null) {
      if (SyncService.remotoEsLegacy) {
        await _respaldarLocal(unaVez: true);
        await guardarSoloLocal(remotas);
        // Migración: sube todo en el formato nuevo.
        unawaited(SyncService.subirNube(remotas));
        return remotas;
      }
      if (locales.isNotEmpty) {
        await _respaldarLocal(unaVez: false);
      }
      await guardarSoloLocal(remotas);
      return remotas;
    } else if (locales.isNotEmpty) {
      await _respaldarLocal(unaVez: true);
      unawaited(SyncService.subirNube(locales));
    }
    return locales;
  }
}
