import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/periodontograma.dart';
import '../theme/app_theme.dart';
import '../widgets/marca_agua_muela_k.dart';
import '../widgets/dientes_realistas.dart';

class PeriodontogramaFormScreen extends StatefulWidget {
  final Periodontograma examen;
  final String nombrePaciente;
  const PeriodontogramaFormScreen({
    super.key,
    required this.examen,
    required this.nombrePaciente,
  });

  @override
  State<PeriodontogramaFormScreen> createState() =>
      _PeriodontogramaFormScreenState();
}

class _PeriodontogramaFormScreenState
    extends State<PeriodontogramaFormScreen> {
  late final TextEditingController _notasCtrl;

  static const double _anchoColumna = 15.0;
  static const double _alturaGrafico = 110.0;
  static const double _escalaPxPorMm = 8.0;
  static const List<String> _sitiosVestibular = [
    'vest_mesial',
    'vest_central',
    'vest_distal',
  ];
  static const List<String> _sitiosPalatino = [
    'palat_mesial',
    'palat_central',
    'palat_distal',
  ];

  @override
  void initState() {
    super.initState();
    _notasCtrl = TextEditingController(text: widget.examen.notas ?? '');
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Color _colorParaProfundidad(int pd, bool ausente) {
    if (ausente) {
      return Colors.grey.shade300;
    }
    if (pd >= 6) {
      return Colors.red.shade400;
    }
    if (pd >= 4) {
      return Colors.orange.shade400;
    }
    return Colors.green.shade400;
  }

  Widget _iconoDiente(String numeroFdi, {required bool esSuperior}) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final color = _colorParaProfundidad(diente.profundidadMaxima, diente.ausente);
    final tipo = tipoDientePorFdi(numeroFdi);
    final icono = Transform.rotate(
      angle: esSuperior ? 0 : math.pi,
      child: DienteRealistaVector(tipo: tipo, size: 34, colorRelleno: color),
    );
    return GestureDetector(
      onTap: () => _editarDiente(numeroFdi),
      child: SizedBox(
        width: _anchoColumna * 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            diente.ausente
                ? const Icon(Icons.close, size: 28, color: Colors.black38)
                : icono,
          ],
        ),
      ),
    );
  }

  Widget _chipNumeroDiente(String numeroFdi) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final color = _colorParaProfundidad(diente.profundidadMaxima, diente.ausente);
    return GestureDetector(
      onTap: () => _editarDiente(numeroFdi),
      child: Container(
        width: _anchoColumna * 3,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numeroFdi,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
            if (diente.movilidad > 0 && !diente.ausente)
              Text(
                'M${diente.movilidad}',
                style: const TextStyle(fontSize: 8, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filaNumeros(
    List<DienteRegistro> dientes,
    List<String> claves,
    int Function(SitioPeriodontal) obtener,
  ) {
    return Row(
      children: [
        for (final d in dientes)
          for (final clave in claves)
            SizedBox(
              width: _anchoColumna,
              child: Text(
                d.ausente ? '-' : '${obtener(d.sitios[clave]!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 8, color: Colors.black87),
              ),
            ),
      ],
    );
  }

  Widget _filaValorPorDiente(
    List<DienteRegistro> dientes,
    String Function(DienteRegistro) obtener,
  ) {
    return Row(
      children: [
        for (final d in dientes)
          SizedBox(
            width: _anchoColumna * 3,
            child: Text(
              d.ausente ? '-' : obtener(d),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
      ],
    );
  }

  Widget _filaIndicadores(List<DienteRegistro> dientes, List<String> claves) {
    return Row(
      children: [
        for (final d in dientes)
          for (final clave in claves)
            SizedBox(
              width: _anchoColumna,
              child: d.ausente
                  ? const SizedBox(height: 12)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 5,
                          color: d.sitios[clave]!.sangrado
                              ? Colors.red.shade700
                              : Colors.transparent,
                        ),
                        const SizedBox(height: 1),
                        Icon(
                          Icons.square,
                          size: 5,
                          color: d.sitios[clave]!.placa
                              ? Colors.blueGrey.shade900
                              : Colors.transparent,
                        ),
                      ],
                    ),
            ),
      ],
    );
  }

  Widget _arcada(String titulo, List<String> numeros, {required bool esSuperior}) {
    final dientes = numeros.map((n) => widget.examen.dientes[n]!).toList();
    final anchoTotal = numeros.length * 3 * _anchoColumna;
    final clavesArriba = esSuperior ? _sitiosVestibular : _sitiosPalatino;
    final clavesAbajo = esSuperior ? _sitiosPalatino : _sitiosVestibular;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              titulo.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Foto" del diente (ilustración vectorial coloreada por estado)
              Row(children: numeros.map((n) => _iconoDiente(n, esSuperior: esSuperior)).toList()),
              const SizedBox(height: 4),
              const Text('Movilidad', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaValorPorDiente(dientes, (d) => '${d.movilidad}'),
              const Text('Furcación', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaValorPorDiente(
                dientes,
                (d) => esMolar(d.numeroFdi) ? '${d.furca}' : '',
              ),
              const SizedBox(height: 2),
              Text(esSuperior ? 'Vestibular' : 'Vestibular',
                  style: const TextStyle(fontSize: 9, color: Colors.black45)),
              CustomPaint(
                size: Size(anchoTotal, _alturaGrafico),
                painter: _GraficoPeriodontalPainter(
                  dientes: dientes,
                  clavesSitio: clavesArriba,
                  anchoColumna: _anchoColumna,
                  escalaPxPorMm: _escalaPxPorMm,
                  crecerHaciaArriba: true,
                ),
              ),
              const SizedBox(height: 2),
              const Text('PD', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaNumeros(dientes, clavesArriba, (s) => s.profundidadSondaje),
              const Text('REC', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaNumeros(dientes, clavesArriba, (s) => s.recesion),
              const Text('NI', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaNumeros(dientes, clavesArriba, (s) => s.nivelInsercionClinica),
              _filaIndicadores(dientes, clavesArriba),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: numeros.map(_chipNumeroDiente).toList()),
              ),
              _filaIndicadores(dientes, clavesAbajo),
              const Text('NI', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaNumeros(dientes, clavesAbajo, (s) => s.nivelInsercionClinica),
              _filaNumeros(dientes, clavesAbajo, (s) => s.recesion),
              const Text('REC', style: TextStyle(fontSize: 8, color: Colors.black45)),
              _filaNumeros(dientes, clavesAbajo, (s) => s.profundidadSondaje),
              const Text('PD', style: TextStyle(fontSize: 8, color: Colors.black45)),
              const SizedBox(height: 2),
              CustomPaint(
                size: Size(anchoTotal, _alturaGrafico),
                painter: _GraficoPeriodontalPainter(
                  dientes: dientes,
                  clavesSitio: clavesAbajo,
                  anchoColumna: _anchoColumna,
                  escalaPxPorMm: _escalaPxPorMm,
                  crecerHaciaArriba: false,
                ),
              ),
              const SizedBox(height: 2),
              Text(esSuperior ? 'Palatino' : 'Lingual',
                  style: const TextStyle(fontSize: 9, color: Colors.black45)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editarDiente(String numeroFdi) async {
    final diente = widget.examen.dientes[numeroFdi]!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget filaSitio(String clave, String etiqueta) {
              final sitio = diente.sitios[clave]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(etiqueta, style: const TextStyle(fontSize: 12))),
                    _campoNumero(
                      valor: sitio.profundidadSondaje,
                      etiqueta: 'PD',
                      onCambio: (v) => setModalState(() => sitio.profundidadSondaje = v),
                    ),
                    const SizedBox(width: 6),
                    _campoNumero(
                      valor: sitio.recesion,
                      etiqueta: 'REC',
                      onCambio: (v) => setModalState(() => sitio.recesion = v),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.water_drop,
                        color: sitio.sangrado ? Colors.red : Colors.black26,
                      ),
                      tooltip: 'Sangrado al sondaje',
                      onPressed: () =>
                          setModalState(() => sitio.sangrado = !sitio.sangrado),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.circle,
                        color: sitio.placa ? Colors.blueGrey.shade900 : Colors.black26,
                        size: 18,
                      ),
                      tooltip: 'Placa bacteriana',
                      onPressed: () =>
                          setModalState(() => sitio.placa = !sitio.placa),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Diente $numeroFdi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text('Ausente'),
                            Switch(
                              value: diente.ausente,
                              onChanged: (v) =>
                                  setModalState(() => diente.ausente = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text('Movilidad: '),
                        ...List.generate(4, (g) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ChoiceChip(
                              label: Text('$g'),
                              selected: diente.movilidad == g,
                              onSelected: (_) =>
                                  setModalState(() => diente.movilidad = g),
                            ),
                          );
                        }),
                      ],
                    ),
                    if (esMolar(numeroFdi)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Furca: '),
                          ...List.generate(4, (g) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ChoiceChip(
                                label: Text('$g'),
                                selected: diente.furca == g,
                                onSelected: (_) =>
                                    setModalState(() => diente.furca = g),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Vestibular',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    filaSitio('vest_mesial', 'Mesial'),
                    filaSitio('vest_central', 'Central'),
                    filaSitio('vest_distal', 'Distal'),
                    const SizedBox(height: 8),
                    const Text(
                      'Palatino / Lingual',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    filaSitio('palat_mesial', 'Mesial'),
                    filaSitio('palat_central', 'Central'),
                    filaSitio('palat_distal', 'Distal'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Listo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _campoNumero({
    required int valor,
    required String etiqueta,
    required ValueChanged<int> onCambio,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        SizedBox(
          width: 46,
          height: 34,
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  if (valor > 0) {
                    onCambio(valor - 1);
                  }
                },
                child: const Icon(Icons.remove, size: 14),
              ),
              Expanded(
                child: Text(
                  '$valor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: () {
                  if (valor < 15) {
                    onCambio(valor + 1);
                  }
                },
                child: const Icon(Icons.add, size: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: DateFormat('dd/MM/yyyy').format(widget.examen.fecha),
        colores: const [AppTheme.lavanda, AppTheme.rosaOscuro],
        acciones: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Guardar',
            onPressed: () {
              widget.examen.notas = _notasCtrl.text.trim();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: MarcaAguaMuelaK(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                color: Colors.white.withValues(alpha: 0.92),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.nombrePaciente,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sangrado: ${widget.examen.porcentajeSangrado.toStringAsFixed(0)}%  •  '
                        'Placa: ${widget.examen.porcentajePlaca.toStringAsFixed(0)}%  •  '
                        'Bolsas ≥4mm: ${widget.examen.totalDientesConBolsaModerada + widget.examen.totalDientesConBolsaSevera}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white.withValues(alpha: 0.92),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _arcada('Arcada superior', dientesArcadaSuperior, esSuperior: true),
                      const SizedBox(height: 22),
                      _arcada('Arcada inferior', dientesArcadaInferior, esSuperior: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _leyendaBarra(Colors.red.shade400, 'Profundidad de sondaje'),
                  _leyendaLinea(Colors.blue.shade700, 'Margen gingival'),
                  _leyendaLinea(Colors.red.shade600, 'Línea de referencia'),
                  _leyendaPunto(Colors.red.shade700, 'Sangrado', circulo: true),
                  _leyendaPunto(Colors.blueGrey.shade900, 'Placa', circulo: false),
                  _leyenda(Colors.grey.shade300, 'Diente ausente'),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white.withValues(alpha: 0.92),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _notasCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas del examen',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _leyendaBarra(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 12, color: color),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _leyendaLinea(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 2, color: color),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _leyendaPunto(Color color, String texto, {required bool circulo}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: circulo ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Dibuja el gráfico clásico de periodontograma: barras rojas de profundidad
/// de sondaje y una línea azul que traza el margen gingival, para una fila
/// de 3 sitios por diente (vestibular o palatino/lingual).
class _GraficoPeriodontalPainter extends CustomPainter {
  final List<DienteRegistro> dientes;
  final List<String> clavesSitio;
  final double anchoColumna;
  final double escalaPxPorMm;
  final bool crecerHaciaArriba;

  _GraficoPeriodontalPainter({
    required this.dientes,
    required this.clavesSitio,
    required this.anchoColumna,
    required this.escalaPxPorMm,
    required this.crecerHaciaArriba,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final paintDivisor = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    final paintLineaBase = Paint()
      ..color = Colors.red.shade600
      ..strokeWidth = 1.4;
    final paintBarra = Paint()..color = Colors.red.shade400;
    final paintLineaEncia = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final paintPuntoEncia = Paint()..color = Colors.blue.shade700;
    final paintAusente = Paint()..color = Colors.grey.shade200;

    final baseY = crecerHaciaArriba ? size.height : 0.0;

    double yPara(double mm) {
      final desplazamiento = mm * escalaPxPorMm;
      return crecerHaciaArriba ? baseY - desplazamiento : baseY + desplazamiento;
    }

    for (int mm = 3; mm <= 9; mm += 3) {
      final y = yPara(mm.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final puntosEncia = <Offset>[];

    for (int i = 0; i < dientes.length; i++) {
      final diente = dientes[i];
      final xInicioDiente = i * clavesSitio.length * anchoColumna;

      canvas.drawLine(
        Offset(xInicioDiente, 0),
        Offset(xInicioDiente, size.height),
        paintDivisor,
      );

      if (diente.ausente) {
        canvas.drawRect(
          Rect.fromLTWH(
            xInicioDiente,
            0,
            clavesSitio.length * anchoColumna,
            size.height,
          ),
          paintAusente,
        );
        for (int s = 0; s < clavesSitio.length; s++) {
          final x = xInicioDiente + s * anchoColumna + anchoColumna / 2;
          puntosEncia.add(Offset(x, baseY));
        }
        continue;
      }

      for (int s = 0; s < clavesSitio.length; s++) {
        final clave = clavesSitio[s];
        final sitio = diente.sitios[clave]!;
        final x = xInicioDiente + s * anchoColumna + anchoColumna / 2;

        final yMargen = yPara(sitio.recesion.toDouble());
        final yFondo =
            yPara((sitio.recesion + sitio.profundidadSondaje).toDouble());

        final rectBarra = Rect.fromLTRB(
          x - anchoColumna * 0.28,
          crecerHaciaArriba ? yFondo : yMargen,
          x + anchoColumna * 0.28,
          crecerHaciaArriba ? yMargen : yFondo,
        );
        canvas.drawRect(rectBarra, paintBarra);

        puntosEncia.add(Offset(x, yMargen));
      }
    }

    if (puntosEncia.length > 1) {
      final path = Path()..moveTo(puntosEncia.first.dx, puntosEncia.first.dy);
      for (final p in puntosEncia.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paintLineaEncia);
    }
    for (final p in puntosEncia) {
      canvas.drawCircle(p, 1.6, paintPuntoEncia);
    }

    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), paintLineaBase);
  }

  @override
  bool shouldRepaint(covariant _GraficoPeriodontalPainter oldDelegate) => true;
}
