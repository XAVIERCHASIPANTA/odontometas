import 'package:flutter/material.dart';

class ParColor {
  final Color fuerte;
  final Color claro;
  const ParColor(this.fuerte, this.claro);
}

const List<ParColor> paletaColores = [
  ParColor(Color(0xFFEC407A), Color(0xFFFFE4EC)), // rosa
  ParColor(Color(0xFF7E57C2), Color(0xFFEDE7F6)), // lavanda
  ParColor(Color(0xFF29B6F6), Color(0xFFE1F5FE)), // celeste
  ParColor(Color(0xFF26A69A), Color(0xFFE0F2F1)), // menta
  ParColor(Color(0xFFFFA726), Color(0xFFFFF3E0)), // durazno
  ParColor(Color(0xFFEF5350), Color(0xFFFFEBEE)), // coral
];

/// Tono menta llamativo para el fondo de la pantalla de cada meta, en vez
/// de desvanecer a blanco puro en el centro del degradado.
const Color fondoMetaMenta = Color(0xFFA8E6CF);

ParColor colorParaMeta(String id) {
  final indice = id.hashCode.abs() % paletaColores.length;
  return paletaColores[indice];
}

/// Genera un tono derivado del color de la meta, distinto para cada número
/// de paciente (1, 2, 3...) — fuerte y llamativo, para poder distinguirlos
/// de un vistazo incluso en toda la tarjeta.
Color tonoPacientePorIndice(Color base, int indice) {
  final hsl = HSLColor.fromColor(base);
  const rotacionesDeMatiz = [
    0.0, 40.0, -40.0, 70.0, -70.0, 100.0, -100.0, 140.0,
  ];
  final matiz =
      (hsl.hue + rotacionesDeMatiz[indice % rotacionesDeMatiz.length]) % 360;
  final matizPositivo = matiz < 0 ? matiz + 360 : matiz;
  return HSLColor.fromAHSL(1.0, matizPositivo, 0.62, 0.52).toColor();
}

/// Versión más oscura del mismo tono (misma rotación de matiz), por si se
/// necesita un color de texto/ícono legible sobre un fondo claro.
Color tonoPacienteTextoPorIndice(Color base, int indice) {
  final hsl = HSLColor.fromColor(base);
  const rotacionesDeMatiz = [
    0.0, 40.0, -40.0, 70.0, -70.0, 100.0, -100.0, 140.0,
  ];
  final matiz =
      (hsl.hue + rotacionesDeMatiz[indice % rotacionesDeMatiz.length]) % 360;
  final matizPositivo = matiz < 0 ? matiz + 360 : matiz;
  return HSLColor.fromAHSL(1.0, matizPositivo, 0.70, 0.32).toColor();
}

IconData iconoParaProcedimiento(String titulo) {
  final t = titulo.toLowerCase();
  if (t.contains('extrac')) {
    return Icons.content_cut;
  }
  if (t.contains('endodon') || t.contains('conducto')) {
    return Icons.healing;
  }
  if (t.contains('calza') || t.contains('resina') || t.contains('obtur')) {
    return Icons.build_circle_outlined;
  }
  if (t.contains('periodon') || t.contains('encia')) {
    return Icons.spa_outlined;
  }
  if (t.contains('limpieza') || t.contains('profilax')) {
    return Icons.auto_awesome_outlined;
  }
  if (t.contains('blanque')) {
    return Icons.brightness_high_outlined;
  }
  if (t.contains('ortodon') || t.contains('bracket')) {
    return Icons.grid_on;
  }
  if (t.contains('protesis') || t.contains('prótesis') || t.contains('corona')) {
    return Icons.emoji_events_outlined;
  }
  return Icons.medical_services_outlined;
}
