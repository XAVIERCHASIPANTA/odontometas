import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/paciente.dart';
import '../models/periodontograma.dart';
import '../theme/app_theme.dart';
import 'periodontograma_form_screen.dart';

class PeriodontogramaListScreen extends StatefulWidget {
  final Paciente paciente;
  const PeriodontogramaListScreen({super.key, required this.paciente});

  @override
  State<PeriodontogramaListScreen> createState() =>
      _PeriodontogramaListScreenState();
}

class _PeriodontogramaListScreenState
    extends State<PeriodontogramaListScreen> {
  final _uuid = const Uuid();

  Future<void> _nuevoExamen() async {
    final examen = Periodontograma(id: _uuid.v4(), fecha: DateTime.now());
    setState(() {
      widget.paciente.periodontogramas.add(examen);
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodontogramaFormScreen(
          examen: examen,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _abrirExamen(Periodontograma examen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodontogramaFormScreen(
          examen: examen,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  void _eliminarExamen(Periodontograma examen) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar examen'),
        content: Text(
          '¿Eliminar el periodontograma del ${DateFormat('dd/MM/yyyy').format(examen.fecha)}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                widget.paciente.periodontogramas.remove(examen);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final examenes = List<Periodontograma>.from(widget.paciente.periodontogramas)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Periodontograma — ${widget.paciente.nombre}',
        colores: const [AppTheme.lavanda, AppTheme.rosaOscuro],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoExamen,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo examen'),
      ),
      body: examenes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay exámenes periodontales registrados.\n'
                  'Toca "Nuevo examen" para crear el primero (línea base) '
                  'y poder comparar el avance del paciente más adelante.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: examenes.length,
              itemBuilder: (ctx, i) {
                final examen = examenes[i];
                final esElMasReciente = i == 0;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    onTap: () => _abrirExamen(examen),
                    onLongPress: () => _eliminarExamen(examen),
                    leading: CircleAvatar(
                      backgroundColor: esElMasReciente
                          ? AppTheme.mentaFresca
                          : AppTheme.rosaClaro,
                      foregroundColor:
                          esElMasReciente ? Colors.white : AppTheme.rosaOscuro,
                      child: const Icon(Icons.grid_on, size: 18),
                    ),
                    title: Text(
                      DateFormat('dd/MM/yyyy').format(examen.fecha),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Sangrado: ${examen.porcentajeSangrado.toStringAsFixed(0)}%  •  '
                      'Placa: ${examen.porcentajePlaca.toStringAsFixed(0)}%  •  '
                      'Bolsas ≥4mm: ${examen.totalDientesConBolsaModerada + examen.totalDientesConBolsaSevera}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}
