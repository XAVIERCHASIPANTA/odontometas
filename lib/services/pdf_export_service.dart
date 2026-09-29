import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/meta_goal.dart';

class PdfExportService {
  /// Dibuja una muelita estilizada simplificada usando las primitivas de
  /// dibujo del paquete pdf (no es una imagen ni una fuente/emoji), para
  /// poder usarla como marca de agua/sello de autoría en los PDF generados.
  static pw.Widget _muelaPdf(double tamano) {
    return pw.CustomPaint(
      size: PdfPoint(tamano, tamano),
      painter: (canvas, size) {
        final w = size.x;
        final h = size.y;
        canvas
          ..setFillColor(PdfColor.fromInt(0xFF000000))
          ..moveTo(w * 0.5, h * 0.06)
          ..curveTo(w * 0.82, h * 0.04, w * 0.94, h * 0.32, w * 0.84, h * 0.54)
          ..curveTo(w * 0.90, h * 0.74, w * 0.78, h * 0.94, w * 0.64, h * 0.90)
          ..curveTo(w * 0.60, h * 0.76, w * 0.55, h * 0.74, w * 0.5, h * 0.84)
          ..curveTo(w * 0.45, h * 0.74, w * 0.40, h * 0.76, w * 0.36, h * 0.90)
          ..curveTo(w * 0.22, h * 0.94, w * 0.10, h * 0.74, w * 0.16, h * 0.54)
          ..curveTo(w * 0.06, h * 0.32, w * 0.18, h * 0.04, w * 0.5, h * 0.06)
          ..closePath()
          ..fillPath();
      },
    );
  }

  /// Patrón de marca de agua repetido a lo largo de toda la página: la
  /// muelita + la letra "K", como sello de autoría del programa.
  static pw.Widget _fondoMarcaAgua() {
    return pw.Opacity(
      opacity: 0.07,
      child: pw.Wrap(
        spacing: 26,
        runSpacing: 32,
        children: List.generate(54, (i) {
          return pw.Transform.rotate(
            angle: i.isEven ? -0.2 : 0.2,
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _muelaPdf(16),
                pw.SizedBox(width: 3),
                pw.Text(
                  'K',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static pw.PageTheme _temaConMarcaAgua() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: _fondoMarcaAgua(),
      ),
    );
  }

  /// Tema de página con la marca de agua de la app, para que otros PDF
  /// (presupuesto, recibos) mantengan el mismo sello de autoría.
  static pw.PageTheme temaMarcaAgua() => _temaConMarcaAgua();

  static Future<void> exportarCalendario(List<MetaGoal> metas) async {
    final pdf = pw.Document();
    final List<Map<String, dynamic>> citas = [];

    for (final meta in metas) {
      for (final paciente in meta.pacientes) {
        if (paciente != null && paciente.tieneInfo && paciente.fecha != null) {
          citas.add({
            'nombre': paciente.nombre,
            'cedula': paciente.cedula,
            'celular': paciente.celular,
            'procedimiento': meta.titulo,
            'fecha': paciente.fecha!,
          });
        }
      }
    }
    citas.sort(
      (a, b) => (a['fecha'] as DateTime).compareTo(b['fecha'] as DateTime),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: _temaConMarcaAgua(),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'OdontoMetas Kerly — Calendario de citas',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          citas.isEmpty
              ? pw.Text('No hay citas agendadas todavía.')
              : pw.Table.fromTextArray(
                  headers: const [
                    'Fecha',
                    'Hora',
                    'Paciente',
                    'Cédula',
                    'Celular',
                    'Procedimiento',
                  ],
                  data: citas.map((c) {
                    final f = c['fecha'] as DateTime;
                    final fechaTxto =
                        '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
                    final horaTxto =
                        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
                    return [
                      fechaTxto,
                      horaTxto,
                      c['nombre'] as String,
                      (c['cedula'] as String).isEmpty
                          ? '-'
                          : c['cedula'] as String,
                      (c['celular'] as String).isEmpty
                          ? '-'
                          : c['celular'] as String,
                      c['procedimiento'] as String,
                    ];
                  }).toList(),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerStyle:
                      pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFE4EC)),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}