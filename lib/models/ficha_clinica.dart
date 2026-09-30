
// ---------------------------------------------------------------------------
// Utilidades internas de (de)serialización segura
// ---------------------------------------------------------------------------

T? _porNombre<T extends Enum>(List<T> valores, Object? nombre) {
  if (nombre == null) {
    return null;
  }
  for (final v in valores) {
    if (v.name == nombre) {
      return v;
    }
  }
  return null;
}

DateTime? _fechaDe(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString());

String _txt(Object? v) => v == null ? '' : v.toString();

List<Map<String, dynamic>> _listaMapas(Object? v) {
  if (v is! List) {
    return [];
  }
  return v
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

// ---------------------------------------------------------------------------
// Catálogos
// ---------------------------------------------------------------------------

enum Sexo { femenino, masculino, otro }

const Map<Sexo, String> etiquetaSexo = {
  Sexo.femenino: 'Femenino',
  Sexo.masculino: 'Masculino',
  Sexo.otro: 'Otro',
};

enum TipoAlergia { medicamento, anestesico, latex, alimento, otro }

const Map<TipoAlergia, String> etiquetaTipoAlergia = {
  TipoAlergia.medicamento: 'Medicamento',
  TipoAlergia.anestesico: 'Anestésico',
  TipoAlergia.latex: 'Látex / material',
  TipoAlergia.alimento: 'Alimento',
  TipoAlergia.otro: 'Otro',
};

enum SeveridadAlergia { leve, moderada, grave }

const Map<SeveridadAlergia, String> etiquetaSeveridad = {
  SeveridadAlergia.leve: 'Leve',
  SeveridadAlergia.moderada: 'Moderada',
  SeveridadAlergia.grave: 'Grave',
};

enum NivelHabito { ninguno, ocasional, frecuente }

const Map<NivelHabito, String> etiquetaNivelHabito = {
  NivelHabito.ninguno: 'No',
  NivelHabito.ocasional: 'Ocasional',
  NivelHabito.frecuente: 'Frecuente',
};

/// Condición médica que se marca en la historia. [alerta] = la condición
/// cambia la forma de atender (anestesia, sangrado, antibióticos...), así
/// que se destaca en rojo arriba de la ficha.
class CondicionMedica {
  final String clave;
  final String etiqueta;
  final bool alerta;
  const CondicionMedica(this.clave, this.etiqueta, this.alerta);
}

const List<CondicionMedica> catalogoCondiciones = [
  CondicionMedica('diabetes', 'Diabetes', true),
  CondicionMedica('hipertension', 'Hipertensión arterial', true),
  CondicionMedica('cardiopatia', 'Enfermedad cardíaca', true),
  CondicionMedica('marcapasos', 'Marcapasos / prótesis valvular', true),
  CondicionMedica('endocarditis', 'Fiebre reumática / endocarditis', true),
  CondicionMedica('anticoagulantes', 'Anticoagulantes / antiagregantes', true),
  CondicionMedica('coagulacion', 'Problemas de coagulación', true),
  CondicionMedica('hepatitis', 'Hepatitis / enfermedad hepática', true),
  CondicionMedica('renal', 'Enfermedad renal', true),
  CondicionMedica('inmunodeficiencia', 'Inmunodeficiencia', true),
  CondicionMedica('cancer', 'Cáncer / quimio o radioterapia', true),
  CondicionMedica('embarazo', 'Embarazo', true),
  CondicionMedica('epilepsia', 'Epilepsia / convulsiones', true),
  CondicionMedica('osteoporosis', 'Osteoporosis / bifosfonatos', true),
  CondicionMedica('tuberculosis', 'Tuberculosis', true),
  CondicionMedica('protesis_articular', 'Prótesis articular', true),
  CondicionMedica('lactancia', 'Lactancia', false),
  CondicionMedica('asma', 'Asma / problemas respiratorios', false),
  CondicionMedica('tiroides', 'Enfermedad de la tiroides', false),
  CondicionMedica('anemia', 'Anemia', false),
  CondicionMedica('gastritis', 'Gastritis / reflujo', false),
  CondicionMedica('psiquiatrica', 'Ansiedad / depresión', false),
];

String etiquetaCondicion(String clave) {
  for (final c in catalogoCondiciones) {
    if (c.clave == clave) {
      return c.etiqueta;
    }
  }
  return clave;
}

const List<String> gruposSanguineos = [
  'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-',
];

/// Anestésicos locales de uso común, solo como atajo para llenar el campo.
const List<String> atajosAnestesia = [
  'Lidocaína 2% con epinefrina',
  'Articaína 4% con epinefrina',
  'Mepivacaína 3%',
  'Anestesia tópica',
  'Sin anestesia',
];

/// Medicamentos frecuentes en odontología, solo como atajo de nombre y
/// presentación. La posología (dosis, frecuencia, duración) la decide y
/// escribe siempre la doctora.
class MedicamentoSugerido {
  final String nombre;
  final String presentacion;
  const MedicamentoSugerido(this.nombre, this.presentacion);
}

const List<MedicamentoSugerido> medicamentosSugeridos = [
  MedicamentoSugerido('Amoxicilina', '500 mg cápsulas'),
  MedicamentoSugerido('Amoxicilina + ácido clavulánico', '875/125 mg tabletas'),
  MedicamentoSugerido('Clindamicina', '300 mg cápsulas'),
  MedicamentoSugerido('Azitromicina', '500 mg tabletas'),
  MedicamentoSugerido('Metronidazol', '500 mg tabletas'),
  MedicamentoSugerido('Ibuprofeno', '400 mg tabletas'),
  MedicamentoSugerido('Paracetamol', '500 mg tabletas'),
  MedicamentoSugerido('Ketorolaco', '10 mg tabletas'),
  MedicamentoSugerido('Naproxeno', '550 mg tabletas'),
  MedicamentoSugerido('Dexametasona', '4 mg tabletas'),
  MedicamentoSugerido('Clorhexidina', '0.12% enjuague bucal'),
];

/// Familias de medicamentos para el aviso de posible alergia.
const Map<String, List<String>> _familiasMedicamentos = {
  'penicilina': [
    'penicilina', 'amoxicilina', 'ampicilina', 'clavulánico', 'clavulanico',
    'cloxacilina', 'dicloxacilina',
  ],
  'aine': [
    'ibuprofeno', 'ketorolaco', 'naproxeno', 'diclofenaco', 'aspirina',
    'ácido acetilsalicílico', 'acido acetilsalicilico', 'aine', 'antiinflamatorio',
    'meloxicam', 'piroxicam',
  ],
  'sulfa': ['sulfa', 'sulfametoxazol', 'trimetoprima', 'cotrimoxazol'],
  'macrolido': ['azitromicina', 'claritromicina', 'eritromicina', 'macrólido', 'macrolido'],
  'lincosamida': ['clindamicina', 'lincomicina'],
  'nitroimidazol': ['metronidazol', 'tinidazol', 'secnidazol'],
  'cefalosporina': ['cefalexina', 'cefadroxilo', 'ceftriaxona', 'cefalosporina'],
  'anestesico_amida': ['lidocaína', 'lidocaina', 'articaína', 'articaina', 'mepivacaína', 'mepivacaina', 'bupivacaína', 'bupivacaina'],
};

// ---------------------------------------------------------------------------
// Alergias y medicación
// ---------------------------------------------------------------------------

class Alergia {
  String id;
  TipoAlergia tipo;
  String descripcion;
  String reaccion;
  SeveridadAlergia severidad;

  Alergia({
    required this.id,
    this.tipo = TipoAlergia.medicamento,
    required this.descripcion,
    this.reaccion = '',
    this.severidad = SeveridadAlergia.moderada,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo.name,
        'descripcion': descripcion,
        'reaccion': reaccion,
        'severidad': severidad.name,
      };

  factory Alergia.fromMap(Map<String, dynamic> m) => Alergia(
        id: _txt(m['id']),
        tipo: _porNombre(TipoAlergia.values, m['tipo']) ?? TipoAlergia.otro,
        descripcion: _txt(m['descripcion']),
        reaccion: _txt(m['reaccion']),
        severidad: _porNombre(SeveridadAlergia.values, m['severidad']) ??
            SeveridadAlergia.moderada,
      );
}

class MedicamentoActual {
  String id;
  String nombre;
  String dosis;
  String motivo;

  MedicamentoActual({
    required this.id,
    required this.nombre,
    this.dosis = '',
    this.motivo = '',
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'nombre': nombre, 'dosis': dosis, 'motivo': motivo};

  factory MedicamentoActual.fromMap(Map<String, dynamic> m) => MedicamentoActual(
        id: _txt(m['id']),
        nombre: _txt(m['nombre']),
        dosis: _txt(m['dosis']),
        motivo: _txt(m['motivo']),
      );
}

// ---------------------------------------------------------------------------
// Evolución (nota por cita)
// ---------------------------------------------------------------------------

class Evolucion {
  String id;
  DateTime fecha;
  String procedimiento;
  String piezas;
  String anestesia;
  String presionArterial;
  String materiales;
  String observaciones;
  String indicaciones;
  DateTime? proximaCita;

  /// Ids de los tratamientos del presupuesto que se realizaron en esta cita.
  List<String> itemsRealizados;

  /// Copia del nombre de esos tratamientos (por si luego se eliminan del
  /// presupuesto, la nota clínica no debe perder información).
  List<String> descripcionItems;

  Evolucion({
    required this.id,
    required this.fecha,
    this.procedimiento = '',
    this.piezas = '',
    this.anestesia = '',
    this.presionArterial = '',
    this.materiales = '',
    this.observaciones = '',
    this.indicaciones = '',
    this.proximaCita,
    List<String>? itemsRealizados,
    List<String>? descripcionItems,
  })  : itemsRealizados = itemsRealizados ?? [],
        descripcionItems = descripcionItems ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'procedimiento': procedimiento,
        'piezas': piezas,
        'anestesia': anestesia,
        'presionArterial': presionArterial,
        'materiales': materiales,
        'observaciones': observaciones,
        'indicaciones': indicaciones,
        'proximaCita': proximaCita?.toIso8601String(),
        'itemsRealizados': itemsRealizados,
        'descripcionItems': descripcionItems,
      };

  factory Evolucion.fromMap(Map<String, dynamic> m) => Evolucion(
        id: _txt(m['id']),
        fecha: _fechaDe(m['fecha']) ?? DateTime.now(),
        procedimiento: _txt(m['procedimiento']),
        piezas: _txt(m['piezas']),
        anestesia: _txt(m['anestesia']),
        presionArterial: _txt(m['presionArterial']),
        materiales: _txt(m['materiales']),
        observaciones: _txt(m['observaciones']),
        indicaciones: _txt(m['indicaciones']),
        proximaCita: _fechaDe(m['proximaCita']),
        itemsRealizados:
            ((m['itemsRealizados'] as List?) ?? []).map((e) => e.toString()).toList(),
        descripcionItems:
            ((m['descripcionItems'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

// ---------------------------------------------------------------------------
// Recetas
// ---------------------------------------------------------------------------

class RecetaItem {
  String nombre;
  String presentacion;
  String posologia;
  String duracion;
  String cantidad;

  RecetaItem({
    this.nombre = '',
    this.presentacion = '',
    this.posologia = '',
    this.duracion = '',
    this.cantidad = '',
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'presentacion': presentacion,
        'posologia': posologia,
        'duracion': duracion,
        'cantidad': cantidad,
      };

  factory RecetaItem.fromMap(Map<String, dynamic> m) => RecetaItem(
        nombre: _txt(m['nombre']),
        presentacion: _txt(m['presentacion']),
        posologia: _txt(m['posologia']),
        duracion: _txt(m['duracion']),
        cantidad: _txt(m['cantidad']),
      );
}

class Receta {
  String id;
  int numero;
  DateTime fecha;
  String diagnostico;
  List<RecetaItem> items;
  String indicaciones;

  Receta({
    required this.id,
    required this.numero,
    required this.fecha,
    this.diagnostico = '',
    List<RecetaItem>? items,
    this.indicaciones = '',
  }) : items = items ?? [];

  String get numeroTexto => numero.toString().padLeft(4, '0');

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'fecha': fecha.toIso8601String(),
        'diagnostico': diagnostico,
        'items': items.map((i) => i.toMap()).toList(),
        'indicaciones': indicaciones,
      };

  factory Receta.fromMap(Map<String, dynamic> m) => Receta(
        id: _txt(m['id']),
        numero: (m['numero'] as num?)?.toInt() ?? 0,
        fecha: _fechaDe(m['fecha']) ?? DateTime.now(),
        diagnostico: _txt(m['diagnostico']),
        items: _listaMapas(m['items']).map(RecetaItem.fromMap).toList(),
        indicaciones: _txt(m['indicaciones']),
      );
}

// ---------------------------------------------------------------------------
// Consentimientos informados
// ---------------------------------------------------------------------------

class PlantillaConsentimiento {
  final String titulo;
  final String texto;
  const PlantillaConsentimiento(this.titulo, this.texto);
}

/// Textos base. {firmante}, {paciente}, {doctor} y {fecha} se reemplazan
/// al guardar el documento. La doctora puede editar el texto antes de firmar.
const List<PlantillaConsentimiento> plantillasConsentimiento = [
  PlantillaConsentimiento(
    'Tratamiento odontológico general',
    'Yo, {firmante}, declaro que el/la Odontólogo/a {doctor} me ha explicado, en un lenguaje claro, mi diagnóstico, el plan de tratamiento propuesto, sus alternativas, los beneficios esperados y los riesgos posibles.\n\n'
    'He informado con sinceridad mis antecedentes médicos, alergias y medicación actual, y me comprometo a avisar cualquier cambio en mi salud.\n\n'
    'Entiendo que en odontología no se puede garantizar un resultado exacto, que el éxito depende también de mis cuidados en casa y de asistir a los controles, y que pueden presentarse molestias o complicaciones propias de todo procedimiento.\n\n'
    'He podido hacer preguntas y fueron respondidas a mi satisfacción. Autorizo voluntariamente la realización del tratamiento y sé que puedo retirar este consentimiento en cualquier momento antes del procedimiento.',
  ),
  PlantillaConsentimiento(
    'Extracción dental',
    'Yo, {firmante}, autorizo al/la Odontólogo/a {doctor} a realizar la extracción de la(s) pieza(s) dental(es) indicada(s) en mi plan de tratamiento.\n\n'
    'He sido informado/a de las alternativas (mantener la pieza, tratamiento de conducto, reemplazo posterior) y de los riesgos posibles: dolor, inflamación, sangrado, hematomas, alveolitis (dolor tardío por alteración del coágulo), infección, apertura limitada de la boca temporal, lesión de dientes o tejidos vecinos, alteración temporal o, rara vez, permanente de la sensibilidad, y comunicación con el seno maxilar en piezas superiores.\n\n'
    'Me comprometo a seguir las indicaciones posteriores (reposo, dieta blanda, no fumar, no enjuagar con fuerza las primeras 24 horas, tomar la medicación indicada) y a acudir a control si aparece fiebre, sangrado persistente o dolor que aumenta.',
  ),
  PlantillaConsentimiento(
    'Endodoncia (tratamiento de conducto)',
    'Yo, {firmante}, autorizo al/la Odontólogo/a {doctor} a realizar el tratamiento de conducto en la pieza indicada.\n\n'
    'Se me explicó que el procedimiento consiste en retirar el tejido inflamado o infectado del interior del diente, limpiar y sellar los conductos, y que normalmente requiere una restauración definitiva posterior (por ejemplo una corona) para proteger el diente.\n\n'
    'Conozco los riesgos posibles: dolor o inflamación posoperatoria, fractura de instrumentos dentro del conducto, perforaciones, conductos calcificados o no localizables, fracaso del tratamiento con necesidad de repetirlo, cirugía o extracción, y fractura del diente tratado.\n\n'
    'Entiendo que el tratamiento puede requerir más de una sesión y que debo asistir a los controles indicados.',
  ),
  PlantillaConsentimiento(
    'Anestesia local',
    'Yo, {firmante}, autorizo la aplicación de anestesia local por parte del/la Odontólogo/a {doctor} para realizar mi tratamiento.\n\n'
    'He informado mis alergias, enfermedades y medicamentos que tomo. Se me explicó que pueden presentarse efectos como adormecimiento prolongado de labio, lengua o mejilla, mordedura accidental de la zona anestesiada, hematoma, dolor en el sitio de la inyección, mareo o desmayo, palpitaciones, y, rara vez, reacciones alérgicas o daño temporal o permanente de un nervio.\n\n'
    'Me comprometo a no comer ni masticar hasta que pase el efecto de la anestesia.',
  ),
  PlantillaConsentimiento(
    'Blanqueamiento dental',
    'Yo, {firmante}, autorizo al/la Odontólogo/a {doctor} a realizar el blanqueamiento dental.\n\n'
    'Se me explicó que el resultado varía según cada persona y el tipo de manchas, que las restauraciones (resinas, coronas, carillas) no cambian de color, y que puede aparecer sensibilidad dental o irritación de las encías, normalmente pasajera.\n\n'
    'Entiendo que el color puede recaer con el tiempo, con el consumo de café, té, vino, tabaco u otros alimentos pigmentantes, y me comprometo a seguir las indicaciones de cuidado posteriores.',
  ),
  PlantillaConsentimiento(
    'Implante dental',
    'Yo, {firmante}, autorizo al/la Odontólogo/a {doctor} a realizar el tratamiento con implante dental.\n\n'
    'Se me explicaron las etapas del tratamiento, los tiempos de cicatrización, las alternativas y los riesgos posibles: dolor, inflamación, sangrado, infección, falta de integración del implante con el hueso, lesión de nervios o de estructuras vecinas, comunicación con el seno maxilar, y necesidad eventual de injertos óseos o de retirar el implante.\n\n'
    'Entiendo que el éxito depende de mi higiene, de no fumar, del control de enfermedades como la diabetes y de asistir a los controles periódicos durante toda la vida del implante.',
  ),
  PlantillaConsentimiento(
    'Tratamiento en menor de edad (representante)',
    'Yo, {firmante}, en calidad de representante legal de {paciente}, declaro que el/la Odontólogo/a {doctor} me explicó el diagnóstico, el tratamiento propuesto, sus alternativas, beneficios y riesgos, y que pude hacer todas las preguntas necesarias.\n\n'
    'He informado los antecedentes médicos, alergias y medicación de {paciente}. Autorizo de forma voluntaria la realización del tratamiento y me comprometo a colaborar con los cuidados en casa y los controles posteriores.',
  ),
  PlantillaConsentimiento('Documento en blanco (escribir texto propio)', ''),
];

/// Firma dibujada con el dedo. Se guarda como una lista de trazos; cada
/// trazo es un texto "x,y;x,y;..." (así se evita el problema de las listas
/// anidadas, que la base de datos no admite).
class Consentimiento {
  String id;
  DateTime fecha;
  String titulo;
  String texto;
  String nombreFirmante;
  String cedulaFirmante;
  bool esRepresentante;
  String parentesco;
  List<String> firmaTrazos;
  double firmaAncho;
  double firmaAlto;
  DateTime? firmadoEn;

  Consentimiento({
    required this.id,
    required this.fecha,
    required this.titulo,
    required this.texto,
    this.nombreFirmante = '',
    this.cedulaFirmante = '',
    this.esRepresentante = false,
    this.parentesco = '',
    List<String>? firmaTrazos,
    this.firmaAncho = 0,
    this.firmaAlto = 0,
    this.firmadoEn,
  }) : firmaTrazos = firmaTrazos ?? [];

  bool get firmado => firmaTrazos.isNotEmpty && firmadoEn != null;

  /// Trazos decodificados: cada trazo es una lista de puntos [x, y].
  List<List<List<double>>> get trazos {
    final resultado = <List<List<double>>>[];
    for (final t in firmaTrazos) {
      final puntos = <List<double>>[];
      for (final par in t.split(';')) {
        final xy = par.split(',');
        if (xy.length != 2) {
          continue;
        }
        final x = double.tryParse(xy[0]);
        final y = double.tryParse(xy[1]);
        if (x != null && y != null) {
          puntos.add([x, y]);
        }
      }
      if (puntos.isNotEmpty) {
        resultado.add(puntos);
      }
    }
    return resultado;
  }

  static String codificarTrazo(List<List<double>> puntos) => puntos
      .map((p) => '${redondear1(p[0])},${redondear1(p[1])}')
      .join(';');

  static double redondear1(double v) => (v * 10).round() / 10;

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'titulo': titulo,
        'texto': texto,
        'nombreFirmante': nombreFirmante,
        'cedulaFirmante': cedulaFirmante,
        'esRepresentante': esRepresentante,
        'parentesco': parentesco,
        'firmaTrazos': firmaTrazos,
        'firmaAncho': firmaAncho,
        'firmaAlto': firmaAlto,
        'firmadoEn': firmadoEn?.toIso8601String(),
      };

  factory Consentimiento.fromMap(Map<String, dynamic> m) => Consentimiento(
        id: _txt(m['id']),
        fecha: _fechaDe(m['fecha']) ?? DateTime.now(),
        titulo: _txt(m['titulo']),
        texto: _txt(m['texto']),
        nombreFirmante: _txt(m['nombreFirmante']),
        cedulaFirmante: _txt(m['cedulaFirmante']),
        esRepresentante: m['esRepresentante'] ?? false,
        parentesco: _txt(m['parentesco']),
        firmaTrazos:
            ((m['firmaTrazos'] as List?) ?? []).map((e) => e.toString()).toList(),
        firmaAncho: (m['firmaAncho'] as num?)?.toDouble() ?? 0,
        firmaAlto: (m['firmaAlto'] as num?)?.toDouble() ?? 0,
        firmadoEn: _fechaDe(m['firmadoEn']),
      );
}

// ---------------------------------------------------------------------------
// Ficha clínica completa
// ---------------------------------------------------------------------------

class FichaClinica {
  // Datos personales
  DateTime? fechaNacimiento;
  Sexo? sexo;
  String ocupacion;
  String direccion;
  String correo;
  String referidoPor;
  String contactoNombre;
  String contactoParentesco;
  String contactoTelefono;
  String motivoConsulta;
  String enfermedadActual;

  // Historia médica
  String grupoSanguineo;
  Set<String> condiciones;
  String condicionesOtras;
  List<Alergia> alergias;
  List<MedicamentoActual> medicamentos;
  String cirugias;
  String antecedentesFamiliares;
  String observacionesMedicas;

  /// Última vez que la doctora confirmó que la historia sigue vigente.
  DateTime? historiaActualizada;

  // Hábitos e higiene
  NivelHabito tabaco;
  NivelHabito alcohol;
  int cepilladosDia; // 0 = sin dato
  bool usaHilo;
  bool usaEnjuague;
  bool bruxismo;

  // Antecedentes odontológicos
  String ultimaVisita;
  bool sangradoEncias;
  bool sensibilidad;
  bool ortodonciaPrevia;
  int ansiedadDental; // 0 = sin dato, 1 (nada) a 5 (mucha)
  String experienciasPrevias;

  // Registros clínicos
  List<Evolucion> evoluciones;
  List<Receta> recetas;
  List<Consentimiento> consentimientos;

  FichaClinica({
    this.fechaNacimiento,
    this.sexo,
    this.ocupacion = '',
    this.direccion = '',
    this.correo = '',
    this.referidoPor = '',
    this.contactoNombre = '',
    this.contactoParentesco = '',
    this.contactoTelefono = '',
    this.motivoConsulta = '',
    this.enfermedadActual = '',
    this.grupoSanguineo = '',
    Set<String>? condiciones,
    this.condicionesOtras = '',
    List<Alergia>? alergias,
    List<MedicamentoActual>? medicamentos,
    this.cirugias = '',
    this.antecedentesFamiliares = '',
    this.observacionesMedicas = '',
    this.historiaActualizada,
    this.tabaco = NivelHabito.ninguno,
    this.alcohol = NivelHabito.ninguno,
    this.cepilladosDia = 0,
    this.usaHilo = false,
    this.usaEnjuague = false,
    this.bruxismo = false,
    this.ultimaVisita = '',
    this.sangradoEncias = false,
    this.sensibilidad = false,
    this.ortodonciaPrevia = false,
    this.ansiedadDental = 0,
    this.experienciasPrevias = '',
    List<Evolucion>? evoluciones,
    List<Receta>? recetas,
    List<Consentimiento>? consentimientos,
  })  : condiciones = condiciones ?? <String>{},
        alergias = alergias ?? [],
        medicamentos = medicamentos ?? [],
        evoluciones = evoluciones ?? [],
        recetas = recetas ?? [],
        consentimientos = consentimientos ?? [];

  // ---------- Derivados ----------

  /// Edad en años cumplidos, o null si no hay fecha de nacimiento.
  int? get edad {
    final n = fechaNacimiento;
    if (n == null) {
      return null;
    }
    final hoy = DateTime.now();
    var e = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) {
      e--;
    }
    return e < 0 ? null : e;
  }

  bool get esMenor => (edad ?? 99) < 18;

  bool get tieneHistoriaMedica =>
      condiciones.isNotEmpty ||
      condicionesOtras.trim().isNotEmpty ||
      alergias.isNotEmpty ||
      medicamentos.isNotEmpty ||
      cirugias.trim().isNotEmpty ||
      antecedentesFamiliares.trim().isNotEmpty ||
      observacionesMedicas.trim().isNotEmpty;

  /// Días desde la última confirmación de la historia (null si nunca).
  int? get diasDesdeConfirmacion => historiaActualizada == null
      ? null
      : DateTime.now().difference(historiaActualizada!).inDays;

  /// La historia médica debería revisarse con el paciente (más de 6 meses
  /// sin confirmar).
  bool get historiaPorRevisar {
    final d = diasDesdeConfirmacion;
    return d == null || d > 180;
  }

  /// Condiciones marcadas que cambian la atención.
  List<String> get condicionesDeAlerta => [
        for (final c in catalogoCondiciones)
          if (c.alerta && condiciones.contains(c.clave)) c.etiqueta,
      ];

  List<Alergia> get alergiasOrdenadas {
    final lista = List<Alergia>.from(alergias);
    lista.sort((a, b) => b.severidad.index.compareTo(a.severidad.index));
    return lista;
  }

  bool get tieneAlertas =>
      alergias.isNotEmpty ||
      condicionesDeAlerta.isNotEmpty ||
      condicionesOtras.trim().isNotEmpty;

  int get siguienteNumeroReceta {
    var maximo = 0;
    for (final r in recetas) {
      if (r.numero > maximo) {
        maximo = r.numero;
      }
    }
    return maximo + 1;
  }

  List<Evolucion> get evolucionesOrdenadas {
    final lista = List<Evolucion>.from(evoluciones);
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Próximas citas ya agendadas en las evoluciones (de hoy en adelante).
  List<DateTime> get proximasCitas {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final lista = <DateTime>[
      for (final e in evoluciones)
        if (e.proximaCita != null && !e.proximaCita!.isBefore(inicioHoy))
          e.proximaCita!,
    ]..sort();
    return lista;
  }

  /// Si [medicamento] pertenece a la misma familia (o es el mismo) que una
  /// alergia registrada, devuelve esa alergia para avisar antes de recetar.
  Alergia? alergiaConflictiva(String medicamento) {
    final med = medicamento.trim().toLowerCase();
    if (med.isEmpty) {
      return null;
    }
    for (final a in alergias) {
      final desc = a.descripcion.trim().toLowerCase();
      if (desc.isEmpty) {
        continue;
      }
      if (med.contains(desc) || desc.contains(med)) {
        return a;
      }
      for (final familia in _familiasMedicamentos.values) {
        final alergiaEnFamilia = familia.any((m) => desc.contains(m));
        final medEnFamilia = familia.any((m) => med.contains(m));
        if (alergiaEnFamilia && medEnFamilia) {
          return a;
        }
      }
    }
    return null;
  }

  // ---------- Serialización ----------

  Map<String, dynamic> toMap() => {
        'fechaNacimiento': fechaNacimiento?.toIso8601String(),
        'sexo': sexo?.name,
        'ocupacion': ocupacion,
        'direccion': direccion,
        'correo': correo,
        'referidoPor': referidoPor,
        'contactoNombre': contactoNombre,
        'contactoParentesco': contactoParentesco,
        'contactoTelefono': contactoTelefono,
        'motivoConsulta': motivoConsulta,
        'enfermedadActual': enfermedadActual,
        'grupoSanguineo': grupoSanguineo,
        'condiciones': condiciones.toList(),
        'condicionesOtras': condicionesOtras,
        'alergias': alergias.map((a) => a.toMap()).toList(),
        'medicamentos': medicamentos.map((m) => m.toMap()).toList(),
        'cirugias': cirugias,
        'antecedentesFamiliares': antecedentesFamiliares,
        'observacionesMedicas': observacionesMedicas,
        'historiaActualizada': historiaActualizada?.toIso8601String(),
        'tabaco': tabaco.name,
        'alcohol': alcohol.name,
        'cepilladosDia': cepilladosDia,
        'usaHilo': usaHilo,
        'usaEnjuague': usaEnjuague,
        'bruxismo': bruxismo,
        'ultimaVisita': ultimaVisita,
        'sangradoEncias': sangradoEncias,
        'sensibilidad': sensibilidad,
        'ortodonciaPrevia': ortodonciaPrevia,
        'ansiedadDental': ansiedadDental,
        'experienciasPrevias': experienciasPrevias,
        'evoluciones': evoluciones.map((e) => e.toMap()).toList(),
        'recetas': recetas.map((r) => r.toMap()).toList(),
        'consentimientos': consentimientos.map((c) => c.toMap()).toList(),
      };

  factory FichaClinica.fromMap(Map<String, dynamic> m) => FichaClinica(
        fechaNacimiento: _fechaDe(m['fechaNacimiento']),
        sexo: _porNombre(Sexo.values, m['sexo']),
        ocupacion: _txt(m['ocupacion']),
        direccion: _txt(m['direccion']),
        correo: _txt(m['correo']),
        referidoPor: _txt(m['referidoPor']),
        contactoNombre: _txt(m['contactoNombre']),
        contactoParentesco: _txt(m['contactoParentesco']),
        contactoTelefono: _txt(m['contactoTelefono']),
        motivoConsulta: _txt(m['motivoConsulta']),
        enfermedadActual: _txt(m['enfermedadActual']),
        grupoSanguineo: _txt(m['grupoSanguineo']),
        condiciones:
            ((m['condiciones'] as List?) ?? []).map((e) => e.toString()).toSet(),
        condicionesOtras: _txt(m['condicionesOtras']),
        alergias: _listaMapas(m['alergias']).map(Alergia.fromMap).toList(),
        medicamentos:
            _listaMapas(m['medicamentos']).map(MedicamentoActual.fromMap).toList(),
        cirugias: _txt(m['cirugias']),
        antecedentesFamiliares: _txt(m['antecedentesFamiliares']),
        observacionesMedicas: _txt(m['observacionesMedicas']),
        historiaActualizada: _fechaDe(m['historiaActualizada']),
        tabaco: _porNombre(NivelHabito.values, m['tabaco']) ?? NivelHabito.ninguno,
        alcohol: _porNombre(NivelHabito.values, m['alcohol']) ?? NivelHabito.ninguno,
        cepilladosDia: (m['cepilladosDia'] as num?)?.toInt() ?? 0,
        usaHilo: m['usaHilo'] ?? false,
        usaEnjuague: m['usaEnjuague'] ?? false,
        bruxismo: m['bruxismo'] ?? false,
        ultimaVisita: _txt(m['ultimaVisita']),
        sangradoEncias: m['sangradoEncias'] ?? false,
        sensibilidad: m['sensibilidad'] ?? false,
        ortodonciaPrevia: m['ortodonciaPrevia'] ?? false,
        ansiedadDental: (m['ansiedadDental'] as num?)?.toInt() ?? 0,
        experienciasPrevias: _txt(m['experienciasPrevias']),
        evoluciones: _listaMapas(m['evoluciones']).map(Evolucion.fromMap).toList(),
        recetas: _listaMapas(m['recetas']).map(Receta.fromMap).toList(),
        consentimientos:
            _listaMapas(m['consentimientos']).map(Consentimiento.fromMap).toList(),
      );
}
