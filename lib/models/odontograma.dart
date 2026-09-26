import 'periodontograma.dart' show dientesArcadaSuperior, dientesArcadaInferior;

/// Las 5 caras clínicas que se registran por diente en el odontograma.
enum CaraDental { vestibular, lingual, mesial, distal, oclusal }

const Map<CaraDental, String> etiquetaCara = {
  CaraDental.vestibular: 'Vestibular',
  CaraDental.lingual: 'Lingual / Palatina',
  CaraDental.mesial: 'Mesial',
  CaraDental.distal: 'Distal',
  CaraDental.oclusal: 'Oclusal / Incisal',
};

/// Estados clínicos posibles para una cara o para la pieza completa.
/// Los últimos 4 (ausente, implante, protesisFija, puente) son "de pieza
/// completa": cuando se elige uno, sustituye visualmente a las 5 caras.
enum EstadoDiente {
  sano,
  caries,
  obturado,
  sellante,
  fracturado,
  endodoncia,
  extraccionIndicada,
  ausente,
  implante,
  protesisFija,
  puente,
}

const Set<EstadoDiente> estadosDePiezaCompleta = {
  EstadoDiente.ausente,
  EstadoDiente.implante,
  EstadoDiente.protesisFija,
  EstadoDiente.puente,
};

class EstiloEstadoDiente {
  final int colorValue; // ARGB, para no depender de material aquí
  final String etiqueta;
  const EstiloEstadoDiente(this.colorValue, this.etiqueta);
}

/// Paleta profesional tipo Dentalink. colorValue es 0xAARRGGBB.
const Map<EstadoDiente, EstiloEstadoDiente> estiloEstadoDiente = {
  EstadoDiente.sano: EstiloEstadoDiente(0xFFFFFFFF, 'Sano'),
  EstadoDiente.caries: EstiloEstadoDiente(0xFFE53935, 'Caries'),
  EstadoDiente.obturado: EstiloEstadoDiente(0xFF1E88E5, 'Obturado'),
  EstadoDiente.sellante: EstiloEstadoDiente(0xFF43A047, 'Sellante'),
  EstadoDiente.fracturado: EstiloEstadoDiente(0xFFFB8C00, 'Fracturado'),
  EstadoDiente.endodoncia: EstiloEstadoDiente(0xFF8E24AA, 'Endodoncia'),
  EstadoDiente.extraccionIndicada:
      EstiloEstadoDiente(0xFFD32F2F, 'Extracción indicada'),
  EstadoDiente.ausente: EstiloEstadoDiente(0xFFBDBDBD, 'Ausente'),
  EstadoDiente.implante: EstiloEstadoDiente(0xFF00897B, 'Implante'),
  EstadoDiente.protesisFija:
      EstiloEstadoDiente(0xFFFFB300, 'Corona / prótesis fija'),
  EstadoDiente.puente: EstiloEstadoDiente(0xFF6D4C41, 'Puente'),
};

/// Orden de prioridad para decidir con qué color se pinta el diente en el
/// mapa general cuando tiene varias caras afectadas (se usa la más grave).
const List<EstadoDiente> _prioridadVisual = [
  EstadoDiente.extraccionIndicada,
  EstadoDiente.caries,
  EstadoDiente.fracturado,
  EstadoDiente.endodoncia,
  EstadoDiente.obturado,
  EstadoDiente.sellante,
  EstadoDiente.sano,
];

/// Registro clínico de una pieza dental dentro de un odontograma.
class DienteOdontograma {
  String numeroFdi;
  Map<CaraDental, EstadoDiente> caras;
  EstadoDiente? estadoGeneral; // no nulo si es ausente/implante/PF/puente
  String? notas;

  DienteOdontograma({
    required this.numeroFdi,
    Map<CaraDental, EstadoDiente>? caras,
    this.estadoGeneral,
    this.notas,
  }) : caras = caras ??
            {for (final c in CaraDental.values) c: EstadoDiente.sano};

  bool get tieneHallazgo =>
      estadoGeneral != null || caras.values.any((e) => e != EstadoDiente.sano);

  /// Estado que decide el color con el que se pinta el diente completo.
  EstadoDiente get estadoVisual {
    if (estadoGeneral != null) return estadoGeneral!;
    for (final estado in _prioridadVisual) {
      if (caras.values.contains(estado)) return estado;
    }
    return EstadoDiente.sano;
  }

  Map<String, dynamic> toMap() {
    return {
      'numeroFdi': numeroFdi,
      'caras': caras.map((k, v) => MapEntry(k.name, v.name)),
      'estadoGeneral': estadoGeneral?.name,
      'notas': notas,
    };
  }

  factory DienteOdontograma.fromMap(Map<String, dynamic> map) {
    final rawCaras = (map['caras'] as Map?) ?? {};
    return DienteOdontograma(
      numeroFdi: map['numeroFdi'] ?? '',
      caras: {
        for (final c in CaraDental.values)
          c: EstadoDiente.values.firstWhere(
            (e) => e.name == rawCaras[c.name],
            orElse: () => EstadoDiente.sano,
          ),
      },
      estadoGeneral: map['estadoGeneral'] == null
          ? null
          : EstadoDiente.values
              .firstWhere((e) => e.name == map['estadoGeneral']),
      notas: map['notas'],
    );
  }
}

/// Un odontograma completo del paciente en una fecha dada (una "foto" del
/// estado de sus 32 piezas). Un paciente puede tener varios en el tiempo,
/// igual que ya ocurre con los periodontogramas.
class Odontograma {
  String id;
  DateTime fecha;
  String? notas;
  Map<String, DienteOdontograma> dientes;

  Odontograma({
    required this.id,
    required this.fecha,
    this.notas,
    Map<String, DienteOdontograma>? dientes,
  }) : dientes = dientes ??
            {
              for (final n in [...dientesArcadaSuperior, ...dientesArcadaInferior])
                n: DienteOdontograma(numeroFdi: n),
            };

  /// Resumen clínico (cuenta piezas/caras por estado), base para el
  /// presupuesto.
  Map<EstadoDiente, int> resumenPorEstado() {
    final resumen = <EstadoDiente, int>{};
    for (final d in dientes.values) {
      if (d.estadoGeneral != null) {
        resumen[d.estadoGeneral!] = (resumen[d.estadoGeneral!] ?? 0) + 1;
      } else {
        for (final e in d.caras.values) {
          if (e != EstadoDiente.sano) {
            resumen[e] = (resumen[e] ?? 0) + 1;
          }
        }
      }
    }
    return resumen;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'notas': notas,
      'dientes': dientes.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory Odontograma.fromMap(Map<String, dynamic> map) {
    final rawDientes = (map['dientes'] as Map?) ?? {};
    final dientes = <String, DienteOdontograma>{};
    for (final n in [...dientesArcadaSuperior, ...dientesArcadaInferior]) {
      final valor = rawDientes[n];
      dientes[n] = valor != null
          ? DienteOdontograma.fromMap(Map<String, dynamic>.from(valor))
          : DienteOdontograma(numeroFdi: n);
    }
    return Odontograma(
      id: map['id'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      notas: map['notas'],
      dientes: dientes,
    );
  }
}
