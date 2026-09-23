import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AdjuntosService {
  static Future<String> guardarArchivo(
    String rutaOrigen,
    String nombreOriginal,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final carpeta = Directory('${dir.path}/adjuntos');
    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }
    final nombreSeguro = nombreOriginal.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final nombreUnico =
        '${DateTime.now().millisecondsSinceEpoch}_$nombreSeguro';
    final destino = File('${carpeta.path}/$nombreUnico');
    await File(rutaOrigen).copy(destino.path);
    return destino.path;
  }

  static Future<void> eliminarArchivo(String ruta) async {
    try {
      final archivo = File(ruta);
      if (await archivo.exists()) {
        await archivo.delete();
      }
    } catch (_) {
      // Si ya no existe o no se puede borrar, se ignora silenciosamente.
    }
  }

  static bool esImagen(String ruta) {
    final r = ruta.toLowerCase();
    return r.endsWith('.jpg') ||
        r.endsWith('.jpeg') ||
        r.endsWith('.png') ||
        r.endsWith('.webp');
  }

  static String nombreArchivo(String ruta) {
    final partes = ruta.split(Platform.pathSeparator);
    final nombreConTimestamp = partes.isEmpty ? ruta : partes.last;
    // Quita el prefijo de milisegundos que se agrega para hacerlo único.
    final idx = nombreConTimestamp.indexOf('_');
    if (idx > 0 && idx < nombreConTimestamp.length - 1) {
      return nombreConTimestamp.substring(idx + 1);
    }
    return nombreConTimestamp;
  }
}
