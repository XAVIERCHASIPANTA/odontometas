import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/pago.dart';
import '../models/paciente.dart';
import '../models/presupuesto.dart';
import 'pdf_export_service.dart';

/// Documentos imprimibles / compartibles del módulo de presupuesto:
///  - Presupuesto del paciente (con historial de pagos y saldo).
///  - Recibo de pago individual (con el monto en letras).
class PresupuestoPdfService {
  static final DateFormat _fecha = DateFormat('dd/MM/yyyy');
  static const PdfColor _rosa = PdfColor.fromInt(0xFFC2185B);
  static const PdfColor _rosaClaro = PdfColor.fromInt(0xFFFFE4EC);
  static const PdfColor _gris = PdfColor.fromInt(0xFF616161);
  static const PdfColor _rojo = PdfColor.fromInt(0xFFC62828);

  // ---------------------------------------------------------------------
  // Monto en letras (para el recibo)
  // ---------------------------------------------------------------------

  static const List<String> _unidades = [
    'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho',
    'nueve', 'diez', 'once', 'doce', 'trece', 'catorce', 'quince',
    'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve', 'veinte',
    'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco',
    'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve',
  ];
  static const List<String> _decenas = [
    '', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta',
    'ochenta', 'noventa',
  ];
  static const List<String> _centenas = [
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos',
    'seiscientos', 'setecientos', 'ochocientos', 'novecientos',
  ];

  static String _menorDeMil(int n) {
    if (n == 100) {
      return 'cien';
    }
    final c = n ~/ 100;
    final r = n % 100;
    final partes = <String>[];
    if (c > 0) {
      partes.add(_centenas[c]);
    }
    if (r > 0) {
      if (r < 30) {
        partes.add(_unidades[r]);
      } else {
        final d = r ~/ 10;
        final u = r % 10;
        partes.add(u == 0 ? _decenas[d] : '${_decenas[d]} y ${_unidades[u]}');
      }
    }
    return partes.join(' ');
  }

  /// "uno" -> "un", "veintiuno" -> "veintiún" cuando va antes de "mil" o
  /// "millones".
  static String _apocopado(int n) {
    final s = _menorDeMil(n);
    if (s.endsWith('veintiuno')) {
      return '${s.substring(0, s.length - 'veintiuno'.length)}veintiún';
    }
    if (s.endsWith('uno')) {
      return '${s.substring(0, s.length - 3)}un';
    }
    return s;
  }

  static String _enteroALetras(int n) {
    if (n == 0) {
      return 'cero';
    }
    final millones = n ~/ 1000000;
    final miles = (n % 1000000) ~/ 1000;
    final resto = n % 1000;
    final partes = <String>[];
    if (millones > 0) {
      partes.add(millones == 1 ? 'un millón' : '${_apocopado(millones)} millones');
    }
    if (miles > 0) {
      partes.add(miles == 1 ? 'mil' : '${_apocopado(miles)} mil');
    }
    if (resto > 0) {
      partes.add(_menorDeMil(resto));
    }
    return partes.join(' ');
  }

  /// 120.5 -> "Ciento veinte con 50/100 dólares".
  static String montoEnLetras(double monto) {
    final centavosTotales = (monto * 100).round();
    final entero = centavosTotales ~/ 100;
    final centavos = centavosTotales % 100;
    final letras = _enteroALetras(entero);
    final moneda = entero == 1 ? 'dólar' : 'dólares';
    final texto = '$letras con ${centavos.toString().padLeft(2, '0')}/100 $moneda';
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
  }

  // ---------------------------------------------------------------------
  // Piezas comunes
  // ---------------------------------------------------------------------

