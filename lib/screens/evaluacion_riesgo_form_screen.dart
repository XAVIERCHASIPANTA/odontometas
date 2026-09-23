import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/evaluacion_riesgo.dart';
import '../theme/app_theme.dart';

class EvaluacionRiesgoFormScreen extends StatefulWidget {
  final EvaluacionRiesgo evaluacion;
  final String nombrePaciente;
  const EvaluacionRiesgoFormScreen({
    super.key,
    required this.evaluacion,
    required this.nombrePaciente,
  });

  @override
  State<EvaluacionRiesgoFormScreen> createState() =>
      _EvaluacionRiesgoFormScreenState();
}

class _EvaluacionRiesgoFormScreenState
    extends State<EvaluacionRiesgoFormScreen> {
  late EvaluacionRiesgo e;

  @override
  void initState() {
    super.initState();
    e = widget.evaluacion;
  }

  Color get _colorRiesgo {
    switch (e.riesgoGlobal) {
      case RiesgoPeriodontal.bajo:
        return Colors.green.shade600;
      case RiesgoPeriodontal.moderado:
        return Colors.orange.shade700;
      case RiesgoPeriodontal.alto:
        return Colors.red.shade700;
    }
  }

  Widget _tarjeta({required String titulo, required List<Widget> hijos}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _campoEntero({
    required String etiqueta,
    required int valor,
    required ValueChanged<int> onCambio,
    int min = 0,
    int max = 999,
    String? sufijo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              if (valor > min) {
                setState(() => onCambio(valor - 1));
              }
            },
          ),
          SizedBox(
            width: 40,
            child: Text('$valor', textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              if (valor < max) {
                setState(() => onCambio(valor + 1));
              }
            },
          ),
          if (sufijo != null) Text(sufijo, style: const TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Evaluación del Riesgo (PRA)',
        colores: const [AppTheme.lavanda, AppTheme.rosaOscuro],
        acciones: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Guardar',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              widget.nombrePaciente,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(e.fecha),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Examen inicial'),
                  selected: !e.esReevaluacion,
                  onSelected: (_) => setState(() => e.esReevaluacion = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Reevaluación'),
                  selected: e.esReevaluacion,
                  onSelected: (_) => setState(() => e.esReevaluacion = true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _tarjeta(titulo: 'Datos del paciente', hijos: [
              _campoEntero(
                etiqueta: 'Edad',
                valor: e.edad,
                onCambio: (v) => e.edad = v,
                max: 120,
              ),
              _campoEntero(
                etiqueta: 'Número de dientes e implantes',
                valor: e.dientesEImplantes,
                onCambio: (v) => e.dientesEImplantes = v,
                min: 1,
                max: 32,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Número de sitios por diente/implante'),
              ),
              Wrap(
                spacing: 8,
                children: [2, 4, 6].map((n) {
                  return ChoiceChip(
                    label: Text('$n'),
                    selected: e.sitiosPorDiente == n,
                    onSelected: (_) => setState(() => e.sitiosPorDiente = n),
                  );
                }).toList(),
              ),
            ]),
            const SizedBox(height: 12),
            _tarjeta(titulo: 'Parámetros clínicos', hijos: [
              _campoEntero(
                etiqueta: 'Sitios BOP-positivos',
                valor: e.sitiosBopPositivos,
                onCambio: (v) => e.sitiosBopPositivos = v,
                max: e.totalSitios,
                sufijo: '/ ${e.totalSitios}',
              ),
              _campoEntero(
                etiqueta: 'Sitios con PPD ≥5mm',
                valor: e.sitiosConBolsaProfunda,
                onCambio: (v) => e.sitiosConBolsaProfunda = v,
                max: e.totalSitios,
              ),
              _campoEntero(
                etiqueta: 'Dientes perdidos',
                valor: e.dientesPerdidos,
                onCambio: (v) => e.dientesPerdidos = v,
                max: 28,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(child: Text('% pérdida de hueso alveolar')),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (e.porcentajePerdidaOsea > 0) {
                          setState(() => e.porcentajePerdidaOsea -= 10);
                        }
                      },
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('${e.porcentajePerdidaOsea}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (e.porcentajePerdidaOsea < 100) {
                          setState(() => e.porcentajePerdidaOsea += 10);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _tarjeta(titulo: 'Factores sistémicos y ambientales', hijos: [
              const Text('Factores sistémicos (diabetes, etc.)'),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Sí'),
                    selected: e.factorSistemico,
                    onSelected: (_) => setState(() => e.factorSistemico = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('No'),
                    selected: !e.factorSistemico,
                    onSelected: (_) => setState(() => e.factorSistemico = false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Tabaquismo'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: NivelTabaquismo.values.map((t) {
                  return ChoiceChip(
                    label: Text(t.etiqueta),
                    selected: e.tabaquismo == t,
                    onSelected: (_) => setState(() => e.tabaquismo = t),
                  );
                }).toList(),
              ),
            ]),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _HexagonoPainter(evaluacion: e),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Riesgo periodontal: ${e.riesgoGlobal.etiqueta.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorRiesgo,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recomendación: ${e.recomendacion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Intervalo de mantenimiento sugerido: ${e.intervaloSugerido}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Basado en el modelo de Lang & Tonetti (2003), publicado en '
                'perio-tools.com/risk-assessment (CC BY-NC-SA 4.0). Es una '
                'guía de apoyo clínico, no reemplaza el criterio profesional.',
                style: TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// Dibuja el diagrama hexagonal de riesgo con los 6 ejes de Lang & Tonetti,
/// con anillos de referencia (bajo/moderado/alto) y el polígono real del
/// paciente.
class _HexagonoPainter extends CustomPainter {
  final EvaluacionRiesgo evaluacion;
  _HexagonoPainter({required this.evaluacion});

  static const List<String> etiquetas = [
    'BOP%',
    'PD≥5mm',
    'Dientes\nperdidos',
    'BL/Edad',
    'Sist./Gen.',
    'Amb.',
  ];

  double _nivelContinuo(int indice) {
    switch (indice) {
      case 0:
        return (evaluacion.porcentajeBop / 50).clamp(0, 1);
      case 1:
        return (evaluacion.sitiosConBolsaProfunda / 12).clamp(0, 1);
      case 2:
        return (evaluacion.dientesPerdidos / 12).clamp(0, 1);
      case 3:
        return (evaluacion.relacionPerdidaOseaEdad / 1.5).clamp(0, 1);
      case 4:
        return evaluacion.factorSistemico ? 1.0 : 0.0;
      case 5:
        switch (evaluacion.tabaquismo) {
          case NivelTabaquismo.noFumador:
            return 0.0;
          case NivelTabaquismo.exFumador:
            return 0.12;
          case NivelTabaquismo.ocasional:
            return 0.45;
          case NivelTabaquismo.fumador:
            return 0.62;
          case NivelTabaquismo.granFumador:
            return 1.0;
        }
      default:
        return 0.0;
    }
  }

  Offset _puntoEnEje(Offset centro, double radio, int indice, double fraccion) {
    final angulo = (-math.pi / 2) + (indice * (2 * math.pi / 6));
    return Offset(
      centro.dx + radio * fraccion * math.cos(angulo),
      centro.dy + radio * fraccion * math.sin(angulo),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2 - 6);
    final radioMax = math.min(size.width, size.height) / 2 - 34;

    final paintAnilloBajo = Paint()
      ..color = Colors.green.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final paintAnilloModerado = Paint()
      ..color = Colors.orange.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final paintAnilloAlto = Paint()
      ..color = Colors.red.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final paintLineaAnillo = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final paintEje = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    Path hexagonoEn(double fraccion) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final p = _puntoEnEje(centro, radioMax, i, fraccion);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      return path;
    }

    // anillos de fondo: bajo (0-0.33), moderado (0.33-0.67), alto (0.67-1.0)
    canvas.drawPath(hexagonoEn(1.0), paintAnilloAlto);
    canvas.drawPath(hexagonoEn(0.667), paintAnilloModerado);
    canvas.drawPath(hexagonoEn(0.333), paintAnilloBajo);
    canvas.drawPath(hexagonoEn(1.0), paintLineaAnillo);
    canvas.drawPath(hexagonoEn(0.667), paintLineaAnillo);
    canvas.drawPath(hexagonoEn(0.333), paintLineaAnillo);

    // ejes
    for (int i = 0; i < 6; i++) {
      final p = _puntoEnEje(centro, radioMax, i, 1.0);
      canvas.drawLine(centro, p, paintEje);
    }

    // polígono real del paciente
    final pathReal = Path();
    for (int i = 0; i < 6; i++) {
      final f = _nivelContinuo(i);
      final p = _puntoEnEje(centro, radioMax, i, f);
      if (i == 0) {
        pathReal.moveTo(p.dx, p.dy);
      } else {
        pathReal.lineTo(p.dx, p.dy);
      }
    }
    pathReal.close();
    final paintRelleno = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final paintBorde = Paint()
      ..color = Colors.deepPurple.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(pathReal, paintRelleno);
    canvas.drawPath(pathReal, paintBorde);
    for (int i = 0; i < 6; i++) {
      final f = _nivelContinuo(i);
      final p = _puntoEnEje(centro, radioMax, i, f);
      canvas.drawCircle(p, 3, Paint()..color = Colors.deepPurple.shade700);
    }

    // etiquetas
    for (int i = 0; i < 6; i++) {
      final p = _puntoEnEje(centro, radioMax + 20, i, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: etiquetas[i],
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 60);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonoPainter oldDelegate) => true;
}
