import 'package:flutter_test/flutter_test.dart';
import 'package:odontometas/models/ayuda_temas.dart';

void main() {
  test('cada tema tiene clave coherente, grupo válido y contenido', () {
    for (final e in temasAyuda.entries) {
      expect(e.value.clave, e.key);
      expect(ordenGruposAyuda.contains(e.value.grupo), isTrue, reason: e.key);
      expect(e.value.titulo.trim(), isNotEmpty, reason: e.key);
      expect(e.value.resumen.trim(), isNotEmpty, reason: e.key);
      expect(e.value.pasos, isNotEmpty, reason: e.key);
    }
  });

  test('existen los temas que usan las pantallas', () {
    const usados = [
      'presupuesto', 'pagos', 'caja_cobros', 'caja_porcobrar',
      'ficha_resumen', 'ficha_historia', 'ficha_evolucion', 'ficha_recetas',
      'ficha_consentimientos', 'firma', 'nube',
      'sheet_item', 'sheet_pago', 'sheet_ajustes', 'sheet_precios',
      'sheet_hallazgos', 'sheet_datos', 'sheet_condiciones', 'sheet_alergia',
      'sheet_medicamento', 'sheet_habitos', 'sheet_evolucion', 'sheet_receta',
      'sheet_consentimiento',
    ];
    for (final k in usados) {
      expect(temasAyuda.containsKey(k), isTrue, reason: k);
    }
  });

  test('las reglas sugeridas cubren las subcolecciones del usuario', () {
    expect(reglasFirestoreSugeridas.contains('/usuarios/{uid}/{documento=**}'), isTrue);
    expect(reglasFirestoreSugeridas.contains('request.auth.uid == uid'), isTrue);
  });
}
