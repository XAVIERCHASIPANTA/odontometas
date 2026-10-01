import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/meta_goal.dart';
import 'nube_docs.dart';

enum FaseNube { sinSesion, inactiva, sincronizando, ok, error }

/// Estado visible del respaldo en la nube (se muestra en el Centro de ayuda).
class EstadoNube {
  final FaseNube fase;
  final String mensaje;
  final DateTime? ultima;
  final List<String> advertencias;
  const EstadoNube({
    required this.fase,
    this.mensaje = '',
    this.ultima,
    this.advertencias = const [],
  });
}

/// Resumen de lo que hay guardado en la nube.
class ResumenNube {
  final int pacientes;
  final int metas;
  final bool formatoNuevo;
  const ResumenNube(this.pacientes, this.metas, this.formatoNuevo);
}

/// Respaldo en Firestore, asociado a la cuenta con sesión iniciada.
///
/// Formato 2 (actual): un documento por paciente y otro por meta, dentro de
/// `usuarios/{uid}/pacientes` y `usuarios/{uid}/metas`. Solo se sube lo que
/// cambió. El formato anterior (todo en un solo documento `usuarios/{uid}`,
/// campo `metas`) se migra solo la primera vez y NO se borra: queda como
/// respaldo.
class SyncService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static final ValueNotifier<EstadoNube> estado =
      ValueNotifier(const EstadoNube(fase: FaseNube.inactiva));

  /// True si lo último que se descargó estaba en el formato anterior.
  static bool remotoEsLegacy = false;

  // Lo último que sabemos que está en la nube (id -> json) para subir solo
  // lo que cambia.
  static String? _uidCache;
  static final Map<String, String> _jsonPacientes = {};
  static final Map<String, String> _jsonMetas = {};
  static bool _formatoConfirmado = false;

  static DocsNube? _pendiente;
  static Future<void>? _ciclo;

  // ---------------------------------------------------------------------
  // Marca local "hay cambios sin subir" (evita perder datos al reabrir)
  // ---------------------------------------------------------------------

  static const String _archivoEstado = 'odontometas_sync.json';
  static bool _pendienteMemoria = false;

  static Future<File> _archivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_archivoEstado');
  }

  static Future<Map<String, dynamic>> _leerEstadoLocal() async {
    if (kIsWeb) {
      return {'pendiente': _pendienteMemoria};
    }
    try {
      final f = await _archivo();
      if (!await f.exists()) {
        return {};
      }
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) {
        return {};
      }
      return Map<String, dynamic>.from(jsonDecode(txt) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _escribirEstadoLocal(Map<String, dynamic> datos) async {
    if (kIsWeb) {
      _pendienteMemoria = datos['pendiente'] == true;
      return;
    }
    try {
      final f = await _archivo();
      await f.writeAsString(jsonEncode(datos));
    } catch (_) {
      // Si no se puede guardar la marca, la app sigue funcionando igual.
    }
  }

  /// Se llama en cada guardado local, antes de intentar subir.
  static Future<void> marcarPendiente() async {
    if (_pendienteMemoria) {
      return;
    }
    _pendienteMemoria = true;
    final datos = await _leerEstadoLocal();
    datos['pendiente'] = true;
    await _escribirEstadoLocal(datos);
  }

  static Future<void> _marcarSincronizado() async {
    _pendienteMemoria = false;
    final datos = await _leerEstadoLocal();
    datos['pendiente'] = false;
    datos['ultima'] = DateTime.now().toIso8601String();
    await _escribirEstadoLocal(datos);
  }

  /// True si este dispositivo tiene cambios que aún no llegaron a la nube.
  static Future<bool> hayCambiosSinSubir() async {
    final datos = await _leerEstadoLocal();
    return datos['pendiente'] == true;
  }

  // ---------------------------------------------------------------------
  // Estado visible
  // ---------------------------------------------------------------------

  static void _publicar(
    FaseNube fase,
    String mensaje, {
    List<String> advertencias = const [],
    bool conFecha = false,
  }) {
    estado.value = EstadoNube(
      fase: fase,
      mensaje: mensaje,
      ultima: conFecha ? DateTime.now() : estado.value.ultima,
      advertencias: advertencias,
    );
  }

  static String _mensajeError(Object e) {
    if (e is TimeoutException) {
      return 'Sin respuesta de la nube. Se guardará cuando haya conexión.';
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Firebase rechazó el guardado por PERMISOS. Falta agregar la '
              'regla para las subcolecciones (mira "Reglas de Firestore" abajo).';
        case 'unavailable':
        case 'network-request-failed':
          return 'Sin conexión: los cambios están en el teléfono y se subirán '
              'cuando vuelva internet.';
        case 'unauthenticated':
          return 'La sesión de Google expiró. Cierra sesión y vuelve a entrar.';
        default:
          return 'Error de la nube (${e.code}): ${e.message ?? 'sin detalle'}';
      }
    }
    return 'Error inesperado: $e';
  }

  // ---------------------------------------------------------------------
  // Subida
  // ---------------------------------------------------------------------

  /// Sube a la nube solo lo que cambió. Si no hay sesión o falla la
  /// conexión no interrumpe nada: la app sigue con el archivo local y la
  /// marca de "pendiente" hace que se reintente.
  static Future<void> subirNube(List<MetaGoal> metas) {
    if (_uid == null) {
      _publicar(FaseNube.sinSesion, 'Sin sesión iniciada: los datos solo están en este teléfono.');
      return Future.value();
    }
    // Se fotografía el estado AHORA (los objetos siguen cambiando).
    _pendiente = DocsNube.construir(metas);
    _ciclo ??= _procesar().whenComplete(() => _ciclo = null);
    return _ciclo!;
  }

  static Future<void> _procesar() async {
    while (_pendiente != null) {
      final docs = _pendiente!;
      _pendiente = null;
      try {
        _publicar(FaseNube.sincronizando, 'Guardando en la nube…');
        final avisos = await _subirDocs(docs);
        if (_pendiente == null) {
          await _marcarSincronizado();
        }
        _publicar(
          FaseNube.ok,
          avisos.isEmpty
              ? 'Todo respaldado en la nube.'
              : 'Respaldado, con avisos.',
          advertencias: avisos,
          conFecha: true,
        );
      } catch (e) {
        _publicar(FaseNube.error, _mensajeError(e));
        // Se descarta lo pendiente: el siguiente guardado (o "Sincronizar
        // ahora") reintenta con el estado más reciente.
        _pendiente = null;
      }
    }
  }

  static void _verificarUsuario(String uid) {
    if (_uidCache != uid) {
      _jsonPacientes.clear();
      _jsonMetas.clear();
      _formatoConfirmado = false;
      _uidCache = uid;
    }
  }

  static Future<List<String>> _subirDocs(DocsNube docs) async {
    final uid = _uid;
    if (uid == null) {
      return const [];
    }
    _verificarUsuario(uid);
    final raiz = _db.collection('usuarios').doc(uid);
    final plan = PlanificadorNube.planificar(
      previosPacientes: _jsonPacientes,
      previosMetas: _jsonMetas,
      deseado: docs,
    );

    // 1) Pacientes primero, 2) metas después, 3) borrados al final: así una
    //    casilla nunca apunta a un paciente que todavía no existe.
    await _escribirFase(
      raiz.collection('pacientes'),
      plan.pacientesEscribir,
    );
    _jsonPacientes.addAll(plan.pacientesJson);

    await _escribirFase(raiz.collection('metas'), plan.metasEscribir);
    _jsonMetas.addAll(plan.metasJson);

    await _borrarFase(raiz.collection('pacientes'), plan.pacientesBorrar);
    for (final id in plan.pacientesBorrar) {
      _jsonPacientes.remove(id);
    }
    await _borrarFase(raiz.collection('metas'), plan.metasBorrar);
    for (final id in plan.metasBorrar) {
      _jsonMetas.remove(id);
    }

    if (!_formatoConfirmado) {
      await _confirmarFormato(raiz, docs);
    } else {
      await raiz.set(
        {'actualizadoEn': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    return plan.advertencias;
  }

  static Future<void> _escribirFase(
    CollectionReference<Map<String, dynamic>> coleccion,
    Map<String, Map<String, dynamic>> datos,
  ) async {
    final entradas = datos.entries.toList();
    for (var i = 0; i < entradas.length; i += 400) {
      final lote = _db.batch();
      for (final e in entradas.skip(i).take(400)) {
        lote.set(
          coleccion.doc(e.key),
          {...e.value, 'actualizadoEn': FieldValue.serverTimestamp()},
        );
      }
      await lote.commit();
    }
  }

  static Future<void> _borrarFase(
    CollectionReference<Map<String, dynamic>> coleccion,
    List<String> ids,
  ) async {
    for (var i = 0; i < ids.length; i += 400) {
      final lote = _db.batch();
      for (final id in ids.skip(i).take(400)) {
        lote.delete(coleccion.doc(id));
      }
      await lote.commit();
    }
  }

  /// Marca la nube como "formato 2" SOLO si, tras subir, la cantidad de
  /// documentos coincide con lo esperado. Hasta entonces sigue valiendo el
  /// respaldo anterior.
  static Future<void> _confirmarFormato(
    DocumentReference<Map<String, dynamic>> raiz,
    DocsNube docs,
  ) async {
    final enNube = await raiz.collection('pacientes').count().get();
    final metasNube = await raiz.collection('metas').count().get();
    final pacientesEnNube = enNube.count ?? 0;
    final metasEnNube = metasNube.count ?? 0;
    if (pacientesEnNube < _jsonPacientes.length || metasEnNube < docs.metas.length) {
      throw StateError(
        'La verificación de la nube no coincidió (pacientes $pacientesEnNube, '
        'esperados ${_jsonPacientes.length}). Se mantiene el respaldo anterior.',
      );
    }
    await raiz.set({
      'formato': 2,
      'migradoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _formatoConfirmado = true;
    remotoEsLegacy = false;
  }

  /// Sube todo lo local ahora mismo (botón "Sincronizar ahora").
  static Future<void> sincronizarAhora(List<MetaGoal> locales) async {
    await marcarPendiente();
    await subirNube(locales);
  }

  // ---------------------------------------------------------------------
  // Descarga
  // ---------------------------------------------------------------------

  /// Descarga la última copia de la nube. Devuelve null si no hay sesión, si
  /// todavía no hay datos guardados, o si falla la conexión (en esos casos
  /// la app conserva lo que tiene en el teléfono).
  static Future<List<MetaGoal>?> descargarNube() async {
    final uid = _uid;
    if (uid == null) {
      _publicar(FaseNube.sinSesion, 'Sin sesión iniciada.');
      return null;
    }
    _verificarUsuario(uid);
    try {
      _publicar(FaseNube.sincronizando, 'Descargando de la nube…');
      final raiz = _db.collection('usuarios').doc(uid);
      final snap = await raiz.get().timeout(const Duration(seconds: 25));
      if (!snap.exists) {
        _publicar(FaseNube.ok, 'La nube todavía está vacía.');
        return null;
      }
      final datos = snap.data();
      if (datos?['formato'] == 2) {
        final metasSnap = await raiz.collection('metas').get();
        final pacSnap = await raiz.collection('pacientes').get();
        final docsMetas = metasSnap.docs
            .map((d) => Map<String, dynamic>.from(d.data()))
            .toList();
        final docsPac = {
          for (final d in pacSnap.docs) d.id: Map<String, dynamic>.from(d.data()),
        };
        final lista = DocsNube.ensamblar(docsMetas, docsPac);
        _sembrar(lista);
        remotoEsLegacy = false;
        _publicar(FaseNube.ok, 'Datos al día con la nube.', conFecha: true);
        return lista;
      }
      // Formato anterior: todo en un solo documento.
      final crudo = (datos?['metas'] as List?) ?? const [];
      if (crudo.isEmpty) {
        // Solo existen otros campos (p. ej. el nombre del doctor): no hay
        // datos que traer, y NO se debe vaciar lo que hay en el teléfono.
        remotoEsLegacy = false;
        _publicar(FaseNube.ok, 'La nube todavía no tiene pacientes.');
        return null;
      }
      final lista = crudo
          .map((e) => MetaGoal.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      remotoEsLegacy = true;
      _publicar(FaseNube.ok, 'Datos descargados (formato anterior).', conFecha: true);
      return lista;
    } catch (e) {
      _publicar(FaseNube.error, _mensajeError(e));
      return null;
    }
  }

  /// Anota lo que acaba de descargarse como "ya está en la nube".
  static void _sembrar(List<MetaGoal> lista) {
    final docs = DocsNube.construir(lista);
    _jsonPacientes
      ..clear()
      ..addAll({
        for (final e in docs.pacientes.entries) e.key: DocsNube.serializar(e.value),
      });
    _jsonMetas
      ..clear()
      ..addAll({
        for (final e in docs.metas.entries) e.key: DocsNube.serializar(e.value),
      });
    _formatoConfirmado = true;
  }

  /// Cuenta lo que hay en la nube (para mostrarlo en el Centro de ayuda).
  static Future<ResumenNube?> contarNube() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    try {
      final raiz = _db.collection('usuarios').doc(uid);
      final snap = await raiz.get().timeout(const Duration(seconds: 20));
      final nuevo = snap.data()?['formato'] == 2;
      final pac = await raiz.collection('pacientes').count().get();
      final met = await raiz.collection('metas').count().get();
      return ResumenNube(pac.count ?? 0, met.count ?? 0, nuevo);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Nombre del doctor (sin cambios)
  // ---------------------------------------------------------------------

  /// Sube el nombre del doctor a la nube (documento principal del usuario).
  static Future<void> subirNombreDoctor(String nombre) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      await _db.collection('usuarios').doc(uid).set({
        'nombreDoctor': nombre,
      }, SetOptions(merge: true));
    } catch (_) {
      // Sin conexión u otro error: no interrumpe el uso local de la app.
    }
  }

  /// Descarga el nombre del doctor guardado en la nube. Devuelve null si no
  /// hay sesión iniciada, no existe todavía, o falla la conexión.
  static Future<String?> descargarNombreDoctor() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      final nombre = doc.data()?['nombreDoctor'] as String?;
      if (nombre == null || nombre.trim().isEmpty) {
        return null;
      }
      return nombre;
    } catch (_) {
      return null;
    }
  }
}
