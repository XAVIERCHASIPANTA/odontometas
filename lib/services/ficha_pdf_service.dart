import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/ficha_clinica.dart';
import '../models/paciente.dart';
import 'pdf_export_service.dart';

/// PDFs de la ficha clínica: historia clínica completa, receta y
/// consentimiento informado (con la firma dibujada en pantalla).
class FichaPdfService {
  static final DateFormat _fecha = DateFormat('dd/MM/yyyy');
  static const PdfColor _rosa = PdfColor.fromInt(0xFFC2185B);
  static const PdfColor _rosaClaro = PdfColor.fromInt(0xFFFFE4EC);
  static const PdfColor _rojo = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _rojoClaro = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor _gris = PdfColor.fromInt(0xFF616161);

  // ---------------------------------------------------------------------
  // Piezas comunes
  // ---------------------------------------------------------------------

  static String _si(bool v) => v ? 'Sí' : 'No';

  static String _nombreArchivo(String prefijo, String paciente) {
    final limpio = paciente
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return limpio.isEmpty ? prefijo : '${prefijo}_$limpio';
  }

  static pw.Widget _encabezado(String titulo, String doctor, {String? subtitulo}) {
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
                if (doctor.trim().isNotEmpty)
                  pw.Text(
                    'Odontólogo/a: ${doctor.trim()}',
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

  static pw.Widget _pie(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado el ${_fecha.format(DateTime.now())} con OdontoMetas Kerly',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
        pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      ],
    );
  }

