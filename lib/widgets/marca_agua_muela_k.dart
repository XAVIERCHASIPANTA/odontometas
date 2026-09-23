import 'package:flutter/material.dart';
import 'muela_vector.dart';

/// Marca de agua repetida a pantalla completa: una muelita vectorial en
/// blanco y negro junto a la letra "K", como sello personal de marca.
/// Se usa de fondo en las pantallas de llenado del periodontograma.
class MarcaAguaMuelaK extends StatelessWidget {
  final Widget child;
  final Color colorFondo;

  const MarcaAguaMuelaK({
    super.key,
    required this.child,
    this.colorFondo = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: colorFondo),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.06,
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                ),
                itemCount: 60,
                itemBuilder: (ctx, i) {
                  return Center(
                    child: Transform.rotate(
                      angle: i.isEven ? -0.2 : 0.2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          MuelaVector(
                            size: 34,
                            color: Colors.black,
                            colorBrillo: Color(0x33000000),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'K',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
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
