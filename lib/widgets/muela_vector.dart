import 'package:flutter/material.dart';

/// Dibuja una muelita estilizada usando vectores (Path + Canvas),
/// no una fotografía. Así se puede recolorear y escalar sin perder calidad.
class MuelaPainter extends CustomPainter {
  final Color colorPrincipal;
  final Color colorBrillo;

  MuelaPainter({required this.colorPrincipal, required this.colorBrillo});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.30, h * 0.20);
    path.cubicTo(w * 0.28, h * 0.05, w * 0.42, h * 0.02, w * 0.46, h * 0.14);
    path.cubicTo(w * 0.48, h * 0.05, w * 0.58, h * 0.05, w * 0.60, h * 0.14);
    path.cubicTo(w * 0.64, h * 0.02, w * 0.78, h * 0.05, w * 0.76, h * 0.20);
    path.cubicTo(w * 0.92, h * 0.24, w * 0.90, h * 0.42, w * 0.82, h * 0.50);
    path.cubicTo(w * 0.88, h * 0.62, w * 0.86, h * 0.82, w * 0.74, h * 0.92);
    path.cubicTo(w * 0.68, h * 0.96, w * 0.64, h * 0.86, w * 0.63, h * 0.70);
    path.cubicTo(w * 0.62, h * 0.60, w * 0.58, h * 0.58, w * 0.55, h * 0.58);
    path.cubicTo(w * 0.52, h * 0.58, w * 0.48, h * 0.60, w * 0.47, h * 0.70);
    path.cubicTo(w * 0.46, h * 0.86, w * 0.42, h * 0.96, w * 0.36, h * 0.92);
    path.cubicTo(w * 0.24, h * 0.82, w * 0.22, h * 0.62, w * 0.28, h * 0.50);
    path.cubicTo(w * 0.20, h * 0.42, w * 0.18, h * 0.24, w * 0.30, h * 0.20);
    path.close();

    final paintFill = Paint()
      ..color = colorPrincipal
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    final brillo = Path();
    brillo.moveTo(w * 0.38, h * 0.18);
    brillo.cubicTo(w * 0.40, h * 0.10, w * 0.48, h * 0.08, w * 0.50, h * 0.14);
    brillo.cubicTo(w * 0.46, h * 0.22, w * 0.40, h * 0.24, w * 0.38, h * 0.18);
    brillo.close();
    final paintBrillo = Paint()
      ..color = colorBrillo
      ..style = PaintingStyle.fill;
    canvas.drawPath(brillo, paintBrillo);
  }

  @override
  bool shouldRepaint(covariant MuelaPainter oldDelegate) {
    return oldDelegate.colorPrincipal != colorPrincipal ||
        oldDelegate.colorBrillo != colorBrillo;
  }
}

class MuelaVector extends StatelessWidget {
  final double size;
  final Color color;
  final Color colorBrillo;

  const MuelaVector({
    super.key,
    this.size = 60,
    this.color = const Color(0xFFEC407A),
    this.colorBrillo = const Color(0x55FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MuelaPainter(colorPrincipal: color, colorBrillo: colorBrillo),
      ),
    );
  }
}