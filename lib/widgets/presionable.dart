import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve cualquier widget para darle retroalimentación táctil "de lujo":
/// al tocarlo, vibra e infla el elemento (crece al doble) y luego se
/// encoge de vuelta a su tamaño normal, garantizado siempre.
///
/// La copia que se infla se dibuja en el [Overlay] de la app — es decir,
/// literalmente por ENCIMA de todo lo demás en la pantalla — para que
/// pueda crecer libremente sin que ninguna fila, tarjeta o texto vecino
/// la tape ni la corte. El widget original se oculta mientras dura la
/// animación y vuelve a aparecer al terminar.
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
  OverlayEntry? _overlayEntry;
  bool _ocultandoOriginal = false;

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
    _overlayEntry?.remove();
    _controlador.dispose();
    super.dispose();
  }

  void _alTocar() {
    HapticFeedback.mediumImpact();
    HapticFeedback.vibrate();

    final cajaRender = context.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(context);

    if (cajaRender == null || !cajaRender.attached || overlayState == null) {
      // No hay forma segura de medir la posición o no hay Overlay
      // disponible: seguimos directo a la pantalla de edición, sin
      // animación, para no dejar la app sin reaccionar al toque.
      widget.onTap();
      return;
    }

    final posicion = cajaRender.localToGlobal(Offset.zero);
    final tamano = cajaRender.size;

    late final OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: _escala,
          builder: (context, _) {
            return Positioned(
              left: posicion.dx,
              top: posicion.dy,
              width: tamano.width,
              height: tamano.height,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: _escala.value,
                  child: Material(
                    type: MaterialType.transparency,
                    child: widget.child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    setState(() => _ocultandoOriginal = true);
    _overlayEntry = entrada;
    overlayState.insert(entrada);

    _controlador.forward(from: 0).whenComplete(() {
      entrada.remove();
      _overlayEntry = null;
      if (mounted) setState(() => _ocultandoOriginal = false);
    });

    // Espera a que el rebote termine ANTES de abrir la pantalla de edición
    // — si navegamos de inmediato, la hoja que sube tapa el diente y el
    // rebote nunca se alcanza a ver completo.
    Future.delayed(_duracionTotal, () {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _alTocar,
      child: Opacity(
        opacity: _ocultandoOriginal ? 0 : 1,
        child: widget.child,
      ),
    );
  }
}