  static pw.Widget _encabezado(
    String titulo,
    String nombreDoctor, {
    String? subtitulo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                  titulo,
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                ),
                if (subtitulo != null)
                  pw.Text(
                    subtitulo,
                    style: const pw.TextStyle(fontSize: 10, color: _gris),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _rosa, thickness: 1.2),
      ],
    );
  }

  static pw.Widget _dato(String etiqueta, String valor) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: _gris)),
          pw.SizedBox(height: 2),
          pw.Text(
            valor.isEmpty ? '-' : valor,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _bloquePaciente(Paciente paciente, List<pw.Widget> extras) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _rosaClaro,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Paciente', style: const pw.TextStyle(fontSize: 8, color: _gris)),
                pw.SizedBox(height: 2),
                pw.Text(
                  paciente.nombre,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          _dato('Cédula', paciente.cedula),
          _dato('Celular', paciente.celular),
          ...extras,
        ],
      ),
    );
  }

  static pw.Widget _filaTotal(
    String etiqueta,
    String valor, {
    bool fuerte = false,
    PdfColor? color,
  }) {
    final estilo = pw.TextStyle(
      fontSize: fuerte ? 12 : 10,
      fontWeight: fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(etiqueta, style: estilo), pw.Text(valor, style: estilo)],
      ),
    );
  }

  static pw.Widget _firma(String etiqueta) {
    return pw.Column(
      children: [
        pw.Container(
          width: 170,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.8)),
          ),
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            etiqueta,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  static pw.Widget _pie(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado con OdontoMetas Kerly',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
        pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      ],
    );
  }

  static String _nombreArchivo(String prefijo, String nombrePaciente) {
    final limpio = nombrePaciente
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return limpio.isEmpty ? prefijo : '${prefijo}_$limpio';
  }

  // ---------------------------------------------------------------------
  // Presupuesto
  // ---------------------------------------------------------------------

  static Future<void> imprimirPresupuesto({
    required Paciente paciente,
    required String nombreDoctor,
    bool incluirPagos = true,
  }) async {
    final p = paciente.presupuesto ?? Presupuesto();
    final pdf = pw.Document();
    final items = p.itemsActivos.toList();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: PdfExportService.temaMarcaAgua(),
        header: (ctx) => _encabezado(
          'Presupuesto odontológico',
          nombreDoctor,
          subtitulo: 'Fecha: ${_fecha.format(DateTime.now())}',
        ),
        footer: _pie,
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _bloquePaciente(paciente, [
            _dato('Emitido', _fecha.format(p.fechaCreacion)),
            _dato(
              'Válido hasta',
              p.validoHasta == null ? 'Sin límite' : _fecha.format(p.validoHasta!),
            ),
          ]),
          pw.SizedBox(height: 12),
          pw.Text(
            'Plan de tratamiento',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (items.isEmpty)
            pw.Text('Todavía no hay tratamientos en el presupuesto.')
          else
            pw.Table.fromTextArray(
              headers: const [
                'Pieza',
                'Tratamiento',
                'Cant.',
                'P. unit.',
                'Total',
                'Estado',
              ],
              data: [
                for (final it in items)
                  [
                    it.piezaFdi ?? '-',
                    it.notas.isEmpty
                        ? it.descripcion
                        : '${it.descripcion}\n${it.notas}',
                    '${it.cantidad}',
                    formatoMoneda(it.precio),
                    formatoMoneda(it.total),
                    etiquetaEstadoTratamiento[it.estado]!,
                  ],
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.6),
                5: const pw.FlexColumnWidth(1.8),
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: _rosaClaro),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
              },
            ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _rosa, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _filaTotal('Subtotal', formatoMoneda(p.subtotal)),
                  if (p.descuentoPorcentaje > 0)
                    _filaTotal(
                      'Descuento (${p.descuentoPorcentaje.toStringAsFixed(p.descuentoPorcentaje == p.descuentoPorcentaje.roundToDouble() ? 0 : 1)}%)',
                      '-${formatoMoneda(p.descuento)}',
                    ),
                  pw.Divider(height: 8),
                  _filaTotal('TOTAL', formatoMoneda(p.total), fuerte: true),
                  if (incluirPagos && p.pagosVigentes.isNotEmpty) ...[
                    _filaTotal('Pagado', formatoMoneda(p.totalPagado)),
                    _filaTotal(
                      p.saldo < -0.004 ? 'Saldo a favor' : 'SALDO PENDIENTE',
                      formatoMoneda(p.saldo.abs()),
                      fuerte: true,
                      color: p.saldo > 0.004 ? _rojo : _rosa,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (incluirPagos && p.pagos.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Historial de pagos',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: const ['Recibo', 'Fecha', 'Forma de pago', 'Referencia', 'Monto'],
              data: [
                for (final pago in p.pagos)
                  [
                    pago.numeroTexto,
                    _fecha.format(pago.fecha),
                    etiquetaMetodoPago[pago.metodo]!,
                    pago.anulado
                        ? 'ANULADO${pago.motivoAnulacion.isEmpty ? '' : ' - ${pago.motivoAnulacion}'}'
                        : (pago.referencia.isEmpty ? '-' : pago.referencia),
                    pago.anulado ? '(${formatoMoneda(pago.monto)})' : formatoMoneda(pago.monto),
                  ],
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(3.4),
                4: const pw.FlexColumnWidth(1.6),
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: _rosaClaro),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
            ),
          ],
          if (p.notas.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Notas y condiciones',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(p.notas.trim(), style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.SizedBox(height: 44),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [_firma('Firma del paciente'), _firma('Firma del profesional')],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: _nombreArchivo('Presupuesto', paciente.nombre),
      onLayout: (format) async => pdf.save(),
    );
  }

  // ---------------------------------------------------------------------
  // Recibo de pago
  // ---------------------------------------------------------------------

  static Future<void> imprimirRecibo({
    required Paciente paciente,
    required Pago pago,
    required String nombreDoctor,
  }) async {
    final p = paciente.presupuesto ?? Presupuesto();
    final pagadoHastaAqui = p.pagadoHastaRecibo(pago.numero);
    final saldoTrasPago = redondear2(p.total - pagadoHastaAqui);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageTheme: PdfExportService.temaMarcaAgua(),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _encabezado(
              'Recibo de pago N° ${pago.numeroTexto}',
              nombreDoctor,
              subtitulo: 'Fecha: ${_fecha.format(pago.fecha)}',
            ),
            pw.SizedBox(height: 14),
            if (pago.anulado)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _rojo, width: 1.2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'RECIBO ANULADO'
                  '${pago.fechaAnulacion == null ? '' : ' el ${_fecha.format(pago.fechaAnulacion!)}'}'
                  '${pago.motivoAnulacion.isEmpty ? '' : ' - ${pago.motivoAnulacion}'}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _rojo,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            _bloquePaciente(paciente, const []),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _rosa, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('VALOR RECIBIDO', style: const pw.TextStyle(fontSize: 9, color: _gris)),
                      pw.Text(
                        formatoMoneda(pago.monto),
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pago.anulado ? _gris : _rosa,
                          decoration: pago.anulado ? pw.TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Son: ${montoEnLetras(pago.monto)}',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: _rosaClaro),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Por concepto de: abono a tratamiento odontológico'
                    '${pago.nota.isEmpty ? '' : ' (${pago.nota})'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Forma de pago: ${etiquetaMetodoPago[pago.metodo]!}'
                    '${pago.referencia.isEmpty ? '' : '  -  Ref.: ${pago.referencia}'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _rosaClaro,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _filaTotal('Total del presupuesto', formatoMoneda(p.total)),
                    _filaTotal('Pagado a la fecha de este recibo', formatoMoneda(pagadoHastaAqui)),
                    pw.Divider(height: 8),
                    _filaTotal(
                      saldoTrasPago < -0.004 ? 'Saldo a favor' : 'Saldo pendiente',
                      formatoMoneda(saldoTrasPago.abs()),
                      fuerte: true,
                      color: saldoTrasPago > 0.004 ? _rojo : _rosa,
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 60),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [_firma('Recibí conforme (paciente)'), _firma('Firma del profesional')],
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'Generado con OdontoMetas Kerly',
                style: const pw.TextStyle(fontSize: 8, color: _gris),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      name: _nombreArchivo('Recibo_${pago.numeroTexto}', paciente.nombre),
      onLayout: (format) async => pdf.save(),
    );
  }
}
