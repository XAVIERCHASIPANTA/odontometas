import 'package:flutter/material.dart';

/// Categoría anatómica de un diente según su número FDI (último dígito).
enum TipoDiente { incisivo, canino, premolar, molar }

TipoDiente tipoDientePorFdi(String numeroFdi) {
  if (numeroFdi.isEmpty) {
    return TipoDiente.incisivo;
  }
  final ultimo = numeroFdi.substring(numeroFdi.length - 1);
  switch (ultimo) {
    case '1':
    case '2':
      return TipoDiente.incisivo;
    case '3':
      return TipoDiente.canino;
    case '4':
    case '5':
      return TipoDiente.premolar;
    case '6':
    case '7':
    case '8':
      return TipoDiente.molar;
    default:
      return TipoDiente.incisivo;
  }
}

/// Dibuja una ilustración vectorial original por tipo de diente (corona +
/// raíz), estilo "línea clínica": blanco con contorno negro grueso, sin
/// relleno de color, inspirada en la anatomía real pero con trazos propios.
/// El incisivo tiene un borde de corte más plano, el canino una cúspide
/// puntiaguda y raíz larga, el premolar una corona más redondeada, y el
/// molar una corona ancha con dos raíces bifurcadas.
class DienteRealistaPainter extends CustomPainter {
  final TipoDiente tipo;
  final Color colorRelleno;
  final Color colorContorno;
  final double grosorContorno;

