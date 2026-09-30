import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/pago.dart';
import '../models/presupuesto.dart';
import 'caja_service.dart';
import 'pdf_export_service.dart';

/// Reporte imprimible / compartible de los cobros de un período.
class CajaPdfService {
  static const PdfColor _rosa = PdfColor.fromInt(0xFFC2185B);
  static const PdfColor _rosaClaro = PdfColor.fromInt(0xFFFFE4EC);
  static const PdfColor _gris = PdfColor.fromInt(0xFF616161);

  static String fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<void> imprimirReporte({
    required String tituloPeriodo,
    required RangoFechas rango,
    required ResumenCaja resumen,
    required String nombreDoctor,
  }) async {
    final pdf = pw.Document();
    final dias = resumen.porDia.keys.toList()..sort();

    pw.Widget tabla(List<String> headers, List<List<String>> data,
        Map<int, pw.Alignment> alineacion, Map<int, pw.TableColumnWidth> anchos) {
      return pw.Table.fromTextArray(
        headers: headers,
        data: data,
        columnWidths: anchos,
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: _rosaClaro),
        cellAlignments: alineacion,
      );
    }

    pw.Widget titulo(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
          child: pw.Text(
            t,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: PdfExportService.temaMarcaAgua(),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OdontoMetas Kerly',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _rosa,
                      ),
                    ),
                    if (nombreDoctor.trim().isNotEmpty)
                      pw.Text(
                        'Odontólogo/a: ${nombreDoctor.trim()}',
                        style: const pw.TextStyle(fontSize: 10, color: _gris),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Reporte de cobros',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      tituloPeriodo,
                      style: const pw.TextStyle(fontSize: 10, color: _gris),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: _rosa, thickness: 1.2),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado el ${fmtFecha(DateTime.now())} con OdontoMetas Kerly',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
            pw.Text(
              'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _gris),
            ),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _rosaClaro,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _cifra('TOTAL COBRADO', formatoMoneda(resumen.total), grande: true),
                _cifra('PAGOS', '${resumen.cantidad}'),
                _cifra('PROMEDIO POR PAGO', formatoMoneda(resumen.promedioPorPago)),
              ],
            ),
          ),
          titulo('Por forma de pago'),
          if (resumen.porMetodo.isEmpty)
            pw.Text('No hay cobros en este período.')
          else
            tabla(
              const ['Forma de pago', 'Monto', '%'],
              [
                for (final m in MetodoPago.values)
                  if ((resumen.porMetodo[m] ?? 0) > 0)
                    [
                      etiquetaMetodoPago[m]!,
                      formatoMoneda(resumen.porMetodo[m]!),
                      '${(resumen.porMetodo[m]! / resumen.total * 100).toStringAsFixed(1)}%',
                    ],
              ],
              {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
              },
            ),
          if (dias.length > 1) ...[
            titulo('Cobrado por día'),
            tabla(
              const ['Fecha', 'Monto'],
              [
                for (final d in dias) [fmtFecha(d), formatoMoneda(resumen.porDia[d]!)],
              ],
              {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
              {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(2)},
            ),
          ],
          if (resumen.movimientos.isNotEmpty) ...[
            titulo('Detalle de pagos'),
            tabla(
              const ['Fecha', 'Recibo', 'Paciente', 'Forma de pago', 'Monto'],
              [
                for (final m in resumen.movimientos)
                  [
                    fmtFecha(m.pago.fecha),
                    m.pago.numeroTexto,
                    m.paciente.nombre,
                    etiquetaMetodoPago[m.pago.metodo]!,
                    formatoMoneda(m.pago.monto),
                  ],
              ],
              {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              {
                0: const pw.FlexColumnWidth(1.6),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(4),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.6),
              },
            ),
          ],
          if (resumen.anulados.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Pagos anulados en el período (no incluidos en el total): '
              '${resumen.anulados.length} por ${formatoMoneda(resumen.anuladosMonto)}.',
              style: const pw.TextStyle(fontSize: 9, color: _gris),
            ),
          ],
        ],
      ),
    );

    final sufijo = tituloPeriodo
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    await Printing.layoutPdf(
      name: 'Cobros_$sufijo',
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _cifra(String etiqueta, String valor, {bool grande = false}) {
    return pw.Column(
      children: [
        pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: _gris)),
        pw.SizedBox(height: 3),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: grande ? 20 : 14,
            fontWeight: pw.FontWeight.bold,
            color: grande ? _rosa : PdfColors.black,
          ),
        ),
      ],
    );
  }
}
