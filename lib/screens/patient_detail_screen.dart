import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../models/meta_goal.dart';
import '../models/paciente.dart';
import '../models/presupuesto.dart';
import '../models/tratamiento.dart';
import '../models/campo_adicional.dart';
import '../services/config_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/whatsapp_service.dart';
import '../services/adjuntos_service.dart';
import '../theme/app_theme.dart';
import '../theme/estilo_metas.dart';
import '../widgets/fondo_decorativo.dart';
import 'periodontograma_list_screen.dart';
import 'evaluacion_riesgo_list_screen.dart';
import 'odontograma_list_screen.dart';
import 'presupuesto_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final MetaGoal meta;
  final int indice;
  const PatientDetailScreen({
    super.key,
    required this.meta,
    required this.indice,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late MetaGoal meta;
  late int indice;
  String _nombreDoctor = 'tu odontóloga';

  Paciente get paciente => meta.pacientes[indice]!;

  @override
  void initState() {
    super.initState();
    meta = widget.meta;
    indice = widget.indice;
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

  /// Respalda de inmediato el estado actual de la meta (y con ella el de
  /// este paciente). Se usa desde el presupuesto para que los pagos queden
  /// guardados en cuanto se registran.
  Future<void> _guardarAhora() async {
    final todas = await StorageService.cargarMetas();
    final idx = todas.indexWhere((m) => m.id == meta.id);
    if (idx >= 0) {
      todas[idx] = meta;
    } else {
      todas.add(meta);
    }
    await StorageService.guardarMetas(todas);
  }

  String _resumenPresupuesto() {
    final p = paciente.presupuesto;
    if (p == null || p.items.isEmpty) {
      return 'Sin presupuesto creado';
    }
    final total = 'Total ${formatoMoneda(p.total)}';
    if (p.total > 0 && p.saldo <= 0.004) {
      return '$total  ·  Pagado por completo';
    }
    if (p.pagosVigentes.isEmpty) {
      return total;
    }
    return '$total  ·  Saldo ${formatoMoneda(p.saldo)}';
  }

  String _formatearFecha(DateTime f) {
    return DateFormat('dd/MM/yyyy HH:mm').format(f);
  }

  // ---------- EDITAR DATOS BÁSICOS ----------

  Future<void> _editarDatosBasicos() async {
    final nombreCtrl = TextEditingController(text: paciente.nombre);
    final cedulaCtrl = TextEditingController(text: paciente.cedula);
    final celularCtrl = TextEditingController(text: paciente.celular);
    DateTime? fechaSeleccionada = paciente.fecha;

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
                    const Text(
                      'Editar datos del paciente',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        hintText: 'ej. 593987654321',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fechaSeleccionada == null
                                ? 'Sin fecha de agendamiento'
                                : _formatearFecha(fechaSeleccionada!),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar'),
                        onPressed: () {
                          final nombre = nombreCtrl.text.trim();
                          if (nombre.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa el nombre del paciente'),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            paciente.nombre = nombre;
                            paciente.cedula = cedulaCtrl.text.trim();
                            paciente.celular = celularCtrl.text.trim();
                            paciente.fecha = fechaSeleccionada;
                          });
                          if (fechaSeleccionada != null) {
                            NotificationService.programarRecordatorios(
                              metaId: meta.id,
                              indice: indice,
                              tituloProcedimiento: meta.titulo,
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
                        },
                      ),
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

  // ---------- SUB-TRATAMIENTOS ----------

  Future<void> _agregarOEditarTratamiento({int? indiceExistente}) async {
    final esNuevo = indiceExistente == null;
    final actual =
        esNuevo ? Tratamiento() : paciente.tratamientos[indiceExistente];
    final tipoCtrl = TextEditingController(text: actual.tipo);
    DateTime? fechaSeleccionada = actual.fecha;

    const sugerencias = [
      'Extracción',
      'Endodoncia',
      'Calza',
      'Restauración',
      'Periodoncia',
      'Limpieza',
      'Blanqueamiento',
    ];

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
                      esNuevo ? 'Nuevo tratamiento adicional' : 'Editar tratamiento',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: sugerencias.map((s) {
                        return ActionChip(
                          label: Text(s),
                          onPressed: () {
                            tipoCtrl.text = s;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tipoCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de tratamiento',
                        hintText: 'ej. Extracción, Calza, Restauración',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fechaSeleccionada == null
                                ? 'Sin fecha'
                                : _formatearFecha(fechaSeleccionada!),
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
                        if (!esNuevo)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar'),
                              onPressed: () {
                                setState(() {
                                  paciente.tratamientos.removeAt(indiceExistente);
                                });
                                NotificationService.cancelarRecordatorioTratamiento(
                                  meta.id,
                                  indice,
                                  indiceExistente,
                                );
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        if (!esNuevo) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Guardar'),
                            onPressed: () {
                              final tipo = tipoCtrl.text.trim();
                              if (tipo.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Ingresa el tipo de tratamiento'),
                                  ),
                                );
                                return;
                              }
                              final tratamiento = Tratamiento(
                                tipo: tipo,
                                fecha: fechaSeleccionada,
                                completado: actual.completado,
                              );
                              setState(() {
                                if (esNuevo) {
                                  paciente.tratamientos.add(tratamiento);
                                } else {
                                  paciente.tratamientos[indiceExistente] =
                                      tratamiento;
                                }
                              });
                              final nuevoIndice = esNuevo
                                  ? paciente.tratamientos.length - 1
                                  : indiceExistente;
                              if (fechaSeleccionada != null) {
                                NotificationService.programarRecordatorioTratamiento(
                                  metaId: meta.id,
                                  indicePaciente: indice,
                                  indiceTratamiento: nuevoIndice,
                                  tipoTratamiento: tipo,
                                  nombrePaciente: paciente.nombre,
                                  fechaHora: fechaSeleccionada!,
                                );
                              }
                              Navigator.pop(ctx);
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

  Future<void> _enviarWhatsAppTratamiento(Tratamiento tratamiento) async {
    if (tratamiento.fecha == null) {
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
      fechaHora: tratamiento.fecha!,
    );
    await WhatsAppService.enviarRecordatorio(
      celular: paciente.celular,
      mensaje: mensaje,
    );
  }

  // ---------- ARCHIVOS ADJUNTOS ----------

  Future<void> _cambiarFoto() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (resultado == null || resultado.files.single.path == null) {
        return;
      }
      final rutaGuardada = await AdjuntosService.guardarArchivo(
        resultado.files.single.path!,
        resultado.files.single.name,
      );
      setState(() {
        paciente.fotoPerfil = rutaGuardada;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la foto: $e')),
      );
    }
  }

  void _quitarFoto() {
    setState(() {
      paciente.fotoPerfil = null;
    });
  }

  // ---------- CAMPOS ADICIONALES (info médica personalizable) ----------

  Future<void> _agregarOEditarCampo({int? indiceExistente}) async {
    final esNuevo = indiceExistente == null;
    final actual =
        esNuevo ? CampoAdicional() : paciente.camposAdicionales[indiceExistente];
    final etiquetaCtrl = TextEditingController(text: actual.etiqueta);
    final valorCtrl = TextEditingController(text: actual.valor);

    const sugerencias = [
      'Condición médica',
      'Alergias',
      'Medicamentos actuales',
      'Enfermedad preexistente',
      'Observaciones',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                  esNuevo ? 'Nuevo campo adicional' : 'Editar campo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: sugerencias.map((s) {
                    return ActionChip(
                      label: Text(s),
                      onPressed: () {
                        etiquetaCtrl.text = s;
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: etiquetaCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del campo',
                    hintText: 'ej. Alergias',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Detalle',
                    hintText: 'ej. Penicilina, ibuprofeno',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (!esNuevo)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar'),
                          onPressed: () {
                            setState(() {
                              paciente.camposAdicionales
                                  .removeAt(indiceExistente);
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    if (!esNuevo) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar'),
                        onPressed: () {
                          final etiqueta = etiquetaCtrl.text.trim();
                          final valor = valorCtrl.text.trim();
                          if (etiqueta.isEmpty || valor.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Completa ambos campos'),
                              ),
                            );
                            return;
                          }
                          final campo =
                              CampoAdicional(etiqueta: etiqueta, valor: valor);
                          setState(() {
                            if (esNuevo) {
                              paciente.camposAdicionales.add(campo);
                            } else {
                              paciente.camposAdicionales[indiceExistente] = campo;
                            }
                          });
                          Navigator.pop(ctx);
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
  }

  Future<void> _agregarAdjunto() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (resultado == null) {
        return;
      }
      for (final archivo in resultado.files) {
        if (archivo.path == null) {
          continue;
        }
        final rutaGuardada = await AdjuntosService.guardarArchivo(
          archivo.path!,
          archivo.name,
        );
        setState(() {
          paciente.adjuntos.add(rutaGuardada);
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo adjuntar el archivo: $e')),
      );
    }
  }

  Future<void> _eliminarAdjunto(String ruta) async {
    setState(() {
      paciente.adjuntos.remove(ruta);
    });
    await AdjuntosService.eliminarArchivo(ruta);
  }

  Future<void> _abrirAdjunto(String ruta) async {
    try {
      await OpenFile.open(ruta);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el archivo: $e')),
      );
    }
  }

  // ---------- INTERFAZ ----------

  @override
  Widget build(BuildContext context) {
    final colorPar = colorParaMeta(meta.id);
    final colorTarjeta = tonoPacientePorIndice(colorPar.fuerte, indice);
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: paciente.nombre,
        colores: [colorPar.fuerte, colorPar.fuerte.withValues(alpha: 0.7)],
        acciones: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar datos',
            onPressed: _editarDatosBasicos,
          ),
        ],
      ),
      body: FondoDecorativo(
        coloresGradiente: [colorPar.claro, Colors.white, colorPar.claro],
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colorTarjeta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _cambiarFoto,
                      onLongPress:
                          paciente.fotoPerfil != null ? _quitarFoto : null,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white.withValues(alpha: 0.28),
                            backgroundImage: paciente.fotoPerfil != null
                                ? FileImage(File(paciente.fotoPerfil!))
                                : null,
                            child: paciente.fotoPerfil == null
                                ? const Icon(Icons.person, size: 44, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: colorTarjeta, width: 2),
                              ),
                              child: Icon(Icons.camera_alt,
                                  size: 14, color: colorTarjeta),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      paciente.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        meta.titulo.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CI: ${paciente.cedula.isEmpty ? "-" : paciente.cedula}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Cel: ${paciente.celular.isEmpty ? "-" : paciente.celular}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      paciente.fecha != null
                          ? 'Cita principal: ${_formatearFecha(paciente.fecha!)}'
                          : 'Sin fecha de cita principal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(Icons.grid_on, color: colorPar.fuerte),
                title: const Text(
                  'Periodontograma',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  paciente.periodontogramas.isEmpty
                      ? 'Sin exámenes registrados'
                      : '${paciente.periodontogramas.length} examen(es) guardado(s)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PeriodontogramaListScreen(paciente: paciente),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(Icons.grid_view, color: colorPar.fuerte),
                title: const Text(
                  'Odontograma',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  paciente.odontogramas.isEmpty
                      ? 'Sin odontogramas registrados'
                      : '${paciente.odontogramas.length} registrado(s)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OdontogramaListScreen(paciente: paciente),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(Icons.attach_money, color: colorPar.fuerte),
                title: const Text(
                  'Presupuesto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_resumenPresupuesto()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PresupuestoScreen(
                        paciente: paciente,
                        onGuardar: _guardarAhora,
                      ),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(Icons.shield_outlined, color: colorPar.fuerte),
                title: const Text(
                  'Evaluación del riesgo periodontal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  paciente.evaluacionesRiesgo.isEmpty
                      ? 'Sin evaluaciones registradas'
                      : '${paciente.evaluacionesRiesgo.length} evaluación(es) guardada(s)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EvaluacionRiesgoListScreen(paciente: paciente),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Información adicional',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                  onPressed: () => _agregarOEditarCampo(),
                ),
              ],
            ),
            if (paciente.camposAdicionales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aquí puedes registrar condiciones médicas, alergias, '
                  'medicamentos, o cualquier dato extra que necesites.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...paciente.camposAdicionales.asMap().entries.map((entry) {
                final i = entry.key;
                final campo = entry.value;
                return Card(
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: colorPar.fuerte),
                    title: Text(
                      campo.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(campo.valor),
                    onTap: () => _agregarOEditarCampo(indiceExistente: i),
                  ),
                );
              }),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tratamientos adicionales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                  onPressed: () => _agregarOEditarTratamiento(),
                ),
              ],
            ),
            if (paciente.tratamientos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aún no hay tratamientos adicionales para este paciente.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...paciente.tratamientos.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                return Card(
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(iconoParaProcedimiento(t.tipo),
                        color: colorPar.fuerte),
                    title: Text(t.tipo),
                    subtitle: Text(
                      t.fecha != null ? _formatearFecha(t.fecha!) : 'Sin fecha',
                    ),
                    onTap: () => _agregarOEditarTratamiento(indiceExistente: i),
                    trailing: t.fecha != null
                        ? IconButton(
                            icon: const Icon(Icons.chat_bubble,
                                color: Colors.green),
                            tooltip: 'Enviar recordatorio por WhatsApp',
                            onPressed: () => _enviarWhatsAppTratamiento(t),
                          )
                        : null,
                  ),
                );
              }),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fotos y archivos adjuntos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Adjuntar'),
                  onPressed: _agregarAdjunto,
                ),
              ],
            ),
            if (paciente.adjuntos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aún no hay archivos adjuntos para este paciente.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: paciente.adjuntos.map((ruta) {
                  final esImagen = AdjuntosService.esImagen(ruta);
                  return GestureDetector(
                    onTap: () => _abrirAdjunto(ruta),
                    onLongPress: () => _eliminarAdjunto(ruta),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorPar.claro,
                        border: Border.all(color: colorPar.fuerte, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: esImagen
                          ? Image.file(File(ruta), fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf,
                                    color: colorPar.fuerte, size: 32),
                                const SizedBox(height: 4),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    AdjuntosService.nombreArchivo(ruta),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            const Text(
              'Toca para abrir, mantén presionado para eliminar.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
