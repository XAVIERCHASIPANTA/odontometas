import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/evaluacion_riesgo.dart';
import '../models/paciente.dart';
import '../theme/app_theme.dart';
import 'evaluacion_riesgo_form_screen.dart';

class EvaluacionRiesgoListScreen extends StatefulWidget {
  final Paciente paciente;
  const EvaluacionRiesgoListScreen({super.key, required this.paciente});

  @override
  State<EvaluacionRiesgoListScreen> createState() =>
      _EvaluacionRiesgoListScreenState();
}

class _EvaluacionRiesgoListScreenState
    extends State<EvaluacionRiesgoListScreen> {
  Color _colorRiesgo(RiesgoPeriodontal r) {
    switch (r) {
      case RiesgoPeriodontal.bajo:
        return Colors.green.shade600;
      case RiesgoPeriodontal.moderado:
        return Colors.orange.shade700;
      case RiesgoPeriodontal.alto:
        return Colors.red.shade700;
    }
  }

  Future<void> _nuevaEvaluacion() async {
    final nueva = EvaluacionRiesgo(
      id: const Uuid().v4(),
      fecha: DateTime.now(),
      esReevaluacion: widget.paciente.evaluacionesRiesgo.isNotEmpty,
    );
    setState(() => widget.paciente.evaluacionesRiesgo.add(nueva));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluacionRiesgoFormScreen(
          evaluacion: nueva,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _abrirEvaluacion(EvaluacionRiesgo ev) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluacionRiesgoFormScreen(
          evaluacion: ev,
          nombrePaciente: widget.paciente.nombre,
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final evaluaciones = [...widget.paciente.evaluacionesRiesgo]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Riesgo periodontal',
        colores: const [AppTheme.lavanda, AppTheme.rosaOscuro],
      ),
      body: SafeArea(
        child: evaluaciones.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aún no hay evaluaciones de riesgo periodontal para '
                    'este paciente. Toca el botón + para crear la primera.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: evaluaciones.length,
                itemBuilder: (context, i) {
                  final ev = evaluaciones[i];
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorRiesgo(ev.riesgoGlobal),
                        child: const Icon(Icons.shield_outlined, color: Colors.white),
                      ),
                      title: Text(DateFormat('dd/MM/yyyy').format(ev.fecha)),
                      subtitle: Text(
                        '${ev.esReevaluacion ? "Reevaluación" : "Examen inicial"} · '
                        'Riesgo ${ev.riesgoGlobal.etiqueta}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrirEvaluacion(ev),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaEvaluacion,
        icon: const Icon(Icons.add),
        label: const Text('Nueva evaluación'),
      ),
    );
  }
}
