import 'tratamiento.dart';
import 'periodontograma.dart';
import 'campo_adicional.dart';
import 'evaluacion_riesgo.dart';
import 'odontograma.dart';
import 'presupuesto.dart';
import 'ficha_clinica.dart';

class Paciente {
  String nombre;
  String cedula;
  String celular;
  DateTime? fecha;
  bool completado;
  String? fotoPerfil;
  List<Tratamiento> tratamientos;
  List<String> adjuntos;
  List<Periodontograma> periodontogramas;
  List<CampoAdicional> camposAdicionales;
  List<EvaluacionRiesgo> evaluacionesRiesgo;
  List<Odontograma> odontogramas;
  Presupuesto? presupuesto;
  FichaClinica? ficha;

  Paciente({
    this.nombre = '',
    this.cedula = '',
    this.celular = '',
    this.fecha,
    this.completado = false,
    this.fotoPerfil,
    List<Tratamiento>? tratamientos,
    List<String>? adjuntos,
    List<Periodontograma>? periodontogramas,
    List<CampoAdicional>? camposAdicionales,
    List<EvaluacionRiesgo>? evaluacionesRiesgo,
    List<Odontograma>? odontogramas,
    this.presupuesto,
    this.ficha,
  })  : tratamientos = tratamientos ?? [],
        adjuntos = adjuntos ?? [],
        periodontogramas = periodontogramas ?? [],
        camposAdicionales = camposAdicionales ?? [],
        evaluacionesRiesgo = evaluacionesRiesgo ?? [],
        odontogramas = odontogramas ?? [];

  bool get tieneInfo => nombre.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'cedula': cedula,
      'celular': celular,
      'fecha': fecha?.toIso8601String(),
      'completado': completado,
      'fotoPerfil': fotoPerfil,
      'tratamientos': tratamientos.map((t) => t.toMap()).toList(),
      'adjuntos': adjuntos,
      'periodontogramas': periodontogramas.map((p) => p.toMap()).toList(),
      'camposAdicionales': camposAdicionales.map((c) => c.toMap()).toList(),
      'evaluacionesRiesgo': evaluacionesRiesgo.map((r) => r.toMap()).toList(),
      'odontogramas': odontogramas.map((o) => o.toMap()).toList(),
      'presupuesto': presupuesto?.toMap(),
      'ficha': ficha?.toMap(),
    };
  }

  factory Paciente.fromMap(Map<String, dynamic> map) {
    final rawTratamientos = (map['tratamientos'] as List?) ?? [];
    final rawAdjuntos = (map['adjuntos'] as List?) ?? [];
    final rawPeriodontogramas = (map['periodontogramas'] as List?) ?? [];
    final rawCampos = (map['camposAdicionales'] as List?) ?? [];
    final rawEvaluaciones = (map['evaluacionesRiesgo'] as List?) ?? [];
    final rawOdontogramas = (map['odontogramas'] as List?) ?? [];
    return Paciente(
      nombre: map['nombre'] ?? '',
      cedula: map['cedula'] ?? '',
      celular: map['celular'] ?? '',
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha']) : null,
      completado: map['completado'] ?? false,
      fotoPerfil: map['fotoPerfil'],
      tratamientos: rawTratamientos
          .map((t) => Tratamiento.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
      adjuntos: rawAdjuntos.map((a) => a.toString()).toList(),
      periodontogramas: rawPeriodontogramas
          .map((p) =>
              Periodontograma.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
      camposAdicionales: rawCampos
          .map((c) =>
              CampoAdicional.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      evaluacionesRiesgo: rawEvaluaciones
          .map((r) =>
              EvaluacionRiesgo.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
      odontogramas: rawOdontogramas
          .map((o) => Odontograma.fromMap(Map<String, dynamic>.from(o as Map)))
          .toList(),
      presupuesto: map['presupuesto'] != null
          ? Presupuesto.fromMap(Map<String, dynamic>.from(map['presupuesto']))
          : null,
      ficha: map['ficha'] != null
          ? FichaClinica.fromMap(Map<String, dynamic>.from(map['ficha']))
          : null,
    );
  }
}
