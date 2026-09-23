import 'package:flutter/material.dart';
import 'muela_vector.dart';

/// Envuelve una pantalla con un fondo colorido y muelitas vectorizadas
/// como marca de agua decorativa, muy sutil, detrás del contenido.
class FondoDecorativo extends StatelessWidget {
  final Widget child;
  final List<Color> coloresGradiente;
  final Color colorMuelitas;

  const FondoDecorativo({
    super.key,
    required this.child,
    this.coloresGradiente = const [
      Color(0xFFFFF0F5),
      Color(0xFFF3E8FF),
      Color(0xFFE0F7F5),
    ],
    this.colorMuelitas = const Color(0xFFEC407A),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: coloresGradiente,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.08,
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                ),
                itemCount: 60,
                itemBuilder: (ctx, i) {
                  return Center(
                    child: Transform.rotate(
                      angle: i.isEven ? -0.25 : 0.25,
                      child: MuelaVector(size: 34, color: colorMuelitas),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
