import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve cualquier widget para darle retroalimentación táctil "de lujo":
/// al tocarlo, vibra y hace un rebote de escala completo (encoge y vuelve a
/// crecer), garantizado siempre — a diferencia de animar solo mientras el
/// dedo está presionado (que en toques muy rápidos puede no alcanzar a
/// dibujarse ni un solo cuadro), aquí la animación se dispara con
/// [AnimationController.forward] al soltar, así que siempre se completa.
class Presionable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// Qué tanto se encoge (0.85 = 15% más chico). Ajustable por si algún
  /// elemento necesita un rebote más sutil o más marcado.
  final double escalaMinima;

  const Presionable({
    super.key,
    required this.child,
    required this.onTap,
    this.escalaMinima = 0.82,
  });

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    // Encoge rápido (primer 35%) y luego rebota de vuelta con overshoot
    // (el resto), para que se sienta elástico y no un simple parpadeo.
    _escala = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: widget.escalaMinima)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.escalaMinima, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
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
    widget.onTap();
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
