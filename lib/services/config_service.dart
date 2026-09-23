import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'sync_service.dart';

class ConfigService {
  static const String _nombreArchivo = 'odontometas_config.json';

  /// En la web no existe un sistema de archivos real, así que mientras la
  /// pestaña sigue abierta se guarda una copia en memoria (la nube sigue
  /// siendo la fuente real de la verdad para la versión web).
  static Map<String, dynamic> _cacheWeb = {};

  static Future<File> _archivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_nombreArchivo');
  }

  static Future<Map<String, dynamic>> _leerTodo() async {
    if (kIsWeb) {
      return _cacheWeb;
    }
    try {
      final file = await _archivo();
      if (!await file.exists()) {
        return {};
      }
      final contenido = await file.readAsString();
      if (contenido.trim().isEmpty) {
        return {};
      }
      return jsonDecode(contenido) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  static Future<void> _escribirTodo(Map<String, dynamic> data) async {
    if (kIsWeb) {
      _cacheWeb = data;
      return;
    }
    final file = await _archivo();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<String?> obtenerNombreDoctor() async {
    final data = await _leerTodo();
    final nombre = data['nombreDoctor'] as String?;
    if (nombre == null || nombre.trim().isEmpty) {
      return null;
    }
    return nombre;
  }

  static Future<void> guardarNombreDoctor(String nombre) async {
    final data = await _leerTodo();
    data['nombreDoctor'] = nombre;
    await _escribirTodo(data);
    unawaited(SyncService.subirNombreDoctor(nombre));
  }

  /// Se llama una vez al iniciar sesión (o al abrir la app con sesión ya
  /// iniciada): si hay un nombre guardado en la nube y localmente no hay
  /// ninguno todavía (por ejemplo, un teléfono nuevo, o la versión web), lo
  /// trae. Si ya hay uno local pero la nube no tiene nada, lo sube.
  /// Devuelve el nombre final que debe usar la app (o null si no hay
  /// ninguno en ningún lado todavía).
  static Future<String?> sincronizarNombreAlIniciarSesion() async {
    final local = await obtenerNombreDoctor();
    final remoto = await SyncService.descargarNombreDoctor();
    if (local == null && remoto != null) {
      final data = await _leerTodo();
      data['nombreDoctor'] = remoto;
      await _escribirTodo(data);
      return remoto;
    }
    if (local != null && remoto == null) {
      unawaited(SyncService.subirNombreDoctor(local));
    }
    return local ?? remoto;
  }

  /// Indica si ya se le pidió al usuario el permiso de alarmas/notificaciones
  /// alguna vez, para no volver a interrumpirlo en cada apertura de la app.
  static Future<bool> yaSolicitoPermisos() async {
    if (kIsWeb) {
      return true;
    }
    final data = await _leerTodo();
    return data['permisosSolicitados'] == true;
  }

  static Future<void> marcarPermisosSolicitados() async {
    final data = await _leerTodo();
    data['permisosSolicitados'] = true;
    await _escribirTodo(data);
  }
}
