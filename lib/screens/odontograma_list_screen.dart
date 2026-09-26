import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/paciente.dart';
import '../models/odontograma.dart';
import '../theme/app_theme.dart';
import 'odontograma_form_screen.dart';

class OdontogramaListScreen extends StatefulWidget {
  final Paciente paciente;
  const OdontogramaListScreen({super.key, required this.paciente});

  @override
  State<OdontogramaListScreen> createState() => _OdontogramaListScreenState();
}

class _OdontogramaListScreenState extends State<OdontogramaListScreen> {
  final _uuid = const Uuid();

  Future<void> _nuevoExamen() async {
    final examen = Odontograma(id: _uuid.v4(), fecha: DateTime.now());
    setState(() {
      widget.paciente.odontogramas.add(examen);
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OdontogramaFormScreen(
          examen: examen,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _abrirExamen(Odontograma examen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OdontogramaFormScreen(
          examen: examen,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  void _eliminarExamen(Odontograma examen) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar odontograma'),
        content: Text(
          '¿Eliminar el odontograma del ${DateFormat('dd/MM/yyyy').format(examen.fecha)}? '
          'Esta acción no se puede deshacer.',
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
                widget.paciente.odontogramas.remove(examen);
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
    final examenes = List<Odontograma>.from(widget.paciente.odontogramas)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Odontograma — ${widget.paciente.nombre}',
        colores: const [AppTheme.mentaFresca, AppTheme.rosaOscuro],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoExamen,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo odontograma'),
      ),
      body: examenes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no hay odontogramas registrados.\n'
                  'Toca "Nuevo odontograma" para crear el primero.',
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
                final hallazgos = examen.resumenPorEstado()
                    .values
                    .fold<int>(0, (sum, v) => sum + v);
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => _abrirExamen(examen),
                    onLongPress: () => _eliminarExamen(examen),
                    leading: CircleAvatar(
                      backgroundColor:
                          esElMasReciente ? AppTheme.mentaFresca : AppTheme.rosaClaro,
                      foregroundColor:
                          esElMasReciente ? Colors.white : AppTheme.rosaOscuro,
                      child: const Icon(Icons.grid_view, size: 18),
                    ),
                    title: Text(
                      DateFormat('dd/MM/yyyy').format(examen.fecha),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$hallazgos hallazgo(s) registrado(s)'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}
