import 'package:flutter/material.dart';
import '../models/ayuda_temas.dart';
import '../screens/centro_ayuda_screen.dart';
import '../services/ayuda_service.dart';
import 'ayuda_cuerpo.dart';

/// Muestra la ventana flotante de ayuda de un tema.
Future<void> mostrarAyuda(
  BuildContext context,
  String clave, {
  bool primeraVez = false,
}) {
  final tema = temasAyuda[clave];
  if (tema == null) {
    return Future.value();
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar ayuda',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => _DialogoAyuda(tema: tema, primeraVez: primeraVez),
    transitionBuilder: (ctx, animacion, _, hijo) {
      return FadeTransition(
        opacity: animacion,
        child: ScaleTransition(
          scale: animacion
              .drive(CurveTween(curve: Curves.easeOutBack))
              .drive(Tween<double>(begin: 0.85, end: 1)),
          child: hijo,
        ),
      );
    },
  );
}

/// Muestra la guía de un tema SOLO la primera vez que se entra a esa
/// pantalla o pestaña.
Future<void> ayudaPrimeraVez(BuildContext context, String clave) async {
  if (AyudaService.mostrando) {
    return;
  }
  if (await AyudaService.yaVista(clave)) {
    return;
  }
  if (!context.mounted || AyudaService.mostrando) {
    return;
  }
  AyudaService.mostrando = true;
  try {
    await AyudaService.marcarVista(clave);
    if (context.mounted) {
      await mostrarAyuda(context, clave, primeraVez: true);
    }
  } finally {
    AyudaService.mostrando = false;
  }
}

/// Programa la guía de primera vez para cuando la pantalla ya esté dibujada.
void programarAyudaPrimeraVez(State estado, String clave) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (estado.mounted) {
      ayudaPrimeraVez(estado.context, clave);
    }
  });
}

/// Botón "?" para poner en la barra superior.
class BotonAyuda extends StatelessWidget {
  final String tema;
  final Color? color;
  const BotonAyuda({super.key, required this.tema, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda: cómo funciona',
      icon: Icon(Icons.help_outline, color: color ?? Colors.white),
      onPressed: () => mostrarAyuda(context, tema),
    );
  }
}

class _DialogoAyuda extends StatelessWidget {
  final AyudaTema tema;
  final bool primeraVez;
  const _DialogoAyuda({required this.tema, required this.primeraVez});

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: alto * 0.84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tema.color, tema.colorOscuro],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tema.icono, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primeraVez ? 'GUÍA RÁPIDA' : 'AYUDA',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          tema.titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: CuerpoAyuda(tema: tema),
              ),
            ),
            if (primeraVez)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Text(
                  'Esta guía aparece solo esta vez. Siempre puedes volver a verla '
                  'con el botón «?» de arriba.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => CentroAyudaScreen(temaInicial: tema.clave),
                        ),
                      );
                    },
                    icon: Icon(Icons.menu_book_outlined, size: 18, color: tema.colorOscuro),
                    label: Text(
                      'Todas las ayudas',
                      style: TextStyle(color: tema.colorOscuro),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: tema.color),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
