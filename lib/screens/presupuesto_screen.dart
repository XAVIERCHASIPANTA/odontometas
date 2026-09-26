import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/paciente.dart';
import '../models/odontograma.dart';
import '../models/presupuesto.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_decorativo.dart';

class PresupuestoScreen extends StatefulWidget {
  final Paciente paciente;
  const PresupuestoScreen({super.key, required this.paciente});

  @override
  State<PresupuestoScreen> createState() => _PresupuestoScreenState();
}

class _PresupuestoScreenState extends State<PresupuestoScreen> {
  final _uuid = const Uuid();
  late Presupuesto _presupuesto;

  @override
  void initState() {
    super.initState();
    _presupuesto = widget.paciente.presupuesto ?? Presupuesto();
    widget.paciente.presupuesto = _presupuesto;
  }

  Odontograma? get _ultimoOdontograma {
    if (widget.paciente.odontogramas.isEmpty) return null;
    final ordenados = List<Odontograma>.from(widget.paciente.odontogramas)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return ordenados.first;
  }

  void _generarDesdeOdontograma() {
    final odontograma = _ultimoOdontograma;
    if (odontograma == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Este paciente todavía no tiene un odontograma registrado.'),
      ));
      return;
    }
    setState(() {
      _presupuesto.items.removeWhere((i) => i.generadoAutomaticamente);
      for (final diente in odontograma.dientes.values) {
        if (diente.estadoGeneral != null) {
          _presupuesto.items.add(_crearItem(diente.numeroFdi, null, diente.estadoGeneral!));
        } else {
          for (final entry in diente.caras.entries) {
            if (entry.value != EstadoDiente.sano) {
              _presupuesto.items.add(_crearItem(diente.numeroFdi, entry.key, entry.value));
            }
          }
        }
      }
    });
  }

  ItemPresupuesto _crearItem(String piezaFdi, CaraDental? cara, EstadoDiente estado) {
    final estilo = estiloEstadoDiente[estado]!;
    final descripcionCara = cara != null ? ' (${etiquetaCara[cara]})' : '';
    return ItemPresupuesto(
      id: _uuid.v4(),
      piezaFdi: piezaFdi,
      cara: cara,
      estadoOrigen: estado,
      descripcion: 'Pieza $piezaFdi · ${estilo.etiqueta}$descripcionCara',
      precio: _presupuesto.precios[estado] ?? 0,
      generadoAutomaticamente: true,
    );
  }

  Future<void> _agregarManual() async {
    final descripcionCtrl = TextEditingController();
    final piezaCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar tratamiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            TextField(
              controller: piezaCtrl,
              decoration: const InputDecoration(labelText: 'Pieza FDI (opcional)'),
            ),
            TextField(
              controller: precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true || descripcionCtrl.text.trim().isEmpty) return;
    setState(() {
      _presupuesto.items.add(ItemPresupuesto(
        id: _uuid.v4(),
        piezaFdi: piezaCtrl.text.trim().isEmpty ? null : piezaCtrl.text.trim(),
        descripcion: descripcionCtrl.text.trim(),
        precio: double.tryParse(precioCtrl.text.trim()) ?? 0,
      ));
    });
  }

  Future<void> _configurarPrecios() async {
    final controladores = {
      for (final e in preciosPorDefecto.keys)
        e: TextEditingController(text: _presupuesto.precios[e]!.toStringAsFixed(2)),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Precios por tratamiento'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in controladores.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(estiloEstadoDiente[entry.key]!.etiqueta)),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: entry.value,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(prefixText: '\$'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final entry in controladores.entries) {
        _presupuesto.precios[entry.key] =
            double.tryParse(entry.value.text.trim()) ?? _presupuesto.precios[entry.key]!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Presupuesto — ${widget.paciente.nombre}',
        colores: const [AppTheme.rosaPrincipal, AppTheme.lavanda],
        acciones: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar precios',
            onPressed: _configurarPrecios,
          ),
        ],
      ),
      body: FondoDecorativo(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _generarDesdeOdontograma,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Generar desde odontograma'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _agregarManual,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar manual'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_presupuesto.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Todavía no hay tratamientos en el presupuesto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [for (final item in _presupuesto.items) _filaItem(item)],
                  ),
                ),
              const SizedBox(height: 16),
              _resumenTotales(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaItem(ItemPresupuesto item) {
    final color = Color(colorEstadoTratamiento[item.estado]!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: color),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(item.descripcion, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 84,
            child: TextFormField(
              key: ValueKey('${item.id}_${item.precio}'),
              initialValue: item.precio.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                prefixText: '\$',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (v) {
                final valor = double.tryParse(v.trim());
                if (valor != null) setState(() => item.precio = valor);
              },
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<EstadoTratamiento>(
            value: item.estado,
            underline: const SizedBox(),
            items: [
              for (final e in EstadoTratamiento.values)
                DropdownMenuItem(
                  value: e,
                  child: Text(
                    etiquetaEstadoTratamiento[e]!,
                    style: TextStyle(color: Color(colorEstadoTratamiento[e]!), fontSize: 12),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => item.estado = v);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.grey.shade600,
            onPressed: () => setState(() => _presupuesto.items.remove(item)),
          ),
        ],
      ),
    );
  }

  Widget _resumenTotales() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.rosaClaro.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filaTotal('Subtotal', _presupuesto.subtotal),
          Row(
            children: [
              const Text('Descuento (%)'),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _presupuesto.descuentoPorcentaje.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onFieldSubmitted: (v) {
                    setState(() =>
                        _presupuesto.descuentoPorcentaje = double.tryParse(v.trim()) ?? 0);
                  },
                ),
              ),
              const Spacer(),
              Text('-\$${_presupuesto.descuento.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(),
          _filaTotal('Total', _presupuesto.total, destacado: true),
        ],
      ),
    );
  }

  Widget _filaTotal(String label, double valor, {bool destacado = false}) {
    final estilo = TextStyle(
      fontSize: destacado ? 18 : 14,
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: estilo),
          const Spacer(),
          Text('\$${valor.toStringAsFixed(2)}', style: estilo),
        ],
      ),
    );
  }
}
