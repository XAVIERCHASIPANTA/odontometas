import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  final String? nombreGuardado;
  const SplashScreen({super.key, required this.nombreGuardado});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _opacidad;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacidad = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controlador, curve: Curves.easeOut),
    );
    _iniciarSecuencia();
  }

  Future<void> _iniciarSecuencia() async {
    // Se muestra el logo fijo unos segundos antes de empezar a desvanecer.
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) {
      return;
    }
    await _controlador.forward();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => widget.nombreGuardado == null
            ? const OnboardingScreen()
            : const HomeShell(),
      ),
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.rosaOscuro,
      body: AnimatedBuilder(
        animation: _opacidad,
        builder: (context, child) {
          return Opacity(
            opacity: _opacidad.value,
            child: child,
          );
        },
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.rosaOscuro, AppTheme.lavanda],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/images/texto_cursivo.png',
                    width: 260,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
