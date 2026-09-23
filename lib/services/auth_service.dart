import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Maneja el inicio y cierre de sesión con Google, conectado a Firebase Auth.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// El "Client ID" web de OAuth (del mismo proyecto de Firebase) — solo
  /// hace falta cuando la app corre en un navegador; en Android/iOS no se
  /// usa (ahí basta con el archivo de configuración nativo).
  static const String _clientIdWeb =
      '344663140142-7akla93u4kqk04ggvpurs592c6iv0pdg.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb ? _clientIdWeb : null,
  );

  /// Emite el usuario actual cada vez que cambia el estado de sesión
  /// (inicia sesión, cierra sesión, o se restaura una sesión guardada).
  static Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  static User? get usuarioActual => _auth.currentUser;

  /// Devuelve el usuario si el inicio de sesión fue exitoso, o null si el
  /// usuario canceló el diálogo de selección de cuenta.
  static Future<User?> iniciarSesionConGoogle() async {
    if (kIsWeb) {
      // En la web usamos el método propio de Firebase: abre el popup de
      // Google y hace todo el intercambio de tokens internamente, sin
      // depender de la API de personas (que en un navegador puede fallar
      // con error 403 y bloquear el inicio de sesión).
      final proveedorGoogle = GoogleAuthProvider();
      final userCredential = await _auth.signInWithPopup(proveedorGoogle);
      return userCredential.user;
    }
    final GoogleSignInAccount? cuentaGoogle = await _googleSignIn.signIn();
    if (cuentaGoogle == null) {
      return null;
    }
    final GoogleSignInAuthentication authGoogle =
        await cuentaGoogle.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authGoogle.accessToken,
      idToken: authGoogle.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  static Future<void> cerrarSesion() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
