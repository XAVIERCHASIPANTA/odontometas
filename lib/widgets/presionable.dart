import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve cualquier widget para darle retroalimentación táctil "de lujo":
/// al tocarlo, vibra e infla el elemento (crece al doble) y luego se
/// encoge de vuelta a su tamaño normal, garantizado siempre — a diferencia
/// de animar solo mientras el dedo está presionado (que en toques muy
/// rápidos puede no alcanzar a dibujarse ni un solo cuadro), aquí la
/// animación se dispara con [AnimationController.forward] al soltar, así
/// que siempre se completa.
///
/// IMPORTANTE: este widget crece "en su lugar" (no usa Overlay ni
/// coordenadas globales), así que es idéntico en Android, iOS y Web. Para
/// que el crecimiento no quede tapado por filas vecinas, quien use este
/// widget debe dejarle un margen vertical/horizontal de sobra alrededor
/// (ver el uso en las pantallas de odontograma/periodontograma).
class Presionable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// Qué tanto se infla (2.0 = el doble de grande) antes de volver a
  /// encogerse a su tamaño normal.
  final double escalaMaxima;

  const Presionable({
    super.key,
    required this.child,
    required this.onTap,
    this.escalaMaxima = 2.0,
  });

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _escala;

  static const Duration _duracionTotal = Duration(milliseconds: 780);

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: _duracionTotal,
    );
    // Se infla (primer 45%) y luego se encoge de vuelta a su tamaño normal
    // con un rebote elástico al final (el resto), para que se sienta vivo
    // y no un simple parpadeo.
    _escala = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: widget.escalaMaxima)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.escalaMaxima, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_controlador);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alTocar() {
    // Se dispara SIEMPRE al levantar el dedo, sin importar qué tan rápido
    // fue el toque — por eso la animación no se pierde en toques rápidos.
    HapticFeedback.mediumImpact();
    HapticFeedback.vibrate();
    _controlador.forward(from: 0);
    // Espera a que el rebote sea bien visible ANTES de abrir la pantalla de
    // edición — si navegamos de inmediato, la hoja que sube tapa el diente
    // y el rebote nunca se alcanza a ver.
    Future.delayed(_duracionTotal, () {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _alTocar,
      child: AnimatedBuilder(
        animation: _escala,
        builder: (context, child) => Transform.scale(scale: _escala.value, child: child),
        child: widget.child,
      ),
    );
  }
}