  static pw.Widget _seccion(String titulo) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(color: _rosaClaro),
      child: pw.Text(
        titulo.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _rosa,
        ),
      ),
    );
  }

  /// Pares "etiqueta: valor" en dos columnas. Se omiten los vacíos.
  static pw.Widget _pares(List<List<String>> pares) {
    final visibles = pares.where((p) => p[1].trim().isNotEmpty).toList();
    if (visibles.isEmpty) {
      return pw.Text('Sin datos registrados.',
          style: const pw.TextStyle(fontSize: 9, color: _gris));
    }
    return pw.Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final p in visibles)
          pw.SizedBox(
            width: 245,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '${p[0]}: ',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _gris,
                    ),
                  ),
                  pw.TextSpan(text: p[1], style: const pw.TextStyle(fontSize: 9.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _texto(String etiqueta, String valor) {
    if (valor.trim().isEmpty) {
      return pw.SizedBox();
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$etiqueta: ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _gris,
              ),
            ),
            pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tabla(
    List<String> headers,
    List<List<String>> data,
    Map<int, pw.TableColumnWidth> anchos,
  ) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      columnWidths: anchos,
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _rosaClaro),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _lineaFirma(String etiqueta, {double ancho = 190}) {
    return pw.Column(
      children: [
        pw.Container(
          width: ancho,
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

  /// Dibuja la firma guardada (trazos) dentro de un recuadro.
  static pw.Widget _firmaDibujada(
    Consentimiento c, {
    double ancho = 190,
    double alto = 70,
  }) {
    final trazos = c.trazos;
    if (trazos.isEmpty || c.firmaAncho <= 0 || c.firmaAlto <= 0) {
      return pw.SizedBox(width: ancho, height: alto);
    }
    final escala = math.min(ancho / c.firmaAncho, alto / c.firmaAlto);
    final ox = (ancho - c.firmaAncho * escala) / 2;
    final oy = (alto - c.firmaAlto * escala) / 2;
    return pw.SizedBox(
      width: ancho,
      height: alto,
      child: pw.CustomPaint(
        size: PdfPoint(ancho, alto),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas
            ..setStrokeColor(const PdfColor.fromInt(0xFF1A237E))
            ..setLineWidth(1.3);
          double px(List<double> p) => ox + p[0] * escala;
          // El eje Y del PDF crece hacia arriba: se invierte.
          double py(List<double> p) => alto - (oy + p[1] * escala);
          for (final t in trazos) {
            canvas.moveTo(px(t.first), py(t.first));
            if (t.length == 1) {
              canvas.lineTo(px(t.first) + 0.2, py(t.first));
            }
            for (var i = 1; i < t.length; i++) {
              canvas.lineTo(px(t[i]), py(t[i]));
            }
            canvas.strokePath();
          }
        },
      ),
    );
  }

  static pw.Widget _bloquePaciente(Paciente paciente) {
    final f = paciente.ficha;
    final edad = f?.edad;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _rosaClaro,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            paciente.nombre.isEmpty ? 'Paciente sin nombre' : paciente.nombre,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _pares([
            ['Cédula', paciente.cedula],
            ['Celular', paciente.celular],
            ['Edad', edad == null ? '' : '$edad años'],
            ['Nacimiento',
              f?.fechaNacimiento == null ? '' : _fecha.format(f!.fechaNacimiento!)],
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Historia clínica completa
  // ---------------------------------------------------------------------

  static Future<void> imprimirFicha({
    required Paciente paciente,
    required String nombreDoctor,
  }) async {
    final f = paciente.ficha ?? FichaClinica();
    final pdf = pw.Document();
    final evoluciones = f.evolucionesOrdenadas.reversed.toList(); // cronológico
    final alergias = f.alergiasOrdenadas;
    final condiciones = [
      for (final c in catalogoCondiciones)
        if (f.condiciones.contains(c.clave)) c.etiqueta,
    ];

    pdf.addPage(
      pw.MultiPage(
        pageTheme: PdfExportService.temaMarcaAgua(),
        header: (ctx) => _encabezado(
          'Historia clínica',
          nombreDoctor,
          subtitulo: 'Fecha: ${_fecha.format(DateTime.now())}',
        ),
        footer: _pie,
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _bloquePaciente(paciente),
          if (f.tieneAlertas) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _rojoClaro,
                border: pw.Border.all(color: _rojo, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ALERTAS MÉDICAS',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _rojo,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  for (final a in alergias)
                    pw.Text(
                      'Alergia (${etiquetaSeveridad[a.severidad]!.toLowerCase()}): '
                      '${a.descripcion}'
                      '${a.reaccion.isEmpty ? '' : ' - ${a.reaccion}'}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  if (f.condicionesDeAlerta.isNotEmpty)
                    pw.Text(
                      'Condiciones: ${f.condicionesDeAlerta.join(', ')}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  if (f.condicionesOtras.trim().isNotEmpty)
                    pw.Text(
                      'Otras: ${f.condicionesOtras.trim()}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                ],
              ),
            ),
          ],
          _seccion('Datos personales'),
          _pares([
            ['Sexo', f.sexo == null ? '' : etiquetaSexo[f.sexo]!],
            ['Ocupación', f.ocupacion],
            ['Dirección', f.direccion],
            ['Correo', f.correo],
            ['Referido por', f.referidoPor],
            ['Emergencia',
              [f.contactoNombre, f.contactoParentesco, f.contactoTelefono]
                  .where((e) => e.trim().isNotEmpty)
                  .join(' - ')],
          ]),
          _seccion('Motivo de consulta'),
          if (f.motivoConsulta.trim().isEmpty && f.enfermedadActual.trim().isEmpty)
            pw.Text('Sin datos registrados.',
                style: const pw.TextStyle(fontSize: 9, color: _gris))
          else ...[
            _texto('Motivo', f.motivoConsulta),
            _texto('Enfermedad actual', f.enfermedadActual),
          ],
          _seccion('Historia médica'),
          _pares([
            ['Grupo sanguíneo', f.grupoSanguineo],
            ['Condiciones', condiciones.join(', ')],
            ['Otras', f.condicionesOtras],
          ]),
          _texto('Cirugías / hospitalizaciones', f.cirugias),
          _texto('Antecedentes familiares', f.antecedentesFamiliares),
          _texto('Observaciones médicas', f.observacionesMedicas),
          if (f.medicamentos.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _tabla(
              const ['Medicación actual', 'Dosis', 'Motivo'],
              [
                for (final m in f.medicamentos) [m.nombre, m.dosis, m.motivo],
              ],
              {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
              },
            ),
          ],
          if (alergias.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _tabla(
              const ['Alergia', 'Tipo', 'Reacción', 'Gravedad'],
              [
                for (final a in alergias)
                  [
                    a.descripcion,
                    etiquetaTipoAlergia[a.tipo]!,
                    a.reaccion,
                    etiquetaSeveridad[a.severidad]!,
                  ],
              ],
              {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
          ],
          if (f.historiaActualizada != null)
            _texto('Historia médica revisada el',
                _fecha.format(f.historiaActualizada!)),
          _seccion('Hábitos y salud bucal'),
          _pares([
            ['Fuma', etiquetaNivelHabito[f.tabaco]!],
            ['Alcohol', etiquetaNivelHabito[f.alcohol]!],
            ['Bruxismo', _si(f.bruxismo)],
            ['Cepillados al día', f.cepilladosDia == 0 ? '' : '${f.cepilladosDia}'],
            ['Hilo dental', _si(f.usaHilo)],
            ['Enjuague bucal', _si(f.usaEnjuague)],
            ['Sangrado de encías', _si(f.sangradoEncias)],
            ['Sensibilidad', _si(f.sensibilidad)],
            ['Ortodoncia previa', _si(f.ortodonciaPrevia)],
            ['Ansiedad dental',
              f.ansiedadDental == 0 ? '' : '${f.ansiedadDental} de 5'],
            ['Última visita', f.ultimaVisita],
          ]),
          _texto('Experiencias previas', f.experienciasPrevias),
          _seccion('Evolución clínica (${evoluciones.length})'),
          if (evoluciones.isEmpty)
            pw.Text('Aún no hay evoluciones registradas.',
                style: const pw.TextStyle(fontSize: 9, color: _gris))
          else
            _tabla(
              const ['Fecha', 'Procedimiento', 'Piezas', 'Anestesia', 'Notas e indicaciones'],
              [
                for (final e in evoluciones)
                  [
                    _fecha.format(e.fecha),
                    e.procedimiento,
                    e.piezas,
                    e.anestesia,
                    [
                      if (e.presionArterial.isNotEmpty) 'PA ${e.presionArterial}',
                      if (e.materiales.isNotEmpty) 'Materiales: ${e.materiales}',
                      if (e.observaciones.isNotEmpty) e.observaciones,
                      if (e.indicaciones.isNotEmpty) 'Indicaciones: ${e.indicaciones}',
                      if (e.proximaCita != null)
                        'Próxima cita: ${_fecha.format(e.proximaCita!)}',
                    ].join('\n'),
                  ],
              ],
              {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(5),
              },
            ),
          if (f.recetas.isNotEmpty) ...[
            _seccion('Recetas emitidas (${f.recetas.length})'),
            _tabla(
              const ['N°', 'Fecha', 'Medicamentos'],
              [
                for (final r in f.recetas.reversed)
                  [
                    r.numeroTexto,
                    _fecha.format(r.fecha),
                    r.items.map((i) => i.nombre).join(', '),
                  ],
              ],
              {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(6),
              },
            ),
          ],
          if (f.consentimientos.isNotEmpty) ...[
            _seccion('Consentimientos informados (${f.consentimientos.length})'),
            _tabla(
              const ['Fecha', 'Documento', 'Firmante', 'Estado'],
              [
                for (final c in f.consentimientos.reversed)
                  [
                    _fecha.format(c.fecha),
                    c.titulo,
                    c.nombreFirmante,
                    c.firmado
                        ? 'Firmado ${_fecha.format(c.firmadoEn!)}'
                        : 'Pendiente de firma',
                  ],
              ],
              {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2.5),
              },
            ),
          ],
          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _lineaFirma('Firma del paciente'),
              _lineaFirma('Firma del profesional'),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: _nombreArchivo('Historia_clinica', paciente.nombre),
      onLayout: (format) async => pdf.save(),
    );
  }

  // ---------------------------------------------------------------------
  // Receta
  // ---------------------------------------------------------------------

  static Future<void> imprimirReceta({
    required Paciente paciente,
    required Receta receta,
    required String nombreDoctor,
  }) async {
    final f = paciente.ficha;
    final alergias = f?.alergiasOrdenadas ?? const <Alergia>[];
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageTheme: PdfExportService.temaMarcaAgua(),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _encabezado(
              'Receta N° ${receta.numeroTexto}',
              nombreDoctor,
              subtitulo: 'Fecha: ${_fecha.format(receta.fecha)}',
            ),
            pw.SizedBox(height: 10),
            _bloquePaciente(paciente),
            if (alergias.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: _rojoClaro,
                  border: pw.Border.all(color: _rojo, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Alergias: ${alergias.map((a) => a.descripcion).join(', ')}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _rojo,
                  ),
                ),
              ),
            ],
            if (receta.diagnostico.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _texto('Diagnóstico', receta.diagnostico),
            ],
            pw.SizedBox(height: 14),
            pw.Text(
              'Rp/',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _rosa,
              ),
            ),
            pw.SizedBox(height: 6),
            for (var i = 0; i < receta.items.length; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.only(left: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: _rosa, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${i + 1}. ${receta.items[i].nombre}'
                      '${receta.items[i].presentacion.isEmpty ? '' : '  -  ${receta.items[i].presentacion}'}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      receta.items[i].posologia,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    if (receta.items[i].duracion.isNotEmpty ||
                        receta.items[i].cantidad.isNotEmpty)
                      pw.Text(
                        [
                          if (receta.items[i].duracion.isNotEmpty)
                            'Duración: ${receta.items[i].duracion}',
                          if (receta.items[i].cantidad.isNotEmpty)
                            'Cantidad: ${receta.items[i].cantidad}',
                        ].join('     '),
                        style: const pw.TextStyle(fontSize: 10, color: _gris),
                      ),
                  ],
                ),
              ),
            if (receta.indicaciones.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Indicaciones',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(receta.indicaciones.trim(),
                  style: const pw.TextStyle(fontSize: 10.5)),
            ],
            pw.Spacer(),
            pw.Center(child: _lineaFirma('Firma y sello del profesional', ancho: 220)),
            pw.SizedBox(height: 10),
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
      name: _nombreArchivo('Receta_${receta.numeroTexto}', paciente.nombre),
      onLayout: (format) async => pdf.save(),
    );
  }

  // ---------------------------------------------------------------------
  // Consentimiento informado
  // ---------------------------------------------------------------------

  static Future<void> imprimirConsentimiento({
    required Paciente paciente,
    required Consentimiento consentimiento,
    required String nombreDoctor,
  }) async {
    final c = consentimiento;
    final parrafos = c.texto
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: PdfExportService.temaMarcaAgua(),
        header: (ctx) => _encabezado(
          'Consentimiento informado',
          nombreDoctor,
          subtitulo: 'Fecha: ${_fecha.format(c.firmadoEn ?? c.fecha)}',
        ),
        footer: _pie,
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _bloquePaciente(paciente),
          pw.SizedBox(height: 14),
          pw.Text(
            c.titulo.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _rosa,
            ),
          ),
          pw.SizedBox(height: 10),
          for (final p in parrafos)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                p,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
              ),
            ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            alignment: pw.WrapAlignment.spaceAround,
            runSpacing: 16,
            children: [
              pw.Column(
                children: [
                  _firmaDibujada(c),
                  _lineaFirma(
                    c.esRepresentante
                        ? 'Representante legal'
                        : 'Firma del paciente',
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    c.nombreFirmante.isEmpty ? paciente.nombre : c.nombreFirmante,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  if (c.cedulaFirmante.isNotEmpty)
                    pw.Text('C.I. ${c.cedulaFirmante}',
                        style: const pw.TextStyle(fontSize: 9)),
                  if (c.esRepresentante && c.parentesco.isNotEmpty)
                    pw.Text('Parentesco: ${c.parentesco}',
                        style: const pw.TextStyle(fontSize: 9)),
                  if (!c.firmado)
                    pw.Text(
                      'Pendiente de firma',
                      style: const pw.TextStyle(fontSize: 8, color: _gris),
                    ),
                ],
              ),
              pw.Column(
                children: [
                  pw.SizedBox(height: 70),
                  _lineaFirma('Firma del profesional'),
                  if (nombreDoctor.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(
                        nombreDoctor.trim(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (c.firmado)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'Firmado digitalmente en pantalla el ${_fecha.format(c.firmadoEn!)}.',
                style: const pw.TextStyle(fontSize: 8, color: _gris),
              ),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: _nombreArchivo('Consentimiento', paciente.nombre),
      onLayout: (format) async => pdf.save(),
    );
  }
}
