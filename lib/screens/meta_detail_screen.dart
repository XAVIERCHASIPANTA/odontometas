import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meta_goal.dart';
import '../models/paciente.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/whatsapp_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';
import '../theme/estilo_metas.dart';
import '../widgets/fondo_decorativo.dart';
import 'patient_detail_screen.dart';

class MetaDetailScreen extends StatefulWidget {
  final MetaGoal meta;
  const MetaDetailScreen({super.key, required this.meta});

  @override
  State<MetaDetailScreen> createState() => _MetaDetailScreenState();
}

class _MetaDetailScreenState extends State<MetaDetailScreen> {
  late MetaGoal meta;
  String _nombreDoctor = 'tu odontóloga';

  @override
  void initState() {
    super.initState();
    meta = widget.meta;
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

  Future<void> _guardarTodo() async {
    final todas = await StorageService.cargarMetas();
    final idx = todas.indexWhere((m) => m.id == meta.id);
    if (idx >= 0) {
      todas[idx] = meta;
    } else {
      todas.add(meta);
    }
    await StorageService.guardarMetas(todas);
  }

  void _editarTamanoMeta() {
    final ctrl = TextEditingController(text: meta.metaNumero.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar número de meta'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nueva meta objetivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevo = int.tryParse(ctrl.text.trim());
              if (nuevo == null || nuevo <= 0) {
                return;
              }
              setState(() {
                meta.ajustarTamano(nuevo);
              });
              _guardarTodo();
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarWhatsApp(Paciente paciente) async {
    if (paciente.fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este paciente no tiene fecha de cita agendada'),
        ),
      );
      return;
    }
    if (!WhatsAppService.celularValido(paciente.celular)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un número de celular válido para este paciente'),
        ),
      );
      return;
    }
    final mensaje = WhatsAppService.construirMensaje(
      nombreDoctor: _nombreDoctor,
      nombrePaciente: paciente.nombre,
      fechaHora: paciente.fecha!,
    );
    final abrio = await WhatsAppService.enviarRecordatorio(
      celular: paciente.celular,
      mensaje: mensaje,
    );
    if (!mounted) {
      return;
    }
    if (!abrio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp en este dispositivo'),
        ),
      );
    }
  }

  Future<void> _programarConAviso({
    required int indice,
    required String nombrePaciente,
    required DateTime fechaHora,
  }) async {
    try {
      await NotificationService.programarRecordatorios(
        metaId: meta.id,
        indice: indice,
        tituloProcedimiento: meta.titulo,
        nombrePaciente: nombrePaciente,
        fechaHora: fechaHora,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo programar el recordatorio: $e'),
        ),
      );
    }
  }

  void _ofrecerMensajeBienvenida(Paciente paciente, DateTime fechaHora) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mensaje de bienvenida'),
        content: Text(
          '¿Deseas enviarle a ${paciente.nombre} un mensaje de bienvenida '
          'por WhatsApp confirmando su cita?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, gracias'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text('Enviar'),
            onPressed: () async {
              Navigator.pop(ctx);
              final mensaje = WhatsAppService.construirMensajeBienvenida(
                nombreDoctor: _nombreDoctor,
                nombrePaciente: paciente.nombre,
                fechaHora: fechaHora,
              );
              final abrio = await WhatsAppService.enviarRecordatorio(
                celular: paciente.celular,
                mensaje: mensaje,
              );
              if (!mounted) {
                return;
              }
              if (!abrio) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo abrir WhatsApp en este dispositivo'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDetallePaciente(int indice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(meta: meta, indice: indice),
      ),
    );
    _guardarTodo();
    setState(() {});
  }

  Future<void> _editarPaciente(int indice) async {
    final actual = meta.pacientes[indice] ?? Paciente();
    final nombreCtrl = TextEditingController(text: actual.nombre);
    final cedulaCtrl = TextEditingController(text: actual.cedula);
    final celularCtrl = TextEditingController(text: actual.celular);
    DateTime? fechaSeleccionada = actual.fecha;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meta.titulo} — Paciente #${indice + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Nombre del paciente'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cedulaCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Número de cédula'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: celularCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Número de celular (con código de país)',
                        hintText: 'ej. +593987654321',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fechaSeleccionada == null
                                ? 'Sin fecha de agendamiento'
                                : DateFormat('dd/MM/yyyy  HH:mm')
                                    .format(fechaSeleccionada!),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Elegir fecha'),
                          onPressed: () async {
                            final fecha = await showDatePicker(
                              context: ctx,
                              initialDate: fechaSeleccionada ?? DateTime.now(),
                              firstDate:
                                  DateTime.now().subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (fecha == null) {
                              return;
                            }
                            if (!ctx.mounted) {
                              return;
                            }
                            final hora = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                fechaSeleccionada ?? DateTime.now(),
                              ),
                            );
                            if (hora == null) {
                              return;
                            }
                            setModalState(() {
                              fechaSeleccionada = DateTime(
                                fecha.year,
                                fecha.month,
                                fecha.day,
                                hora.hour,
                                hora.minute,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (actual.tieneInfo)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Vaciar'),
                              onPressed: () {
                                setState(() {
                                  meta.pacientes[indice] = null;
                                });
                                NotificationService.cancelarRecordatorios(
                                  meta.id,
                                  indice,
                                );
                                _guardarTodo();
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        if (actual.tieneInfo) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Guardar'),
                            onPressed: () {
                              final nombre = nombreCtrl.text.trim();
                              if (nombre.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Ingresa el nombre del paciente'),
                                  ),
                                );
                                return;
                              }
                              final paciente = Paciente(
                                nombre: nombre,
                                cedula: cedulaCtrl.text.trim(),
                                celular: celularCtrl.text.trim(),
                                fecha: fechaSeleccionada,
                                completado: true,
                              );
                              setState(() {
                                meta.pacientes[indice] = paciente;
                              });
                              _guardarTodo();
                              if (fechaSeleccionada != null) {
                                _programarConAviso(
                                  indice: indice,
                                  nombrePaciente: paciente.nombre,
                                  fechaHora: fechaSeleccionada!,
                                );
                              } else {
                                NotificationService.cancelarRecordatorios(
                                  meta.id,
                                  indice,
                                );
                              }
                              Navigator.pop(ctx);
                              if (fechaSeleccionada != null &&
                                  WhatsAppService.celularValido(
                                      paciente.celular)) {
                                _ofrecerMensajeBienvenida(
                                  paciente,
                                  fechaSeleccionada!,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorPar = colorParaMeta(meta.id);
    final icono = iconoParaProcedimiento(meta.titulo);
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: meta.titulo,
        colores: [colorPar.fuerte, colorPar.fuerte.withValues(alpha: 0.7)],
        acciones: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Editar número de meta',
            onPressed: _editarTamanoMeta,
          ),
        ],
      ),
      body: FondoDecorativo(
        coloresGradiente: [colorPar.claro, fondoMetaMenta, colorPar.claro],
        colorMuelitas: colorPar.fuerte,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: meta.progreso,
                      minHeight: 10,
                      backgroundColor: colorPar.claro,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colorPar.fuerte),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${meta.completados} / ${meta.metaNumero} completados'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: meta.metaNumero,
                itemBuilder: (ctx, i) {
                  final paciente =
                      meta.pacientes.length > i ? meta.pacientes[i] : null;
                  final lleno = paciente != null && paciente.tieneInfo;
                  final colorTarjeta = lleno
                      ? tonoPacientePorIndice(colorPar.fuerte, i)
                      : colorPar.claro;
                  final colorTexto = lleno ? Colors.white : Colors.black87;
                  final colorTextoSecundario =
                      lleno ? Colors.white.withValues(alpha: 0.85) : Colors.black54;
                  return Card(
                    color: colorTarjeta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      onTap: () => lleno
                          ? _abrirDetallePaciente(i)
                          : _editarPaciente(i),
                      leading: SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: lleno
                                  ? Colors.white.withValues(alpha: 0.28)
                                  : Colors.white,
                              foregroundColor:
                                  lleno ? Colors.white : colorPar.fuerte,
                              child: Text('${i + 1}'),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    Icon(icono, size: 13, color: colorPar.fuerte),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        lleno ? paciente.nombre : 'Sin asignar',
                        style: TextStyle(
                          fontWeight: lleno ? FontWeight.w600 : FontWeight.normal,
                          color: colorTexto,
                        ),
                      ),
                      subtitle: lleno
                          ? Text(
                              'CI: ${paciente.cedula.isEmpty ? "-" : paciente.cedula}  •  Cel: ${paciente.celular.isEmpty ? "-" : paciente.celular}'
                              '${paciente.fecha != null ? "\n${DateFormat('dd/MM/yyyy HH:mm').format(paciente.fecha!)}" : ""}',
                              style: TextStyle(color: colorTextoSecundario),
                            )
                          : Text('Toca para registrar datos del paciente',
                              style: TextStyle(color: colorTextoSecundario)),
                      isThreeLine: lleno && paciente.fecha != null,
                      trailing: lleno && paciente.fecha != null
                          ? IconButton(
                              icon: const Icon(Icons.chat_bubble,
                                  color: Colors.white),
                              tooltip: 'Enviar recordatorio por WhatsApp',
                              onPressed: () => _enviarWhatsApp(paciente),
                            )
                          : Icon(Icons.chevron_right, color: colorTexto),
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
