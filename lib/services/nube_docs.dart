import 'dart:convert';
import '../models/meta_goal.dart';
import '../models/paciente.dart';

/// Lógica PURA (sin Firebase) del respaldo en la nube "un documento por
/// paciente". Está separada de [SyncService] para poder probarla sin
/// conexión.
///
/// Estructura en Firestore, bajo `usuarios/{uid}`:
///   - `metas/{idMeta}`         → título, tamaño, orden y `slots` (lista con
///                                 el id del paciente de cada casilla, o null)
///   - `pacientes/{idPaciente}` → todos los datos de ese paciente
class DocsNube {
  /// idMeta -> datos del documento de la meta.
  final Map<String, Map<String, dynamic>> metas;

  /// idPaciente -> datos del documento del paciente.
  final Map<String, Map<String, dynamic>> pacientes;

  /// Avisos detectados al construir (por ejemplo, ids repetidos).
  final List<String> advertencias;

  DocsNube(this.metas, this.pacientes, this.advertencias);

  factory DocsNube.construir(List<MetaGoal> metas) {
    final docsMetas = <String, Map<String, dynamic>>{};
    final docsPacientes = <String, Map<String, dynamic>>{};
    final avisos = <String>[];
    for (var i = 0; i < metas.length; i++) {
      final meta = metas[i];
      final slots = <String?>[];
      for (final p in meta.pacientes) {
        if (p == null) {
          slots.add(null);
          continue;
        }
        if (docsPacientes.containsKey(p.id)) {
          avisos.add('Id de paciente repetido: ${p.id}');
        }
        final datos = p.toMap();
        datos['metaId'] = meta.id;
        docsPacientes[p.id] = datos;
        slots.add(p.id);
      }
      docsMetas[meta.id] = {
        'id': meta.id,
        'titulo': meta.titulo,
        'metaNumero': meta.metaNumero,
        'orden': i,
        'slots': slots,
      };
    }
    return DocsNube(docsMetas, docsPacientes, avisos);
  }

  /// Reconstruye la lista de metas a partir de los documentos descargados.
  /// Si una casilla apunta a un paciente que no está (por ejemplo, una
  /// subida interrumpida), queda vacía en lugar de fallar.
  static List<MetaGoal> ensamblar(
    List<Map<String, dynamic>> docsMetas,
    Map<String, Map<String, dynamic>> docsPacientes,
  ) {
    final ordenadas = List<Map<String, dynamic>>.from(docsMetas)
      ..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));
    final resultado = <MetaGoal>[];
    for (final m in ordenadas) {
      final slots = (m['slots'] as List?) ?? const [];
      final pacientes = <Map<String, dynamic>?>[];
      for (final id in slots) {
        if (id == null) {
          pacientes.add(null);
        } else {
          final d = docsPacientes[id.toString()];
          pacientes.add(d == null ? null : Map<String, dynamic>.from(d));
        }
      }
      resultado.add(MetaGoal.fromMap({
        'id': m['id'],
        'titulo': m['titulo'],
        'metaNumero': m['metaNumero'],
        'pacientes': pacientes,
      }));
    }
    return resultado;
  }

  static String serializar(Map<String, dynamic> datos) => jsonEncode(datos);

  /// Cantidad aproximada de bytes que ocupará el documento.
  static int tamano(String json) => utf8.encode(json).length;
}

/// Lo que hay que enviar a la nube para dejarla igual que lo local.
class PlanSync {
  /// id -> (datos, json). Solo lo que cambió.
  final Map<String, Map<String, dynamic>> pacientesEscribir;
  final Map<String, String> pacientesJson;
  final Map<String, Map<String, dynamic>> metasEscribir;
  final Map<String, String> metasJson;
  final List<String> pacientesBorrar;
  final List<String> metasBorrar;
  final List<String> advertencias;

  PlanSync({
    required this.pacientesEscribir,
    required this.pacientesJson,
    required this.metasEscribir,
    required this.metasJson,
    required this.pacientesBorrar,
    required this.metasBorrar,
    required this.advertencias,
  });

  bool get vacio =>
      pacientesEscribir.isEmpty &&
      metasEscribir.isEmpty &&
      pacientesBorrar.isEmpty &&
      metasBorrar.isEmpty;

  int get totalOperaciones =>
      pacientesEscribir.length +
      metasEscribir.length +
      pacientesBorrar.length +
      metasBorrar.length;
}

class PlanificadorNube {
  /// Límite de seguridad por documento (Firestore admite 1 MiB).
  static const int limiteBytes = 900000;

  /// Compara lo deseado con lo último que se sabe que está en la nube
  /// ([previosPacientes] / [previosMetas]: id -> json) y arma el plan.
  static PlanSync planificar({
    required Map<String, String> previosPacientes,
    required Map<String, String> previosMetas,
    required DocsNube deseado,
  }) {
    final avisos = List<String>.from(deseado.advertencias);

    final pacEscribir = <String, Map<String, dynamic>>{};
    final pacJson = <String, String>{};
    final pacEnNube = <String>{}; // ids que quedarán/están válidos en la nube
    deseado.pacientes.forEach((id, datos) {
      final json = DocsNube.serializar(datos);
      if (DocsNube.tamano(json) > limiteBytes) {
        final nombre = (datos['nombre'] ?? id).toString();
        avisos.add(
          'El paciente "$nombre" ocupa demasiado espacio para la nube y no se '
          'pudo respaldar (quita adjuntos o textos muy largos).',
        );
        // Si ya estaba en la nube, se conserva lo anterior.
        if (previosPacientes.containsKey(id)) {
          pacEnNube.add(id);
        }
        return;
      }
      pacEnNube.add(id);
      if (previosPacientes[id] != json) {
        pacEscribir[id] = datos;
        pacJson[id] = json;
      }
    });

    final metaEscribir = <String, Map<String, dynamic>>{};
    final metaJson = <String, String>{};
    deseado.metas.forEach((id, datos) {
      final json = DocsNube.serializar(datos);
      if (previosMetas[id] != json) {
        metaEscribir[id] = datos;
        metaJson[id] = json;
      }
    });

    var pacBorrar = previosPacientes.keys
        .where((id) => !deseado.pacientes.containsKey(id))
        .toList();
    var metaBorrar =
        previosMetas.keys.where((id) => !deseado.metas.containsKey(id)).toList();

    // Freno de seguridad: si lo local quedó totalmente vacío pero la nube
    // tenía datos, casi seguro es un error (no se borra todo por accidente).
    if (deseado.pacientes.isEmpty && previosPacientes.isNotEmpty) {
      avisos.add(
        'Se omitió borrar ${pacBorrar.length} paciente(s) de la nube porque la '
        'lista local está vacía (protección contra borrado accidental).',
      );
      pacBorrar = [];
    }
    if (deseado.metas.isEmpty && previosMetas.isNotEmpty) {
      metaBorrar = [];
    }

    return PlanSync(
      pacientesEscribir: pacEscribir,
      pacientesJson: pacJson,
      metasEscribir: metaEscribir,
      metasJson: metaJson,
      pacientesBorrar: pacBorrar,
      metasBorrar: metaBorrar,
      advertencias: avisos,
    );
  }
}
