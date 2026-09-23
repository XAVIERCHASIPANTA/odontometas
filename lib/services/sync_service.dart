import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meta_goal.dart';

/// Sube y descarga el respaldo completo de metas/pacientes (y datos de
/// configuración como el nombre del doctor) en Firestore, asociado a la
/// cuenta de Google de la persona con sesión iniciada. Todas las
/// escrituras usan "merge" para no borrar accidentalmente otros campos
/// del mismo documento (por ejemplo, subir las metas no debe borrar el
/// nombre del doctor, y viceversa).
class SyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Sube la lista completa a la nube. Si no hay sesión iniciada o falla la
  /// conexión, no hace nada — la app sigue funcionando con el archivo local.
  static Future<void> subirNube(List<MetaGoal> metas) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      await _db.collection('usuarios').doc(uid).set({
        'metas': metas.map((m) => m.toMap()).toList(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Sin conexión u otro error: no interrumpe el uso local de la app.
    }
  }

  /// Descarga la última copia guardada en la nube. Devuelve null si no hay
  /// sesión iniciada, no existe respaldo todavía, o falla la conexión.
  static Future<List<MetaGoal>?> descargarNube() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      final data = doc.data();
      final rawMetas = (data?['metas'] as List?) ?? [];
      return rawMetas
          .map((e) => MetaGoal.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Sube el nombre del doctor a la nube (mismo documento que las metas,
  /// campo separado).
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
