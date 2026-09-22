import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/odontograma.dart';
import '../models/periodontograma.dart' show dientesArcadaSuperior, dientesArcadaInferior;
import '../theme/app_theme.dart';
import '../widgets/marca_agua_muela_k.dart';
import '../widgets/dientes_realistas.dart';
import '../widgets/presionable.dart';

class OdontogramaFormScreen extends StatefulWidget {
  final Odontograma examen;
  final String nombrePaciente;
  const OdontogramaFormScreen({
    super.key,
    required this.examen,
    required this.nombrePaciente,
  });

  @override
  State<OdontogramaFormScreen> createState() => _OdontogramaFormScreenState();
}

class _OdontogramaFormScreenState extends State<OdontogramaFormScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _notasCtrl;
  late final AnimationController _pulso;
  static const double _anchoColumna = 34.0;

  @override
  void initState() {
    super.initState();
    _notasCtrl = TextEditingController(text: widget.examen.notas ?? '');
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _pulso.dispose();
    super.dispose();
  }

  Color _color(EstadoDiente e) => Color(estiloEstadoDiente[e]!.colorValue);

  bool _esSevero(DienteOdontograma pieza) {
    final estado = pieza.estadoGeneral ?? pieza.caras.values.firstWhere(
          (e) => e == EstadoDiente.caries || e == EstadoDiente.extraccionIndicada,
          orElse: () => EstadoDiente.sano,
        );
    return estado == EstadoDiente.caries || estado == EstadoDiente.extraccionIndicada;
  }

  Widget _iconoDiente(String numeroFdi, {required bool esSuperior, required int indice}) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final tipo = tipoDientePorFdi(numeroFdi);
    final color = _color(diente.estadoVisual);
    final esSevero = _esSevero(diente);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + indice * 35),
      curve: Curves.elasticOut,
      builder: (context, valor, child) => Transform.scale(
        scale: valor.clamp(0.0, 1.3),
        child: Opacity(opacity: valor.clamp(0.0, 1.0), child: child),
      ),
      child: Presionable(
        onTap: () => _editarDiente(numeroFdi),
        child: AnimatedBuilder(
          animation: _pulso,
          builder: (context, child) {
            if (!esSevero) return child!;
            final t = _pulso.value;
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.15 + 0.35 * t),
                    blurRadius: 4 + 10 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: SizedBox(
            width: _anchoColumna,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: esSuperior ? 0 : 3.14159265,
                  child: diente.estadoGeneral == EstadoDiente.ausente
                      ? const Icon(Icons.close, size: 26, color: Colors.black38)
                      : DienteRealistaVector(
                          tipo: tipo,
                          size: 30,
                          colorRelleno: color,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipNumeroDiente(String numeroFdi) {
    final diente = widget.examen.dientes[numeroFdi]!;
    final color = _color(diente.estadoVisual);
    final esClaro = diente.estadoVisual == EstadoDiente.sano;
    final esSevero = _esSevero(diente);
    final gradiente = [Color.lerp(color, Colors.white, 0.35)!, color];
    return Presionable(
      onTap: () => _editarDiente(numeroFdi),
      child: AnimatedBuilder(
        animation: _pulso,
        builder: (context, child) {
          final t = esSevero ? _pulso.value : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            width: _anchoColumna,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradiente,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3 + 0.4 * t),
                  blurRadius: 3 + 8 * t,
                  spreadRadius: t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Text(
          numeroFdi,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: esClaro ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _arcada(String titulo, List<String> numeros, {required bool esSuperior}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
              if (esSuperior)
                Row(children: numeros.map((n) => _chipNumeroDiente(n)).toList()),
              Row(children: [
                for (int i = 0; i < numeros.length; i++)
                  _iconoDiente(numeros[i], esSuperior: esSuperior, indice: i),
              ]),
              if (!esSuperior)
                Row(children: numeros.map((n) => _chipNumeroDiente(n)).toList()),
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
            Widget chipEstado(EstadoDiente e, {required bool esCaraEspecifica, CaraDental? cara}) {
              final estilo = estiloEstadoDiente[e]!;
              final seleccionado = esCaraEspecifica
                  ? (diente.estadoGeneral == null && diente.caras[cara] == e)
                  : diente.estadoGeneral == e ||
                      (e == EstadoDiente.sano && diente.estadoGeneral == null && cara == null);
              return ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: Color(estilo.colorValue),
                  radius: 8,
                ),
                label: Text(estilo.etiqueta, style: const TextStyle(fontSize: 12)),
                selected: seleccionado,
                onSelected: (_) => setModalState(() {
                  if (esCaraEspecifica) {
                    diente.estadoGeneral = null;
                    diente.caras[cara!] = e;
                  } else {
                    diente.estadoGeneral = e == EstadoDiente.sano ? null : e;
                  }
                }),
              );
            }

            Widget filaCara(CaraDental cara) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiquetaCara[cara]!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in EstadoDiente.values)
                          if (!estadosDePiezaCompleta.contains(e))
                            chipEstado(e, esCaraEspecifica: true, cara: cara),
                      ],
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
                    Text(
                      'Pieza $numeroFdi',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    const Text('Estado de la pieza completa',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        chipEstado(EstadoDiente.sano, esCaraEspecifica: false),
                        for (final e in estadosDePiezaCompleta)
                          chipEstado(e, esCaraEspecifica: false),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (diente.estadoGeneral == null) ...[
                      const Divider(),
                      const Text('Estado por cara',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      for (final cara in CaraDental.values) filaCara(cara),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Esta pieza está marcada como "${estiloEstadoDiente[diente.estadoGeneral]!.etiqueta}". '
                          'Elige "Sano" arriba si quieres volver a registrar sus 5 caras por separado.',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
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

  Widget _leyenda(EstadoDiente e) {
    final estilo = estiloEstadoDiente[e]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Color(estilo.colorValue),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 4),
        Text(estilo.etiqueta, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = widget.examen.resumenPorEstado();
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Odontograma — ${DateFormat('dd/MM/yyyy').format(widget.examen.fecha)}',
        colores: const [AppTheme.mentaFresca, AppTheme.rosaOscuro],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.nombrePaciente,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white.withValues(alpha: 0.92),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _arcada('Arcada superior', dientesArcadaSuperior, esSuperior: true),
                      const SizedBox(height: 26),
                      _arcada('Arcada inferior', dientesArcadaInferior, esSuperior: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [for (final e in EstadoDiente.values) _leyenda(e)],
              ),
              const SizedBox(height: 16),
              if (resumen.isNotEmpty)
                Card(
                  color: AppTheme.rosaClaro.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Resumen clínico',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ...resumen.entries.map((e) => Text(
                            '• ${estiloEstadoDiente[e.key]!.etiqueta}: ${e.value} pieza(s)')),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white.withValues(alpha: 0.92),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _notasCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas del odontograma',
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
}
