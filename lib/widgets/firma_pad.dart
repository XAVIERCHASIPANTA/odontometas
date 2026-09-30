import 'package:flutter/material.dart';
import '../models/ficha_clinica.dart';

/// Resultado de firmar en pantalla: trazos ya codificados y tamaño del
/// lienzo (para poder redibujar la firma en cualquier tamaño).
class ResultadoFirma {
  final List<String> trazos;
  final double ancho;
  final double alto;
  const ResultadoFirma(this.trazos, this.ancho, this.alto);
}

/// Pantalla completa para firmar con el dedo. Se usa una pantalla aparte
/// (y no una hoja con scroll) para que el gesto de dibujar no compita con
/// el desplazamiento.
class FirmaPadPantalla extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  const FirmaPadPantalla({
    super.key,
    this.titulo = 'Firma del paciente',
    this.subtitulo = 'Firme con el dedo dentro del recuadro',
  });

  @override
  State<FirmaPadPantalla> createState() => _FirmaPadPantallaState();
}

class _FirmaPadPantallaState extends State<FirmaPadPantalla> {
  final List<List<Offset>> _trazos = [];
  Size _tamano = Size.zero;

  void _inicio(Offset p) {
    setState(() => _trazos.add([p]));
  }

  void _mover(Offset p) {
    if (_trazos.isEmpty) {
      return;
    }
    final actual = _trazos.last;
    if ((actual.last - p).distance < 1.5) {
      return;
    }
    setState(() => actual.add(p));
  }

  void _deshacer() {
    if (_trazos.isNotEmpty) {
      setState(() => _trazos.removeLast());
    }
  }

  void _borrar() => setState(_trazos.clear);

  void _listo() {
    if (_trazos.isEmpty || _tamano.isEmpty) {
      return;
    }
    final codificados = _trazos
        .map((t) => Consentimiento.codificarTrazo(
              t.map((o) => [o.dx, o.dy]).toList(),
            ))
        .toList();
    Navigator.pop(
      context,
      ResultadoFirma(codificados, _tamano.width, _tamano.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vacio = _trazos.isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: Text(widget.titulo),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7E57C2), Color(0xFFEC407A)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Deshacer último trazo',
            onPressed: vacio ? null : _deshacer,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Borrar todo',
            onPressed: vacio ? null : _borrar,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                widget.subtitulo,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF7E57C2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        _tamano = Size(c.maxWidth, c.maxHeight);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (d) => _inicio(d.localPosition),
                          onPanUpdate: (d) => _mover(d.localPosition),
                          child: CustomPaint(
                            size: Size(c.maxWidth, c.maxHeight),
                            painter: _PintorFirma(_trazos),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: vacio ? null : _listo,
                      icon: const Icon(Icons.check),
                      label: const Text('Aceptar firma'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorFirma extends CustomPainter {
  final List<List<Offset>> trazos;
  _PintorFirma(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    // Línea guía
    final guia = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(24, size.height * 0.78),
      Offset(size.width - 24, size.height * 0.78),
      guia,
    );
    final tinta = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, 1.6, tinta..style = PaintingStyle.fill);
        tinta.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(t.first.dx, t.first.dy);
      for (var i = 1; i < t.length; i++) {
        path.lineTo(t[i].dx, t[i].dy);
      }
      canvas.drawPath(path, tinta);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorFirma old) => true;
}

/// Muestra una firma ya guardada, escalada para caber en su recuadro.
class FirmaVista extends StatelessWidget {
  final Consentimiento consentimiento;
  final double alto;
  const FirmaVista({super.key, required this.consentimiento, this.alto = 90});

  @override
  Widget build(BuildContext context) {
    final trazos = consentimiento.trazos;
    if (trazos.isEmpty ||
        consentimiento.firmaAncho <= 0 ||
        consentimiento.firmaAlto <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      height: alto,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: CustomPaint(
        painter: _PintorFirmaGuardada(
          trazos,
          consentimiento.firmaAncho,
          consentimiento.firmaAlto,
        ),
      ),
    );
  }
}

class _PintorFirmaGuardada extends CustomPainter {
  final List<List<List<double>>> trazos;
  final double ancho;
  final double alto;
  _PintorFirmaGuardada(this.trazos, this.ancho, this.alto);

  @override
  void paint(Canvas canvas, Size size) {
    final escala = (size.width / ancho) < (size.height / alto)
        ? size.width / ancho
        : size.height / alto;
    final dx = (size.width - ancho * escala) / 2;
    final dy = (size.height - alto * escala) / 2;
    final tinta = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      Offset p(List<double> xy) => Offset(dx + xy[0] * escala, dy + xy[1] * escala);
      if (t.length == 1) {
        canvas.drawCircle(p(t.first), 1.2, Paint()..color = tinta.color);
        continue;
      }
      final path = Path()..moveTo(p(t.first).dx, p(t.first).dy);
      for (var i = 1; i < t.length; i++) {
        final o = p(t[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, tinta);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorFirmaGuardada old) =>
      old.trazos != trazos || old.ancho != ancho || old.alto != alto;
}
