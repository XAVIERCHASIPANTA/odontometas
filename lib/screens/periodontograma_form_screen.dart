import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _PeriodontogramaFormScreenState extends State<PeriodontogramaFormScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _notasCtrl;
  late final AnimationController _entrada;

  static const double _anchoColumna = 15.0;
  static const double _alturaGrafico = 116.0;
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
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _entrada.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // COLOR / SEVERIDAD
  // ---------------------------------------------------------------------

  Color _colorParaProfundidad(int pd, bool ausente) {
    if (ausente) return Colors.grey.shade300;
    if (pd >= 6) return const Color(0xFFE53935);
    if (pd >= 4) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  List<Color> _gradienteParaProfundidad(int pd, bool ausente) {
    final base = _colorParaProfundidad(pd, ausente);
    return [Color.lerp(base, Colors.white, 0.35)!, base];
  }

  // ---------------------------------------------------------------------
  // ARCADA — dientes + chips + gráfico
  // ---------------------------------------------------------------------

  Widget _iconoDiente(String numeroFdi, {required bool esSuperior, required int indice}) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final color = _colorParaProfundidad(diente.profundidadMaxima, diente.ausente);
    final tipo = tipoDientePorFdi(numeroFdi);
    final icono = Transform.rotate(
      angle: esSuperior ? 0 : math.pi,
      child: DienteRealistaVector(tipo: tipo, size: 34, colorRelleno: color),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + indice * 18),
      curve: Curves.easeOutBack,
      builder: (context, valor, child) => Transform.scale(
        scale: valor.clamp(0.0, 1.0),
        child: Opacity(opacity: valor.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _editarDiente(numeroFdi);
        },
        child: SizedBox(
          width: _anchoColumna * 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              diente.ausente
                  ? Icon(Icons.close_rounded, size: 26, color: Colors.grey.shade400)
                  : icono,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipNumeroDiente(String numeroFdi) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final gradiente = _gradienteParaProfundidad(diente.profundidadMaxima, diente.ausente);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _editarDiente(numeroFdi);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        width: _anchoColumna * 3,
        margin: const EdgeInsets.symmetric(horizontal: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradiente,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: gradiente.last.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
                style: const TextStyle(fontSize: 8, color: Colors.white70),
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
                        AnimatedScale(
                          duration: const Duration(milliseconds: 250),
                          scale: d.sitios[clave]!.sangrado ? 1 : 0,
                          child: Icon(Icons.circle, size: 5, color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 1),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 250),
                          scale: d.sitios[clave]!.placa ? 1 : 0,
                          child: Icon(Icons.square, size: 5, color: Colors.blueGrey.shade900),
                        ),
                      ],
                    ),
            ),
      ],
    );
  }

  Widget _tituloFila(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 8,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _arcada(String titulo, List<String> numeros, {required bool esSuperior}) {
    final dientes = numeros.map((n) => widget.examen.dientes[n]!).toList();
    final anchoTotal = numeros.length * 3 * _anchoColumna;
    final clavesArriba = esSuperior ? _sitiosVestibular : _sitiosPalatino;
    final clavesAbajo = esSuperior ? _sitiosPalatino : _sitiosVestibular;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.rosaOscuro,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  titulo.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                    color: AppTheme.rosaOscuro,
                  ),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (int i = 0; i < numeros.length; i++)
                    _iconoDiente(numeros[i], esSuperior: esSuperior, indice: i),
                ],
              ),
              const SizedBox(height: 4),
              _tituloFila('MOVILIDAD'),
              _filaValorPorDiente(dientes, (d) => '${d.movilidad}'),
              _tituloFila('FURCACIÓN'),
              _filaValorPorDiente(
                dientes,
                (d) => esMolar(d.numeroFdi) ? '${d.furca}' : '',
              ),
              const SizedBox(height: 3),
              _tituloFila('VESTIBULAR'),
              CustomPaint(
                size: Size(anchoTotal, _alturaGrafico),
                painter: _GraficoPeriodontalPainter(
                  dientes: dientes,
                  clavesSitio: clavesArriba,
                  anchoColumna: _anchoColumna,
                  escalaPxPorMm: _escalaPxPorMm,
                  crecerHaciaArriba: true,
                  colorParaProfundidad: _colorParaProfundidad,
                ),
              ),
              const SizedBox(height: 2),
              _tituloFila('PD'),
              _filaNumeros(dientes, clavesArriba, (s) => s.profundidadSondaje),
              _tituloFila('REC'),
              _filaNumeros(dientes, clavesArriba, (s) => s.recesion),
              _tituloFila('NI'),
              _filaNumeros(dientes, clavesArriba, (s) => s.nivelInsercionClinica),
              _filaIndicadores(dientes, clavesArriba),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: numeros.map(_chipNumeroDiente).toList()),
              ),
              _filaIndicadores(dientes, clavesAbajo),
              _tituloFila('NI'),
              _filaNumeros(dientes, clavesAbajo, (s) => s.nivelInsercionClinica),
              _filaNumeros(dientes, clavesAbajo, (s) => s.recesion),
              _tituloFila('REC'),
              _filaNumeros(dientes, clavesAbajo, (s) => s.profundidadSondaje),
              _tituloFila('PD'),
              const SizedBox(height: 2),
              CustomPaint(
                size: Size(anchoTotal, _alturaGrafico),
                painter: _GraficoPeriodontalPainter(
                  dientes: dientes,
                  clavesSitio: clavesAbajo,
                  anchoColumna: _anchoColumna,
                  escalaPxPorMm: _escalaPxPorMm,
                  crecerHaciaArriba: false,
                  colorParaProfundidad: _colorParaProfundidad,
                ),
              ),
              const SizedBox(height: 2),
              _tituloFila(esSuperior ? 'PALATINO' : 'LINGUAL'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // EDITAR DIENTE — bottom sheet rediseñado
  // ---------------------------------------------------------------------

  Future<void> _editarDiente(String numeroFdi) async {
    final diente = widget.examen.dientes[numeroFdi]!;
    final tipo = tipoDientePorFdi(numeroFdi);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final color = _colorParaProfundidad(diente.profundidadMaxima, diente.ausente);

            Widget filaSitio(String clave, String etiqueta) {
              final sitio = diente.sitios[clave]!;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(etiqueta,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    _campoNumero(
                      valor: sitio.profundidadSondaje,
                      etiqueta: 'PD',
                      onCambio: (v) => setModalState(() => sitio.profundidadSondaje = v),
                    ),
                    const SizedBox(width: 8),
                    _campoNumero(
                      valor: sitio.recesion,
                      etiqueta: 'REC',
                      onCambio: (v) => setModalState(() => sitio.recesion = v),
                    ),
                    const Spacer(),
                    _botonToggle(
                      activo: sitio.sangrado,
                      colorActivo: Colors.red.shade600,
                      icono: Icons.water_drop_rounded,
                      onTap: () => setModalState(() => sitio.sangrado = !sitio.sangrado),
                    ),
                    const SizedBox(width: 4),
                    _botonToggle(
                      activo: sitio.placa,
                      colorActivo: Colors.blueGrey.shade800,
                      icono: Icons.circle,
                      onTap: () => setModalState(() => sitio.placa = !sitio.placa),
                    ),
                  ],
                ),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.86,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx, scrollCtrl) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.zero,
                  children: [
                    // ---- Encabezado con gradiente y diente grande ----
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color.withValues(alpha: 0.85), AppTheme.rosaOscuro],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: DienteRealistaVector(tipo: tipo, size: 36, colorRelleno: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pieza $numeroFdi',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                Text(_nombreTipoDiente(tipo),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Ausente',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                              Switch(
                                value: diente.ausente,
                                activeColor: Colors.white,
                                activeTrackColor: Colors.white38,
                                onChanged: (v) => setModalState(() => diente.ausente = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Movilidad', style: TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              ...List.generate(4, (g) {
                                final activo = diente.movilidad == g;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _pildoraGrado(
                                    texto: '$g',
                                    activo: activo,
                                    onTap: () => setModalState(() => diente.movilidad = g),
                                  ),
                                );
                              }),
                            ],
                          ),
                          if (esMolar(numeroFdi)) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text('Furca', style: TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                ...List.generate(4, (g) {
                                  final activo = diente.furca == g;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _pildoraGrado(
                                      texto: '$g',
                                      activo: activo,
                                      onTap: () => setModalState(() => diente.furca = g),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          _tituloSeccion('Vestibular', Icons.arrow_upward_rounded),
                          filaSitio('vest_mesial', 'Mesial'),
                          filaSitio('vest_central', 'Central'),
                          filaSitio('vest_distal', 'Distal'),
                          const SizedBox(height: 12),
                          _tituloSeccion('Palatino / Lingual', Icons.arrow_downward_rounded),
                          filaSitio('palat_mesial', 'Mesial'),
                          filaSitio('palat_central', 'Central'),
                          filaSitio('palat_distal', 'Distal'),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.rosaOscuro,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                setState(() {});
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Listo',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
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

  String _nombreTipoDiente(TipoDiente t) {
    switch (t) {
      case TipoDiente.incisivo:
        return 'Incisivo';
      case TipoDiente.canino:
        return 'Canino';
      case TipoDiente.premolar:
        return 'Premolar';
      case TipoDiente.molar:
        return 'Molar';
    }
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icono, size: 15, color: AppTheme.rosaOscuro),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.rosaOscuro)),
        ],
      ),
    );
  }

  Widget _pildoraGrado({required String texto, required bool activo, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? AppTheme.rosaOscuro : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: activo ? AppTheme.rosaOscuro : Colors.grey.shade300),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _botonToggle({
    required bool activo,
    required Color colorActivo,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: activo ? colorActivo.withValues(alpha: 0.12) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: activo ? 1.15 : 1,
          child: Icon(icono, size: 18, color: activo ? colorActivo : Colors.black26),
        ),
      ),
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
        Text(etiqueta,
            style: const TextStyle(fontSize: 8, color: Colors.black45, fontWeight: FontWeight.w600)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _botonPasoMini(
              icono: Icons.remove_rounded,
              onTap: () {
                if (valor > 0) onCambio(valor - 1);
              },
            ),
            SizedBox(
              width: 22,
              child: Text(
                '$valor',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            _botonPasoMini(
              icono: Icons.add_rounded,
              onTap: () {
                if (valor < 15) onCambio(valor + 1);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonPasoMini({required IconData icono, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icono, size: 12),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final examen = widget.examen;
    final bolsas = examen.totalDientesConBolsaModerada + examen.totalDientesConBolsaSevera;

    return Scaffold(
      appBar: appBarConGradiente(
        titulo: DateFormat('dd/MM/yyyy').format(examen.fecha),
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
          child: FadeTransition(
            opacity: _entrada,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ---- Panel resumen tipo "dashboard" ----
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.lavanda, AppTheme.rosaOscuro],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.rosaOscuro.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.nombrePaciente,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Odontograma periodontal',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Gauge(
                            valor: examen.porcentajeSangrado,
                            etiqueta: 'Sangrado',
                            color: const Color(0xFFFF7A7A),
                          ),
                          _Gauge(
                            valor: examen.porcentajePlaca,
                            etiqueta: 'Placa',
                            color: const Color(0xFF80DEEA),
                          ),
                          _GaugeEntero(
                            valor: bolsas,
                            etiqueta: 'Bolsas ≥4mm',
                            color: const Color(0xFFFFD180),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 3,
                  shadowColor: AppTheme.rosaOscuro.withValues(alpha: 0.2),
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _arcada('Arcada superior', dientesArcadaSuperior, esSuperior: true),
                        const SizedBox(height: 24),
                        _arcada('Arcada inferior', dientesArcadaInferior, esSuperior: false),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _leyendaBarra(const Color(0xFF43A047), '< 4mm sano'),
                      _leyendaBarra(const Color(0xFFFB8C00), '4-5mm moderado'),
                      _leyendaBarra(const Color(0xFFE53935), '≥6mm severo'),
                      _leyendaLinea(Colors.blue.shade700, 'Margen gingival'),
                      _leyendaPunto(Colors.red.shade700, 'Sangrado', circulo: true),
                      _leyendaPunto(Colors.blueGrey.shade900, 'Placa', circulo: false),
                      _leyenda(Colors.grey.shade300, 'Diente ausente'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextField(
                      controller: _notasCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notas del examen',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
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
        Container(
          width: 10,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
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

// ---------------------------------------------------------------------
// GAUGE ANIMADO — anillo circular de progreso con porcentaje al centro
// ---------------------------------------------------------------------

class _Gauge extends StatelessWidget {
  final double valor; // 0-100
  final String etiqueta;
  final Color color;
  const _Gauge({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: valor.clamp(0, 100)),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) {
            return SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(62, 62),
                    painter: _AroPainter(porcentaje: v, color: color),
                  ),
                  Text('${v.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10)),
      ],
    );
  }
}

class _GaugeEntero extends StatelessWidget {
  final int valor;
  final String etiqueta;
  final Color color;
  const _GaugeEntero({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: valor),
          duration: const Duration(milliseconds: 900),
          builder: (context, v, child) {
            return Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
                border: Border.all(color: color, width: 2.4),
              ),
              alignment: Alignment.center,
              child: Text('$v',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10)),
      ],
    );
  }
}

class _AroPainter extends CustomPainter {
  final double porcentaje; // 0-100
  final Color color;
  _AroPainter({required this.porcentaje, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2 - 4;
    final fondo = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final frente = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centro, radio, fondo);
    final barrido = 2 * math.pi * (porcentaje / 100);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -math.pi / 2,
      barrido,
      false,
      frente,
    );
  }

  @override
  bool shouldRepaint(covariant _AroPainter oldDelegate) =>
      oldDelegate.porcentaje != porcentaje || oldDelegate.color != color;
}

// ---------------------------------------------------------------------
// GRÁFICO PERIODONTAL — barras con color por severidad + línea de encía
// ---------------------------------------------------------------------

class _GraficoPeriodontalPainter extends CustomPainter {
  final List<DienteRegistro> dientes;
  final List<String> clavesSitio;
  final double anchoColumna;
  final double escalaPxPorMm;
  final bool crecerHaciaArriba;
  final Color Function(int pd, bool ausente) colorParaProfundidad;

  _GraficoPeriodontalPainter({
    required this.dientes,
    required this.clavesSitio,
    required this.anchoColumna,
    required this.escalaPxPorMm,
    required this.crecerHaciaArriba,
    required this.colorParaProfundidad,
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
    final paintLineaEncia = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paintPuntoEncia = Paint()..color = Colors.blue.shade700;
    final paintAusente = Paint()..color = Colors.grey.shade100;

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
          Rect.fromLTWH(xInicioDiente, 0, clavesSitio.length * anchoColumna, size.height),
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
        final yFondo = yPara((sitio.recesion + sitio.profundidadSondaje).toDouble());

        final rectBarra = Rect.fromLTRB(
          x - anchoColumna * 0.3,
          crecerHaciaArriba ? yFondo : yMargen,
          x + anchoColumna * 0.3,
          crecerHaciaArriba ? yMargen : yFondo,
        );
        final colorBarra = colorParaProfundidad(sitio.profundidadSondaje, false);
        final paintBarra = Paint()
          ..shader = LinearGradient(
            colors: [colorBarra.withValues(alpha: 0.65), colorBarra],
            begin: crecerHaciaArriba ? Alignment.bottomCenter : Alignment.topCenter,
            end: crecerHaciaArriba ? Alignment.topCenter : Alignment.bottomCenter,
          ).createShader(rectBarra);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rectBarra, const Radius.circular(2)),
          paintBarra,
        );

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
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      canvas.drawCircle(p, 1.6, paintPuntoEncia);
    }

    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), paintLineaBase);
  }

  @override
  bool shouldRepaint(covariant _GraficoPeriodontalPainter oldDelegate) => true;
}
