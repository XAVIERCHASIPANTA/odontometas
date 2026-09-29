import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/odontograma.dart';
import '../models/pago.dart';
import '../models/presupuesto.dart';
import '../theme/app_theme.dart';

/// Convierte "25", "25.5" o "25,50" en número. Devuelve null si no es válido.
double? parsearMonto(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) {
    return null;
  }
  return double.tryParse(limpio);
}

final List<TextInputFormatter> _soloNumeros = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

final DateFormat _fechaCorta = DateFormat('dd/MM/yyyy');

/// Contenedor común de todas las hojas inferiores: respeta el teclado y la
/// barra de navegación del sistema y permite desplazarse si no cabe.
class _MarcoHoja extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  const _MarcoHoja({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icono, color: AppTheme.rosaOscuro),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TRATAMIENTO (agregar / editar)
// ---------------------------------------------------------------------------

class ResultadoItem {
  final ItemPresupuesto? item;
  final bool eliminar;
  const ResultadoItem.guardar(ItemPresupuesto this.item) : eliminar = false;
  const ResultadoItem.eliminar()
      : item = null,
        eliminar = true;
}

Future<ResultadoItem?> mostrarHojaItem(
  BuildContext context, {
  ItemPresupuesto? existente,
}) {
  return showModalBottomSheet<ResultadoItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaItem(existente: existente),
  );
}

class _HojaItem extends StatefulWidget {
  final ItemPresupuesto? existente;
  const _HojaItem({this.existente});

  @override
  State<_HojaItem> createState() => _HojaItemState();
}

