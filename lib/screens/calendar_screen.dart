import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/meta_goal.dart';
import '../services/storage_service.dart';
import '../services/pdf_export_service.dart';
import '../services/whatsapp_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';
import '../theme/estilo_metas.dart';
import '../widgets/fondo_decorativo.dart';

class _CitaInfo {
  final String pacienteNombre;
  final String procedimiento;
  final String celular;
  final String cedula;
  final DateTime fecha;
  final String metaId;

  _CitaInfo({
    required this.pacienteNombre,
    required this.procedimiento,
    required this.celular,
    required this.cedula,
    required this.fecha,
    required this.metaId,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Map<DateTime, List<_CitaInfo>> _eventos = {};
  List<MetaGoal> _metas = [];
  DateTime _diaFocalizado = DateTime.now();
  DateTime? _diaSeleccionado;
  bool _cargando = true;
  String _nombreDoctor = 'tu odontóloga';

  @override
  void initState() {
    super.initState();
    _diaSeleccionado = DateTime.now();
    _cargarCitas();
    _cargarNombreDoctor();
  }

  Future<void> _cargarNombreDoctor() async {
    final nombre = await ConfigService.obtenerNombreDoctor();
    if (!mounted) {
      return;
    }
    if (nombre != null && nombre.trim().isNotEmpty) {
      setState(() {
        _nombreDoctor = nombre;
      });
    }
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _cargarCitas() async {
    final metas = await StorageService.cargarMetas();
    final Map<DateTime, List<_CitaInfo>> mapa = {};
    for (final meta in metas) {
      for (final paciente in meta.pacientes) {
        if (paciente != null && paciente.tieneInfo && paciente.fecha != null) {
          final clave = _soloFecha(paciente.fecha!);
          final cita = _CitaInfo(
            pacienteNombre: paciente.nombre,
            procedimiento: meta.titulo,
            celular: paciente.celular,
            cedula: paciente.cedula,
            fecha: paciente.fecha!,
            metaId: meta.id,
          );
          mapa.putIfAbsent(clave, () => []).add(cita);
        }
      }
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _eventos = mapa;
      _metas = metas;
      _cargando = false;
    });
  }

  List<_CitaInfo> _citasDelDia(DateTime dia) {
    return _eventos[_soloFecha(dia)] ?? [];
  }

  Future<void> _exportarPdf() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando PDF...')),
    );
    await PdfExportService.exportarCalendario(_metas);
  }

  Future<void> _enviarWhatsApp(_CitaInfo cita) async {
    if (!WhatsAppService.celularValido(cita.celular)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este paciente no tiene un celular válido registrado'),
        ),
      );
      return;
    }
    final mensaje = WhatsAppService.construirMensaje(
      nombreDoctor: _nombreDoctor,
      nombrePaciente: cita.pacienteNombre,
      fechaHora: cita.fecha,
    );
    final abrio = await WhatsAppService.enviarRecordatorio(
      celular: cita.celular,
      mensaje: mensaje,
    );
    if (!mounted) {
      return;
    }
    if (!abrio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final citasHoy = _citasDelDia(_diaSeleccionado ?? DateTime.now());
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Calendario de citas',
        colores: const [AppTheme.lavanda, AppTheme.rosaOscuro],
        acciones: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar e imprimir PDF',
            onPressed: _exportarPdf,
          ),
        ],
      ),
      body: FondoDecorativo(
        coloresGradiente: const [
          Color(0xFFEDE7F6),
          Colors.white,
          Color(0xFFFFE4EC),
        ],
        colorMuelitas: AppTheme.lavanda,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TableCalendar<_CitaInfo>(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 730)),
                      focusedDay: _diaFocalizado,
                      locale: 'es_ES',
                      selectedDayPredicate: (day) =>
                          _diaSeleccionado != null &&
                          isSameDay(_diaSeleccionado, day),
                      eventLoader: _citasDelDia,
                      onDaySelected: (seleccionado, enfocado) {
                        setState(() {
                          _diaSeleccionado = seleccionado;
                          _diaFocalizado = enfocado;
                        });
                      },
                      onPageChanged: (enfocado) {
                        _diaFocalizado = enfocado;
                      },
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppTheme.rosaClaro,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppTheme.rosaOscuro,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: AppTheme.mentaFresca,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          _diaSeleccionado != null
                              ? DateFormat('EEEE dd MMMM yyyy', 'es_ES')
                                  .format(_diaSeleccionado!)
                              : '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text('${citasHoy.length} cita(s)'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: citasHoy.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay citas agendadas este día',
                              style: TextStyle(color: Colors.black45),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: citasHoy.length,
                            itemBuilder: (ctx, i) {
                              final cita = citasHoy[i];
                              final colorPar = colorParaMeta(cita.metaId);
                              final icono =
                                  iconoParaProcedimiento(cita.procedimiento);
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: colorPar.claro,
                                    foregroundColor: colorPar.fuerte,
                                    child: Icon(icono),
                                  ),
                                  title: Text(cita.pacienteNombre),
                                  subtitle: Text(
                                    '${cita.procedimiento} • ${DateFormat('HH:mm').format(cita.fecha)}\nCel: ${cita.celular.isEmpty ? "-" : cita.celular}',
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.chat_bubble,
                                        color: Colors.green),
                                    tooltip: 'Enviar recordatorio por WhatsApp',
                                    onPressed: () => _enviarWhatsApp(cita),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
