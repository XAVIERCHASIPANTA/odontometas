import 'package:flutter/material.dart';
import '../models/ayuda_temas.dart';

/// Contenido de un tema de ayuda (resumen, pasos y consejos). Lo usan la
/// ventana flotante y el Centro de ayuda.
class CuerpoAyuda extends StatelessWidget {
  final AyudaTema tema;
  const CuerpoAyuda({super.key, required this.tema});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tema.resumen,
          style: const TextStyle(fontSize: 14.5, height: 1.35),
        ),
        if (tema.pasos.isNotEmpty) ...[
          const SizedBox(height: 14),
          _subtitulo('Cómo se usa', Icons.touch_app_outlined),
          const SizedBox(height: 6),
          for (var i = 0; i < tema.pasos.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tema.color, tema.colorOscuro],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tema.pasos[i],
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (tema.consejos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tema.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tema.color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: tema.colorOscuro),
                    const SizedBox(width: 6),
                    Text(
                      'Buenos consejos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tema.colorOscuro,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final c in tema.consejos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: tema.colorOscuro,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            c,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _subtitulo(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 18, color: tema.colorOscuro),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: tema.colorOscuro,
          ),
        ),
      ],
    );
  }
}