  DienteRealistaPainter({
    required this.tipo,
    this.colorRelleno = Colors.white,
    this.colorContorno = Colors.black87,
    this.grosorContorno = 2.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (tipo) {
      case TipoDiente.incisivo:
        _dibujarIncisivo(canvas, w, h);
        break;
      case TipoDiente.canino:
        _dibujarCanino(canvas, w, h);
        break;
      case TipoDiente.premolar:
        _dibujarPremolar(canvas, w, h);
        break;
      case TipoDiente.molar:
        _dibujarMolar(canvas, w, h);
        break;
    }
  }

  void _pintarForma(Canvas canvas, Path forma) {
    final paintRelleno = Paint()
      ..color = colorRelleno
      ..style = PaintingStyle.fill;
    final paintContorno = Paint()
      ..color = colorContorno
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosorContorno
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(forma, paintRelleno);
    canvas.drawPath(forma, paintContorno);
  }

  /// Línea cervical: la marca donde termina la corona y empieza la raíz,
  /// bien visible en las ilustraciones clínicas de referencia.
  void _pintarLineaCervical(Canvas canvas, double w, double h, double yFrac,
      {double ancho = 0.30}) {
    final paint = Paint()
      ..color = colorContorno.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosorContorno * 0.6;
    final path = Path()
      ..moveTo(w * (0.5 - ancho), h * yFrac)
      ..quadraticBezierTo(
          w * 0.5, h * (yFrac + 0.025), w * (0.5 + ancho), h * yFrac);
    canvas.drawPath(path, paint);
  }

  /// Surco oclusal: la ranura central en la cara masticatoria de premolares
  /// y molares.
  void _pintarSurcoOclusal(Canvas canvas, double w, double h,
      {required double y, required double ancho}) {
    final paint = Paint()
      ..color = colorContorno.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosorContorno * 0.55;
    final path = Path()
      ..moveTo(w * (0.5 - ancho), h * y)
      ..quadraticBezierTo(w * 0.5, h * (y + 0.03), w * (0.5 + ancho), h * y);
    canvas.drawPath(path, paint);
  }

  void _dibujarIncisivo(Canvas canvas, double w, double h) {
    final corona = Path();
    corona.moveTo(w * 0.30, h * 0.42);
    corona.cubicTo(w * 0.24, h * 0.30, w * 0.26, h * 0.10, w * 0.36, h * 0.06);
    corona.cubicTo(w * 0.44, h * 0.02, w * 0.56, h * 0.02, w * 0.64, h * 0.06);
    corona.cubicTo(w * 0.74, h * 0.10, w * 0.76, h * 0.30, w * 0.70, h * 0.42);
    corona.cubicTo(w * 0.68, h * 0.47, w * 0.60, h * 0.49, w * 0.50, h * 0.49);
    corona.cubicTo(w * 0.40, h * 0.49, w * 0.32, h * 0.47, w * 0.30, h * 0.42);
    corona.close();

    final raiz = Path();
    raiz.moveTo(w * 0.38, h * 0.46);
    raiz.cubicTo(w * 0.36, h * 0.60, w * 0.42, h * 0.80, w * 0.47, h * 0.94);
    raiz.cubicTo(w * 0.485, h * 0.98, w * 0.515, h * 0.98, w * 0.53, h * 0.94);
    raiz.cubicTo(w * 0.58, h * 0.80, w * 0.64, h * 0.60, w * 0.62, h * 0.46);
    raiz.cubicTo(w * 0.55, h * 0.50, w * 0.45, h * 0.50, w * 0.38, h * 0.46);
    raiz.close();

    _pintarForma(canvas, corona);
    _pintarForma(canvas, raiz);
    _pintarLineaCervical(canvas, w, h, 0.455, ancho: 0.20);
  }

  void _dibujarCanino(Canvas canvas, double w, double h) {
    final corona = Path();
    corona.moveTo(w * 0.50, h * 0.02);
    corona.cubicTo(w * 0.62, h * 0.08, w * 0.72, h * 0.20, w * 0.72, h * 0.34);
    corona.cubicTo(w * 0.72, h * 0.44, w * 0.63, h * 0.50, w * 0.50, h * 0.50);
    corona.cubicTo(w * 0.37, h * 0.50, w * 0.28, h * 0.44, w * 0.28, h * 0.34);
    corona.cubicTo(w * 0.28, h * 0.20, w * 0.38, h * 0.08, w * 0.50, h * 0.02);
    corona.close();

    final raiz = Path();
    raiz.moveTo(w * 0.40, h * 0.48);
    raiz.cubicTo(w * 0.38, h * 0.65, w * 0.42, h * 0.85, w * 0.485, h * 0.97);
    raiz.cubicTo(w * 0.495, h * 0.995, w * 0.505, h * 0.995, w * 0.515, h * 0.97);
    raiz.cubicTo(w * 0.58, h * 0.85, w * 0.62, h * 0.65, w * 0.60, h * 0.48);
    raiz.cubicTo(w * 0.55, h * 0.52, w * 0.45, h * 0.52, w * 0.40, h * 0.48);
    raiz.close();

    _pintarForma(canvas, corona);
    _pintarForma(canvas, raiz);
    _pintarLineaCervical(canvas, w, h, 0.475, ancho: 0.18);
  }

  void _dibujarPremolar(Canvas canvas, double w, double h) {
    final corona = Path();
    corona.moveTo(w * 0.26, h * 0.30);
    corona.cubicTo(w * 0.24, h * 0.16, w * 0.34, h * 0.05, w * 0.44, h * 0.08);
    corona.cubicTo(w * 0.48, h * 0.10, w * 0.52, h * 0.10, w * 0.56, h * 0.08);
    corona.cubicTo(w * 0.66, h * 0.05, w * 0.76, h * 0.16, w * 0.74, h * 0.30);
    corona.cubicTo(w * 0.73, h * 0.42, w * 0.63, h * 0.50, w * 0.50, h * 0.50);
    corona.cubicTo(w * 0.37, h * 0.50, w * 0.27, h * 0.42, w * 0.26, h * 0.30);
    corona.close();

    final raiz = Path();
    raiz.moveTo(w * 0.36, h * 0.47);
    raiz.cubicTo(w * 0.34, h * 0.62, w * 0.40, h * 0.82, w * 0.47, h * 0.95);
    raiz.cubicTo(w * 0.485, h * 0.98, w * 0.515, h * 0.98, w * 0.53, h * 0.95);
    raiz.cubicTo(w * 0.60, h * 0.82, w * 0.66, h * 0.62, w * 0.64, h * 0.47);
    raiz.cubicTo(w * 0.56, h * 0.51, w * 0.44, h * 0.51, w * 0.36, h * 0.47);
    raiz.close();

    _pintarForma(canvas, corona);
    _pintarForma(canvas, raiz);
    _pintarLineaCervical(canvas, w, h, 0.465, ancho: 0.24);
    _pintarSurcoOclusal(canvas, w, h, y: 0.16, ancho: 0.14);
  }

  void _dibujarMolar(Canvas canvas, double w, double h) {
    final corona = Path();
    corona.moveTo(w * 0.16, h * 0.30);
    corona.cubicTo(w * 0.14, h * 0.16, w * 0.24, h * 0.06, w * 0.34, h * 0.10);
    corona.cubicTo(w * 0.40, h * 0.13, w * 0.42, h * 0.05, w * 0.50, h * 0.05);
    corona.cubicTo(w * 0.58, h * 0.05, w * 0.60, h * 0.13, w * 0.66, h * 0.10);
    corona.cubicTo(w * 0.76, h * 0.06, w * 0.86, h * 0.16, w * 0.84, h * 0.30);
    corona.cubicTo(w * 0.83, h * 0.42, w * 0.68, h * 0.50, w * 0.50, h * 0.50);
    corona.cubicTo(w * 0.32, h * 0.50, w * 0.17, h * 0.42, w * 0.16, h * 0.30);
    corona.close();

    final raizIzq = Path();
    raizIzq.moveTo(w * 0.28, h * 0.47);
    raizIzq.cubicTo(w * 0.24, h * 0.60, w * 0.26, h * 0.78, w * 0.34, h * 0.92);
    raizIzq.cubicTo(w * 0.36, h * 0.95, w * 0.40, h * 0.94, w * 0.40, h * 0.90);
    raizIzq.cubicTo(w * 0.40, h * 0.75, w * 0.40, h * 0.58, w * 0.42, h * 0.47);
    raizIzq.cubicTo(w * 0.37, h * 0.49, w * 0.32, h * 0.49, w * 0.28, h * 0.47);
    raizIzq.close();

    final raizDer = Path();
    raizDer.moveTo(w * 0.72, h * 0.47);
    raizDer.cubicTo(w * 0.76, h * 0.60, w * 0.74, h * 0.78, w * 0.66, h * 0.92);
    raizDer.cubicTo(w * 0.64, h * 0.95, w * 0.60, h * 0.94, w * 0.60, h * 0.90);
    raizDer.cubicTo(w * 0.60, h * 0.75, w * 0.60, h * 0.58, w * 0.58, h * 0.47);
    raizDer.cubicTo(w * 0.63, h * 0.49, w * 0.68, h * 0.49, w * 0.72, h * 0.47);
    raizDer.close();

    _pintarForma(canvas, raizIzq);
    _pintarForma(canvas, raizDer);
    _pintarForma(canvas, corona);
    _pintarLineaCervical(canvas, w, h, 0.465, ancho: 0.32);
    _pintarSurcoOclusal(canvas, w, h, y: 0.14, ancho: 0.22);
  }

  @override
  bool shouldRepaint(covariant DienteRealistaPainter oldDelegate) {
    return oldDelegate.tipo != tipo ||
        oldDelegate.colorRelleno != colorRelleno ||
        oldDelegate.colorContorno != colorContorno ||
        oldDelegate.grosorContorno != grosorContorno;
  }
}

class DienteRealistaVector extends StatelessWidget {
  final TipoDiente tipo;
  final double size;
  final Color colorRelleno;
  final Color colorContorno;

  const DienteRealistaVector({
    super.key,
    required this.tipo,
    this.size = 34,
    this.colorRelleno = Colors.white,
    this.colorContorno = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: CustomPaint(
        painter: DienteRealistaPainter(
          tipo: tipo,
          colorRelleno: colorRelleno,
          colorContorno: colorContorno,
        ),
      ),
    );
  }
}
