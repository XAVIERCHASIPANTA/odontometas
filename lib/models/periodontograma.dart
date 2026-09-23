/// Un "sitio" es uno de los 6 puntos de sondaje que se miden por diente
/// (vestibular: mesial/central/distal, y palatino o lingual: mesial/central/distal).
class SitioPeriodontal {
  int profundidadSondaje; // en milímetros (típicamente 1-15)
  int recesion; // en milímetros (0 si no hay recesión)
  bool sangrado; // sangrado al sondaje
  bool placa; // presencia de placa bacteriana

  SitioPeriodontal({
    this.profundidadSondaje = 0,
    this.recesion = 0,
    this.sangrado = false,
    this.placa = false,
  });

  /// Nivel de inserción clínica = profundidad de sondaje + recesión.
  int get nivelInsercionClinica => profundidadSondaje + recesion;

  Map<String, dynamic> toMap() {
    return {
      'pd': profundidadSondaje,
      'rec': recesion,
      'sangrado': sangrado,
      'placa': placa,
    };
  }

  factory SitioPeriodontal.fromMap(Map<String, dynamic> map) {
    return SitioPeriodontal(
      profundidadSondaje: map['pd'] ?? 0,
      recesion: map['rec'] ?? 0,
      sangrado: map['sangrado'] ?? false,
      placa: map['placa'] ?? false,
    );
  }
}

/// Los 6 puntos estándar que se registran por diente en un periodontograma
/// clínico completo.
const List<String> clavesSitios = [
  'vest_mesial',
  'vest_central',
  'vest_distal',
  'palat_mesial',
  'palat_central',
  'palat_distal',
];

class DienteRegistro {
  String numeroFdi;
  bool ausente;
  int movilidad; // grado 0-3
  int furca; // grado 0-3 (solo aplica a molares)
  Map<String, SitioPeriodontal> sitios;

  DienteRegistro({
    required this.numeroFdi,
    this.ausente = false,
    this.movilidad = 0,
    this.furca = 0,
    Map<String, SitioPeriodontal>? sitios,
  }) : sitios = sitios ??
            {for (final clave in clavesSitios) clave: SitioPeriodontal()};

  /// La profundidad de sondaje más alta entre los 6 sitios (para colorear
  /// el diente en el gráfico general).
  int get profundidadMaxima {
    if (sitios.isEmpty) {
      return 0;
    }
    return sitios.values
        .map((s) => s.profundidadSondaje)
        .reduce((a, b) => a > b ? a : b);
  }

  bool get tieneSangradoEnAlgunSitio =>
      sitios.values.any((s) => s.sangrado);

  bool get tienePlacaEnAlgunSitio => sitios.values.any((s) => s.placa);

  Map<String, dynamic> toMap() {
    return {
      'numeroFdi': numeroFdi,
      'ausente': ausente,
      'movilidad': movilidad,
      'furca': furca,
      'sitios': sitios.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory DienteRegistro.fromMap(Map<String, dynamic> map) {
    final rawSitios = (map['sitios'] as Map?) ?? {};
    final sitios = <String, SitioPeriodontal>{};
    for (final clave in clavesSitios) {
      final valor = rawSitios[clave];
      sitios[clave] = valor != null
          ? SitioPeriodontal.fromMap(Map<String, dynamic>.from(valor))
          : SitioPeriodontal();
    }
    return DienteRegistro(
      numeroFdi: map['numeroFdi'] ?? '',
      ausente: map['ausente'] ?? false,
      movilidad: map['movilidad'] ?? 0,
      furca: map['furca'] ?? 0,
      sitios: sitios,
    );
  }
}

/// Numeración FDI de los 32 dientes permanentes, en el orden en que se
/// muestran habitualmente en un periodontograma (arcada superior e inferior).
const List<String> dientesArcadaSuperior = [
  '18', '17', '16', '15', '14', '13', '12', '11',
  '21', '22', '23', '24', '25', '26', '27', '28',
];

const List<String> dientesArcadaInferior = [
  '48', '47', '46', '45', '44', '43', '42', '41',
  '31', '32', '33', '34', '35', '36', '37', '38',
];

bool esMolar(String numeroFdi) {
  return numeroFdi.endsWith('6') ||
      numeroFdi.endsWith('7') ||
      numeroFdi.endsWith('8');
}

/// Un examen completo (una "foto" del estado periodontal en una fecha).
/// Un paciente puede tener varios, para comparar el inicio con el avance.
class Periodontograma {
  String id;
  DateTime fecha;
  String? notas;
  Map<String, DienteRegistro> dientes;

  Periodontograma({
    required this.id,
    required this.fecha,
    this.notas,
    Map<String, DienteRegistro>? dientes,
  }) : dientes = dientes ??
            {
              for (final n in [...dientesArcadaSuperior, ...dientesArcadaInferior])
                n: DienteRegistro(numeroFdi: n),
            };

  /// Resumen rápido para comparar el avance entre exámenes.
  int get totalDientesConBolsaSevera => dientes.values
      .where((d) => !d.ausente && d.profundidadMaxima >= 6)
      .length;

  int get totalDientesConBolsaModerada => dientes.values
      .where((d) =>
          !d.ausente && d.profundidadMaxima >= 4 && d.profundidadMaxima < 6)
      .length;

  double get porcentajeSangrado {
    final sitiosActivos = <SitioPeriodontal>[];
    for (final d in dientes.values) {
      if (!d.ausente) {
        sitiosActivos.addAll(d.sitios.values);
      }
    }
    if (sitiosActivos.isEmpty) {
      return 0;
    }
    final sangrantes = sitiosActivos.where((s) => s.sangrado).length;
    return (sangrantes / sitiosActivos.length) * 100;
  }

  double get porcentajePlaca {
    final sitiosActivos = <SitioPeriodontal>[];
    for (final d in dientes.values) {
      if (!d.ausente) {
        sitiosActivos.addAll(d.sitios.values);
      }
    }
    if (sitiosActivos.isEmpty) {
      return 0;
    }
    final conPlaca = sitiosActivos.where((s) => s.placa).length;
    return (conPlaca / sitiosActivos.length) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'notas': notas,
      'dientes': dientes.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory Periodontograma.fromMap(Map<String, dynamic> map) {
    final rawDientes = (map['dientes'] as Map?) ?? {};
    final dientes = <String, DienteRegistro>{};
    for (final n in [...dientesArcadaSuperior, ...dientesArcadaInferior]) {
      final valor = rawDientes[n];
      dientes[n] = valor != null
          ? DienteRegistro.fromMap(Map<String, dynamic>.from(valor))
          : DienteRegistro(numeroFdi: n);
    }
    return Periodontograma(
      id: map['id'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      notas: map['notas'],
      dientes: dientes,
    );
  }
}
