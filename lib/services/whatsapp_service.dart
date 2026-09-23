import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static const List<String> _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _formatearFechaLarga(DateTime f) {
    final hh = f.hour.toString().padLeft(2, '0');
    final min = f.minute.toString().padLeft(2, '0');
    return '${f.day} de ${_meses[f.month - 1]} de ${f.year} a las $hh:$min';
  }

  static String construirMensaje({
    required String nombreDoctor,
    required String nombrePaciente,
    required DateTime fechaHora,
  }) {
    final fecha = _formatearFechaLarga(fechaHora);
    return 'Hola qué tal, soy $nombreDoctor, su médico odontólogo. '
        'Le recuerdo que tiene una cita programada para el día $fecha, '
        'por lo que cuento con su valiosa presencia y así pueda lucir '
        'sus hermosas perlas. ¡Le esperamos, $nombrePaciente!';
  }

  static String construirMensajeBienvenida({
    required String nombreDoctor,
    required String nombrePaciente,
    required DateTime fechaHora,
  }) {
    final fecha = _formatearFechaLarga(fechaHora);
    return 'Hola qué tal, soy la Dra./Dr. $nombreDoctor, voy a ser su '
        'médico odontólogo/a. Gracias por preferirme, $nombrePaciente. '
        'Le agendo su cita para el día $fecha. ¡Nos vemos pronto!';
  }

  static String _soloDigitos(String celular) {
    return celular.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool celularValido(String celular) {
    return _soloDigitos(celular).length >= 7;
  }

  static Future<bool> enviarRecordatorio({
    required String celular,
    required String mensaje,
  }) async {
    final digits = _soloDigitos(celular);
    if (digits.isEmpty) {
      return false;
    }
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(mensaje)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
