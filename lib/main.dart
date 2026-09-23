import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/config_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

/// Configuración de Firebase solo para cuando la app corre en un navegador
/// (la versión Android usa su propio archivo google-services.json y no
/// necesita esto).
const FirebaseOptions _opcionesWeb = FirebaseOptions(
  apiKey: "AIzaSyBlLtk46uHOXY9qJ0LNG6T13nbYBcB_iyM",
  authDomain: "odonto-metas-kerly.firebaseapp.com",
  projectId: "odonto-metas-kerly",
  storageBucket: "odonto-metas-kerly.firebasestorage.app",
  messagingSenderId: "344663140142",
  appId: "1:344663140142:web:a0b1a58354cb4fea607cbf",
  measurementId: "G-Y7MZ4J00HN",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: _opcionesWeb);
  } else {
    await Firebase.initializeApp();
  }
  await initializeDateFormatting('es_ES');
  if (!kIsWeb) {
    await NotificationService.inicializar();
  }
  final nombreGuardado = await ConfigService.obtenerNombreDoctor();
  runApp(OdontoMetasApp(nombreGuardado: nombreGuardado));
}

class OdontoMetasApp extends StatelessWidget {
  final String? nombreGuardado;
  const OdontoMetasApp({super.key, this.nombreGuardado});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OdontoMetas Kerly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      locale: const Locale('es', 'EC'),
      supportedLocales: const [
        Locale('es', 'EC'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (!kIsWeb || child == null) {
          return child ?? const SizedBox.shrink();
        }
        // En un navegador la pantalla es mucho más ancha que un celular, así
        // que centramos el contenido en una tarjeta con ancho de teléfono en
        // vez de dejar que la app se estire de borde a borde.
        return Container(
          color: AppTheme.lavanda.withValues(alpha: 0.25),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                elevation: 12,
                shadowColor: Colors.black45,
                child: child,
              ),
            ),
          ),
        );
      },
      home: StreamBuilder<User?>(
        stream: AuthService.cambiosDeSesion,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return _PantallaSincronizando(nombreGuardado: nombreGuardado);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

/// Sincroniza los datos con la nube (una vez, al abrir la app con sesión
/// iniciada) antes de mostrar la pantalla de bienvenida normal.
class _PantallaSincronizando extends StatefulWidget {
  final String? nombreGuardado;
  const _PantallaSincronizando({this.nombreGuardado});

  @override
  State<_PantallaSincronizando> createState() =>
      _PantallaSincronizandoState();
}

class _PantallaSincronizandoState extends State<_PantallaSincronizando> {
  bool _listo = false;
  String? _nombreFinal;

  @override
  void initState() {
    super.initState();
    _nombreFinal = widget.nombreGuardado;
    _sincronizar();
  }

  Future<void> _sincronizar() async {
    final resultados = await Future.wait([
      StorageService.sincronizarAlIniciarSesion(),
      ConfigService.sincronizarNombreAlIniciarSesion(),
    ]);
    final nombreSincronizado = resultados[1] as String?;
    if (mounted) {
      setState(() {
        _nombreFinal = nombreSincronizado;
        _listo = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SplashScreen(nombreGuardado: _nombreFinal);
  }
}
