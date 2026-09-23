/// Modelo de Evaluación del Riesgo Periodontal (PRA), según Lang & Tonetti
/// (2003), publicado y documentado en www.perio-tools.com/risk-assessment
/// (licencia Creative Commons BY-NC-SA 4.0).
///
/// Considera 6 parámetros: % de sangrado al sondaje (BOP%), número de
/// bolsas ≥5mm, número de dientes perdidos, relación pérdida ósea/edad,
/// factores sistémicos y factores ambientales (tabaquismo).
class EvaluacionRiesgo {
  String id;
  DateTime fecha;
  bool esReevaluacion;

  int edad;
  int dientesEImplantes; // 1-32
  int sitiosPorDiente; // 2, 4 o 6
  int sitiosBopPositivos;
  int sitiosConBolsaProfunda; // PPD >= 5mm
  int dientesPerdidos; // 0-28 (sin terceros molares)
  int porcentajePerdidaOsea; // en incrementos de 10%
  bool factorSistemico; // Sí/No
  NivelTabaquismo tabaquismo;

  EvaluacionRiesgo({
    required this.id,
    required this.fecha,
    this.esReevaluacion = false,
    this.edad = 0,
    this.dientesEImplantes = 32,
    this.sitiosPorDiente = 6,
    this.sitiosBopPositivos = 0,
    this.sitiosConBolsaProfunda = 0,
    this.dientesPerdidos = 0,
    this.porcentajePerdidaOsea = 0,
    this.factorSistemico = false,
    this.tabaquismo = NivelTabaquismo.noFumador,
  });

  int get totalSitios => dientesEImplantes * sitiosPorDiente;

  double get porcentajeBop {
    if (totalSitios == 0) {
      return 0;
    }
    return (sitiosBopPositivos / totalSitios) * 100;
  }

  double get relacionPerdidaOseaEdad {
    if (edad <= 0) {
      return 0;
    }
    return porcentajePerdidaOsea / edad;
  }

  /// Nivel de riesgo (0=bajo, 1=moderado, 2=alto) de cada eje, según los
  /// puntos de corte publicados por Lang & Tonetti / perio-tools.com.
  int get nivelBop {
    final v = porcentajeBop;
    if (v < 10) return 0;
    if (v <= 25) return 1;
    return 2;
  }

  int get nivelBolsaProfunda {
    final v = sitiosConBolsaProfunda;
    if (v <= 4) return 0;
    if (v <= 8) return 1;
    return 2;
  }

  int get nivelDientesPerdidos {
    final v = dientesPerdidos;
    if (v <= 4) return 0;
    if (v <= 8) return 1;
    return 2;
  }

  int get nivelPerdidaOseaEdad {
    final v = relacionPerdidaOseaEdad;
    if (v <= 0.5) return 0;
    if (v <= 1.0) return 1;
    return 2;
  }

  int get nivelSistemico => factorSistemico ? 2 : 0;

  int get nivelTabaquismo {
    switch (tabaquismo) {
      case NivelTabaquismo.noFumador:
      case NivelTabaquismo.exFumador:
        return 0;
      case NivelTabaquismo.ocasional:
      case NivelTabaquismo.fumador:
        return 1;
      case NivelTabaquismo.granFumador:
        return 2;
    }
  }

  /// Categoría de riesgo global, siguiendo la regla estándar: bajo si todos
  /// los ejes están en riesgo bajo (o a lo sumo uno en moderado); alto si
  /// hay al menos dos ejes en riesgo alto; moderado en los demás casos.
  RiesgoPeriodontal get riesgoGlobal {
    final niveles = [
      nivelBop,
      nivelBolsaProfunda,
      nivelDientesPerdidos,
      nivelPerdidaOseaEdad,
      nivelSistemico,
      nivelTabaquismo,
    ];
    final altos = niveles.where((n) => n == 2).length;
    final moderados = niveles.where((n) => n == 1).length;
    if (altos >= 2) {
      return RiesgoPeriodontal.alto;
    }
    if (altos == 1 || moderados >= 2) {
      return RiesgoPeriodontal.moderado;
    }
    return RiesgoPeriodontal.bajo;
  }

  String get recomendacion {
    switch (riesgoGlobal) {
      case RiesgoPeriodontal.bajo:
        return 'Mantener las medidas actuales.';
      case RiesgoPeriodontal.moderado:
        return 'Reforzar la higiene oral y controlar los factores de riesgo modificables.';
      case RiesgoPeriodontal.alto:
        return 'Intensificar la terapia periodontal de soporte y controlar estrictamente los factores de riesgo modificables.';
    }
  }

  String get intervaloSugerido {
    switch (riesgoGlobal) {
      case RiesgoPeriodontal.bajo:
        return 'cada 12 meses (orientativo)';
      case RiesgoPeriodontal.moderado:
        return 'cada 6 meses (orientativo)';
      case RiesgoPeriodontal.alto:
        return 'cada 3 meses (orientativo)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'esReevaluacion': esReevaluacion,
      'edad': edad,
      'dientesEImplantes': dientesEImplantes,
      'sitiosPorDiente': sitiosPorDiente,
      'sitiosBopPositivos': sitiosBopPositivos,
      'sitiosConBolsaProfunda': sitiosConBolsaProfunda,
      'dientesPerdidos': dientesPerdidos,
      'porcentajePerdidaOsea': porcentajePerdidaOsea,
      'factorSistemico': factorSistemico,
      'tabaquismo': tabaquismo.name,
    };
  }

  factory EvaluacionRiesgo.fromMap(Map<String, dynamic> map) {
    return EvaluacionRiesgo(
      id: map['id'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      esReevaluacion: map['esReevaluacion'] ?? false,
      edad: map['edad'] ?? 0,
      dientesEImplantes: map['dientesEImplantes'] ?? 32,
      sitiosPorDiente: map['sitiosPorDiente'] ?? 6,
      sitiosBopPositivos: map['sitiosBopPositivos'] ?? 0,
      sitiosConBolsaProfunda: map['sitiosConBolsaProfunda'] ?? 0,
      dientesPerdidos: map['dientesPerdidos'] ?? 0,
      porcentajePerdidaOsea: map['porcentajePerdidaOsea'] ?? 0,
      factorSistemico: map['factorSistemico'] ?? false,
      tabaquismo: NivelTabaquismo.values.firstWhere(
        (v) => v.name == map['tabaquismo'],
        orElse: () => NivelTabaquismo.noFumador,
      ),
    );
  }
}

enum NivelTabaquismo { noFumador, exFumador, ocasional, fumador, granFumador }

extension NivelTabaquismoEtiqueta on NivelTabaquismo {
  String get etiqueta {
    switch (this) {
      case NivelTabaquismo.noFumador:
        return 'No fumador (NS)';
      case NivelTabaquismo.exFumador:
        return 'Ex fumador (FS)';
      case NivelTabaquismo.ocasional:
        return 'Fumador ocasional (OS)';
      case NivelTabaquismo.fumador:
        return 'Fumador (S)';
      case NivelTabaquismo.granFumador:
        return 'Gran fumador (HS)';
    }
  }
}

enum RiesgoPeriodontal { bajo, moderado, alto }

extension RiesgoPeriodontalEtiqueta on RiesgoPeriodontal {
  String get etiqueta {
    switch (this) {
      case RiesgoPeriodontal.bajo:
        return 'bajo';
      case RiesgoPeriodontal.moderado:
        return 'moderado';
      case RiesgoPeriodontal.alto:
        return 'alto';
    }
  }
}