class _HojaItemState extends State<_HojaItem> {
  late final TextEditingController _descripcion;
  late final TextEditingController _pieza;
  late final TextEditingController _precio;
  late final TextEditingController _notas;
  late int _cantidad;
  late EstadoTratamiento _estado;
  String? _error;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final it = widget.existente;
    _descripcion = TextEditingController(text: it?.descripcion ?? '');
    _pieza = TextEditingController(text: it?.piezaFdi ?? '');
    _precio = TextEditingController(
      text: it == null ? '' : it.precio.toStringAsFixed(2),
    );
    _notas = TextEditingController(text: it?.notas ?? '');
    _cantidad = it?.cantidad ?? 1;
    _estado = it?.estado ?? EstadoTratamiento.pendiente;
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _pieza.dispose();
    _precio.dispose();
    _notas.dispose();
    super.dispose();
  }

  double get _totalLinea => redondear2((parsearMonto(_precio.text) ?? 0) * _cantidad);

  void _aplicarPrestacion(PrestacionCatalogo p) {
    setState(() {
      _descripcion.text = p.nombre;
      _precio.text = p.precio.toStringAsFixed(2);
      _error = null;
    });
  }

  void _guardar() {
    final descripcion = _descripcion.text.trim();
    final precio = parsearMonto(_precio.text);
    if (descripcion.isEmpty) {
      setState(() => _error = 'Escribe qué tratamiento es.');
      return;
    }
    if (precio == null || precio < 0) {
      setState(() => _error = 'Ingresa un precio válido (por ejemplo 25 o 25.50).');
      return;
    }
    final pieza = _pieza.text.trim();
    final base = widget.existente;
    final item = base ??
        ItemPresupuesto(
          id: const Uuid().v4(),
          descripcion: descripcion,
          precio: precio,
        );
    item.descripcion = descripcion;
    item.precio = redondear2(precio);
    item.cantidad = _cantidad;
    item.piezaFdi = pieza.isEmpty ? null : pieza;
    item.notas = _notas.text.trim();
    item.cambiarEstado(_estado);
    Navigator.pop(context, ResultadoItem.guardar(item));
  }

  @override
  Widget build(BuildContext context) {
    return _MarcoHoja(
      titulo: _editando ? 'Editar tratamiento' : 'Agregar tratamiento',
      icono: Icons.medical_services_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_editando) ...[
            const Text(
              'Tratamientos frecuentes (toca uno para llenarlo)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final p in catalogoPrestaciones)
                  ActionChip(
                    label: Text(p.nombre, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _aplicarPrestacion(p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _descripcion,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Tratamiento'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pieza,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pieza FDI',
                    hintText: 'opcional',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _soloNumeros,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario',
                    prefixText: '\$ ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_cantidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _cantidad < 99 ? () => setState(() => _cantidad++) : null,
                icon: const Icon(Icons.add),
              ),
              const Spacer(),
              Text(
                'Total ${formatoMoneda(_totalLinea)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_editando) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<EstadoTratamiento>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                for (final e in EstadoTratamiento.values)
                  DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(colorEstadoTratamiento[e]!),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(etiquetaEstadoTratamiento[e]!),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _estado = v);
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notas,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_editando)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, const ResultadoItem.eliminar()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.check),
                label: Text(_editando ? 'Guardar cambios' : 'Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAGO
// ---------------------------------------------------------------------------

Future<Pago?> mostrarHojaPago(
  BuildContext context, {
  required double saldo,
  required int numeroRecibo,
}) {
  return showModalBottomSheet<Pago>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaPago(saldo: saldo, numeroRecibo: numeroRecibo),
  );
}

const Map<MetodoPago, IconData> iconoMetodoPago = {
  MetodoPago.efectivo: Icons.payments_outlined,
  MetodoPago.transferencia: Icons.account_balance_outlined,
  MetodoPago.tarjeta: Icons.credit_card,
  MetodoPago.cheque: Icons.receipt_long_outlined,
  MetodoPago.otro: Icons.more_horiz,
};

class _HojaPago extends StatefulWidget {
  final double saldo;
  final int numeroRecibo;
  const _HojaPago({required this.saldo, required this.numeroRecibo});

  @override
  State<_HojaPago> createState() => _HojaPagoState();
}

class _HojaPagoState extends State<_HojaPago> {
  late final TextEditingController _monto;
  final TextEditingController _referencia = TextEditingController();
  final TextEditingController _nota = TextEditingController();
  DateTime _fecha = DateTime.now();
  MetodoPago _metodo = MetodoPago.efectivo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _monto = TextEditingController(
      text: widget.saldo > 0 ? widget.saldo.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _monto.dispose();
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (elegida != null) {
      setState(() => _fecha = elegida);
    }
  }

  void _guardar() {
    final monto = parsearMonto(_monto.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto mayor que cero.');
      return;
    }
    final ahora = DateTime.now();
    // La fecha elegida conserva la hora actual para ordenar bien varios
    // pagos del mismo día.
    final fecha = DateTime(
      _fecha.year,
      _fecha.month,
      _fecha.day,
      ahora.hour,
      ahora.minute,
    );
    Navigator.pop(
      context,
      Pago(
        id: const Uuid().v4(),
        numero: widget.numeroRecibo,
        fecha: fecha,
        monto: redondear2(monto),
        metodo: _metodo,
        referencia: _referencia.text.trim(),
        nota: _nota.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = widget.saldo;
    return _MarcoHoja(
      titulo: 'Registrar pago  ·  Recibo N° ${widget.numeroRecibo.toString().padLeft(4, '0')}',
      icono: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.rosaClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('Saldo pendiente'),
                const Spacer(),
                Text(
                  formatoMoneda(saldo > 0 ? saldo : 0),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _monto,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _soloNumeros,
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Monto recibido',
              prefixText: '\$ ',
            ),
          ),
          if (saldo > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text('Saldo completo (${formatoMoneda(saldo)})'),
                  onPressed: () => setState(() {
                    _monto.text = saldo.toStringAsFixed(2);
                    _error = null;
                  }),
                ),
                ActionChip(
                  label: const Text('Mitad del saldo'),
                  onPressed: () => setState(() {
                    _monto.text = redondear2(saldo / 2).toStringAsFixed(2);
                    _error = null;
                  }),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('Forma de pago', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in MetodoPago.values)
                ChoiceChip(
                  avatar: Icon(iconoMetodoPago[m], size: 18),
                  label: Text(etiquetaMetodoPago[m]!),
                  selected: _metodo == m,
                  onSelected: (_) => setState(() => _metodo = m),
                ),
            ],
          ),
          if (_metodo != MetodoPago.efectivo) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _referencia,
              decoration: const InputDecoration(
                labelText: 'N° de comprobante / referencia (opcional)',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fecha del pago: ${_fechaCorta.format(_fecha)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Cambiar'),
              ),
            ],
          ),
          TextField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check),
            label: const Text('Registrar pago'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AJUSTES DEL PRESUPUESTO (descuento, vigencia, notas)
// ---------------------------------------------------------------------------

class AjustesPresupuesto {
  final double descuentoPorcentaje;
  final DateTime? validoHasta;
  final String notas;
  const AjustesPresupuesto({
    required this.descuentoPorcentaje,
    required this.validoHasta,
    required this.notas,
  });
}

Future<AjustesPresupuesto?> mostrarHojaAjustes(
  BuildContext context, {
  required Presupuesto presupuesto,
}) {
  return showModalBottomSheet<AjustesPresupuesto>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaAjustes(presupuesto: presupuesto),
  );
}

class _HojaAjustes extends StatefulWidget {
  final Presupuesto presupuesto;
  const _HojaAjustes({required this.presupuesto});

  @override
  State<_HojaAjustes> createState() => _HojaAjustesState();
}

class _HojaAjustesState extends State<_HojaAjustes> {
  late final TextEditingController _descuento;
  late final TextEditingController _notas;
  DateTime? _validoHasta;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.presupuesto;
    final d = p.descuentoPorcentaje;
    _descuento = TextEditingController(
      text: d == 0 ? '' : (d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString()),
    );
    _notas = TextEditingController(text: p.notas);
    _validoHasta = p.validoHasta;
  }

  @override
  void dispose() {
    _descuento.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegirVigencia() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _validoHasta ?? hoy.add(const Duration(days: 30)),
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365 * 3)),
    );
    if (elegida != null) {
      setState(() => _validoHasta = elegida);
    }
  }

  void _guardar() {
    final texto = _descuento.text.trim();
    final descuento = texto.isEmpty ? 0.0 : parsearMonto(texto);
    if (descuento == null || descuento < 0 || descuento > 100) {
      setState(() => _error = 'El descuento debe estar entre 0 y 100 %.');
      return;
    }
    Navigator.pop(
      context,
      AjustesPresupuesto(
        descuentoPorcentaje: descuento,
        validoHasta: _validoHasta,
        notas: _notas.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MarcoHoja(
      titulo: 'Ajustes del presupuesto',
      icono: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descuento,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _soloNumeros,
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
              labelText: 'Descuento general',
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _validoHasta == null
                      ? 'Sin fecha de vigencia'
                      : 'Válido hasta: ${_fechaCorta.format(_validoHasta!)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_validoHasta != null)
                IconButton(
                  tooltip: 'Quitar vigencia',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _validoHasta = null),
                ),
              TextButton.icon(
                onPressed: _elegirVigencia,
                icon: const Icon(Icons.event, size: 18),
                label: Text(_validoHasta == null ? 'Elegir' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notas,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas / condiciones (salen en el PDF)',
              hintText: 'Ej. Tratamiento sujeto a valoración radiográfica.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check),
            label: const Text('Guardar ajustes'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PRECIOS POR TRATAMIENTO DEL ODONTOGRAMA
// ---------------------------------------------------------------------------

Future<Map<EstadoDiente, double>?> mostrarHojaPrecios(
  BuildContext context, {
  required Map<EstadoDiente, double> precios,
}) {
  return showModalBottomSheet<Map<EstadoDiente, double>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaPrecios(precios: precios),
  );
}

class _HojaPrecios extends StatefulWidget {
  final Map<EstadoDiente, double> precios;
  const _HojaPrecios({required this.precios});

  @override
  State<_HojaPrecios> createState() => _HojaPreciosState();
}

class _HojaPreciosState extends State<_HojaPrecios> {
  late final Map<EstadoDiente, TextEditingController> _controladores;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controladores = {
      for (final e in preciosPorDefecto.keys)
        e: TextEditingController(
          text: (widget.precios[e] ?? preciosPorDefecto[e]!).toStringAsFixed(2),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    final resultado = <EstadoDiente, double>{};
    for (final entry in _controladores.entries) {
      final valor = parsearMonto(entry.value.text);
      if (valor == null || valor < 0) {
        setState(() => _error =
            'Revisa el precio de "${estiloEstadoDiente[entry.key]!.etiqueta}".');
        return;
      }
      resultado[entry.key] = redondear2(valor);
    }
    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return _MarcoHoja(
      titulo: 'Precios por hallazgo',
      icono: Icons.sell_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Se usan al generar el presupuesto desde el odontograma. '
            'Los tratamientos que ya están en la lista conservan su precio.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          for (final entry in _controladores.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(estiloEstadoDiente[entry.key]!.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(estiloEstadoDiente[entry.key]!.etiqueta)),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: entry.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: _soloNumeros,
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check),
            label: const Text('Guardar precios'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HALLAZGOS DEL ODONTOGRAMA (elegir cuáles pasan al presupuesto)
// ---------------------------------------------------------------------------

Future<List<ItemPresupuesto>?> mostrarHojaHallazgos(
  BuildContext context, {
  required List<ItemPresupuesto> candidatos,
  required DateTime fechaOdontograma,
  required int pendientesQueSeQuitan,
}) {
  return showModalBottomSheet<List<ItemPresupuesto>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaHallazgos(
      candidatos: candidatos,
      fechaOdontograma: fechaOdontograma,
      pendientesQueSeQuitan: pendientesQueSeQuitan,
    ),
  );
}

class _HojaHallazgos extends StatefulWidget {
  final List<ItemPresupuesto> candidatos;
  final DateTime fechaOdontograma;
  final int pendientesQueSeQuitan;
  const _HojaHallazgos({
    required this.candidatos,
    required this.fechaOdontograma,
    required this.pendientesQueSeQuitan,
  });

  @override
  State<_HojaHallazgos> createState() => _HojaHallazgosState();
}

class _HojaHallazgosState extends State<_HojaHallazgos> {
  late final Set<String> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = widget.candidatos.map((c) => c.id).toSet();
  }

  double get _totalSeleccion => redondear2(widget.candidatos
      .where((c) => _seleccion.contains(c.id))
      .fold(0.0, (s, c) => s + c.total));

  @override
  Widget build(BuildContext context) {
    final todos = _seleccion.length == widget.candidatos.length;
    return _MarcoHoja(
      titulo: 'Hallazgos del odontograma',
      icono: Icons.grid_view,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Odontograma del ${_fechaCorta.format(widget.fechaOdontograma)}. '
            'Marca lo que quieres cobrar en este presupuesto.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (widget.pendientesQueSeQuitan > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Además se quitarán ${widget.pendientesQueSeQuitan} pendiente(s) '
              'automático(s) que ya no figuran en el odontograma.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                if (todos) {
                  _seleccion.clear();
                } else {
                  _seleccion.addAll(widget.candidatos.map((c) => c.id));
                }
              }),
              child: Text(todos ? 'Quitar todos' : 'Marcar todos'),
            ),
          ),
          for (final c in widget.candidatos)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _seleccion.contains(c.id),
              title: Text(c.descripcion),
              secondary: Text(
                formatoMoneda(c.total),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _seleccion.add(c.id);
                } else {
                  _seleccion.remove(c.id);
                }
              }),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_seleccion.isEmpty && widget.pendientesQueSeQuitan == 0)
                ? null
                : () => Navigator.pop(
                      context,
                      widget.candidatos
                          .where((c) => _seleccion.contains(c.id))
                          .toList(),
                    ),
            icon: const Icon(Icons.playlist_add_check),
            label: Text(
              _seleccion.isEmpty
                  ? 'Aplicar'
                  : 'Agregar ${_seleccion.length} (${formatoMoneda(_totalSeleccion)})',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MOTIVO DE ANULACIÓN
// ---------------------------------------------------------------------------

Future<String?> pedirMotivoAnulacion(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DialogoMotivo(),
  );
}

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo();

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final TextEditingController _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El pago no se borra: queda en el historial como ANULADO y deja '
            'de contar en el saldo.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej. Monto mal digitado',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, _motivo.text.trim()),
          child: const Text('Anular pago'),
        ),
      ],
    );
  }
}
