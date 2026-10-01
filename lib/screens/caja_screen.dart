import 'dart:async';
import 'package:flutter/material.dart';
import '../models/meta_goal.dart';
import '../models/pago.dart';
import '../models/presupuesto.dart';
import '../services/caja_pdf_service.dart';
import '../services/caja_service.dart';
import '../services/config_service.dart';
import '../services/presupuesto_pdf_service.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ayuda.dart';
import '../widgets/fondo_decorativo.dart';
import '../widgets/presupuesto_sheets.dart' show iconoMetodoPago;
import 'presupuesto_screen.dart';

enum _Periodo { dia, semana, mes, rango }

const List<String> _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto',
  'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const List<String> _diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Caja del consultorio: cuánto se cobró (por día, semana, mes o rango),
/// cómo se pagó y quién todavía debe.
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _busqueda = TextEditingController();
  List<MetaGoal> _metas = [];
  bool _cargando = true;
  bool _error = false;
  String _nombreDoctor = '';

  _Periodo _periodo = _Periodo.mes;
  DateTime _ancla = DateTime.now();
  RangoFechas? _rangoPersonalizado;
  String _filtroDeuda = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() {});
        unawaited(ayudaPrimeraVez(context, _temaAyuda));
      }
    });
    _cargar();
    programarAyudaPrimeraVez(this, 'caja_cobros');
  }

  String get _temaAyuda => _tab.index == 1 ? 'caja_porcobrar' : 'caja_cobros';

  @override
  void dispose() {
    _tab.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final metas = await StorageService.cargarMetas();
      final nombre = await ConfigService.obtenerNombreDoctor();
      if (!mounted) {
        return;
      }
      setState(() {
        _metas = metas;
        _nombreDoctor = nombre ?? '';
        _cargando = false;
        _error = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _guardarTodo() async {
    await StorageService.guardarMetas(_metas);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ------------------------------------------------------------------
  // Período
  // ------------------------------------------------------------------

  /// Rango que corresponde a [ancla] según el período elegido.
  RangoFechas _rangoPara(DateTime ancla) {
    switch (_periodo) {
      case _Periodo.dia:
        return RangoFechas.dia(ancla);
      case _Periodo.semana:
        return RangoFechas.semana(ancla);
      case _Periodo.mes:
        return RangoFechas.mes(ancla);
      case _Periodo.rango:
        return _rangoPersonalizado ?? RangoFechas.mes(DateTime.now());
    }
  }

  RangoFechas get _rango => _rangoPara(_ancla);

  DateTime _anclaDesplazada(int pasos) {
    switch (_periodo) {
      case _Periodo.dia:
        return DateTime(_ancla.year, _ancla.month, _ancla.day + pasos);
      case _Periodo.semana:
        return DateTime(_ancla.year, _ancla.month, _ancla.day + 7 * pasos);
      case _Periodo.mes:
        return DateTime(_ancla.year, _ancla.month + pasos, 1);
      case _Periodo.rango:
        return _ancla;
    }
  }

  RangoFechas get _rangoAnterior => _periodo == _Periodo.rango
      ? _rango.anteriorMismaDuracion()
      : _rangoPara(_anclaDesplazada(-1));

  bool get _puedeAvanzar =>
      _periodo != _Periodo.rango &&
      !_rangoPara(_anclaDesplazada(1)).inicio.isAfter(DateTime.now());

  void _mover(int pasos) {
    setState(() => _ancla = _anclaDesplazada(pasos));
  }

  String _fmt(DateTime d) => CajaPdfService.fmtFecha(d);

  String get _tituloPeriodo {
    final r = _rango;
    switch (_periodo) {
      case _Periodo.dia:
        final hoy = RangoFechas.soloFecha(DateTime.now());
        return r.inicio == hoy ? 'Hoy, ${_fmt(r.inicio)}' : _fmt(r.inicio);
      case _Periodo.semana:
        return '${_fmt(r.inicio)} – ${_fmt(r.ultimoDia)}';
      case _Periodo.mes:
        return '${_meses[r.inicio.month - 1]} ${r.inicio.year}';
      case _Periodo.rango:
        return r.dias <= 1
            ? _fmt(r.inicio)
            : '${_fmt(r.inicio)} – ${_fmt(r.ultimoDia)}';
    }
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final actual = _rangoPersonalizado ?? RangoFechas.mes(hoy);
    final elegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: DateTimeRange(
        start: actual.inicio,
        end: actual.ultimoDia.isAfter(hoy) ? hoy : actual.ultimoDia,
      ),
      helpText: 'Elige el rango de fechas',
      saveText: 'Aplicar',
    );
    if (elegido == null || !mounted) {
      return;
    }
    setState(() {
      _rangoPersonalizado = RangoFechas.entre(elegido.start, elegido.end);
      _periodo = _Periodo.rango;
    });
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  Future<void> _exportar(ResumenCaja resumen) async {
    if (resumen.cantidad == 0) {
      _aviso('No hay cobros en este período para exportar.');
      return;
    }
    try {
      await CajaPdfService.imprimirReporte(
        tituloPeriodo: _tituloPeriodo,
        rango: _rango,
        resumen: resumen,
        nombreDoctor: _nombreDoctor,
      );
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo generar el reporte. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> _verRecibo(MovimientoCaja m) async {
    try {
      await PresupuestoPdfService.imprimirRecibo(
        paciente: m.paciente,
        pago: m.pago,
        nombreDoctor: _nombreDoctor,
      );
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo generar el recibo.');
      }
    }
  }

  Future<void> _abrirPresupuesto(DeudaPaciente d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PresupuestoScreen(
          paciente: d.paciente,
          onGuardar: _guardarTodo,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _guardarTodo();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recordarSaldo(DeudaPaciente d) async {
    final celular = d.paciente.celular;
    if (!WhatsAppService.celularValido(celular)) {
      _aviso('${d.paciente.nombre} no tiene un celular válido registrado.');
      return;
    }
    final saludo = _nombreDoctor.trim().isEmpty
        ? 'le escribimos del consultorio odontológico'
        : 'le escribe $_nombreDoctor, su odontólogo/a';
    final mensaje = 'Hola ${d.paciente.nombre}, $saludo.\n\n'
        'Le recordamos que tiene un saldo pendiente de ${formatoMoneda(d.saldo)} '
        'de su tratamiento (total ${formatoMoneda(d.total)}, pagado ${formatoMoneda(d.pagado)}).\n\n'
        'Cualquier duda, con gusto le ayudamos. ¡Gracias!';
    final ok = await WhatsAppService.enviarRecordatorio(
      celular: celular,
      mensaje: mensaje,
    );
    if (!ok && mounted) {
      _aviso('No se pudo abrir WhatsApp.');
    }
  }

  // ------------------------------------------------------------------
  // Interfaz
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final todos = CajaService.movimientos(_metas);
    final resumen = CajaService.resumir(todos, _rango);
    final deudas = CajaService.porCobrar(_metas);

    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Caja',
        colores: const [AppTheme.rosaOscuro, AppTheme.lavanda],
        acciones: [
          BotonAyuda(tema: _temaAyuda),
          IconButton(
            tooltip: 'Exportar reporte (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _cargando ? null : () => _exportar(resumen),
          ),
        ],
      ),
      body: FondoDecorativo(
        child: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? _vistaError()
                  : Column(
                      children: [
                        _barraPestanas(deudas.length),
                        Expanded(
                          child: TabBarView(
                            controller: _tab,
                            children: [
                              _pestanaCobros(resumen),
                              _pestanaPorCobrar(deudas),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _vistaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
            const SizedBox(height: 10),
            const Text(
              'No se pudieron cargar los datos.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _cargando = true;
                  _error = false;
                });
                _cargar();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraPestanas(int nDeudas) {
    Widget etiqueta(IconData icono, String texto) => Tab(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icono, size: 18), const SizedBox(width: 6), Text(texto)],
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tab,
        labelColor: AppTheme.rosaOscuro,
        unselectedLabelColor: Colors.black54,
        indicatorColor: AppTheme.rosaOscuro,
        dividerColor: Colors.transparent,
        tabs: [
          etiqueta(Icons.savings_outlined, 'Cobros'),
          etiqueta(Icons.hourglass_bottom, 'Por cobrar ($nDeudas)'),
        ],
      ),
    );
  }

  // ---------------- Pestaña Cobros ----------------

  Widget _pestanaCobros(ResumenCaja resumen) {
    final anterior = CajaService.resumir(
      CajaService.movimientos(_metas),
      _rangoAnterior,
    );
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _selectorPeriodo(),
          const SizedBox(height: 10),
          _tarjetaTotal(resumen, anterior),
          if (resumen.cantidad == 0)
            _vacio()
          else ...[
            if (_periodo != _Periodo.dia && resumen.porDia.isNotEmpty) ...[
              const SizedBox(height: 10),
              _tarjetaGrafico(resumen),
            ],
            const SizedBox(height: 10),
            _tarjetaMetodos(resumen),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Pagos del período (${resumen.cantidad})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            for (final m in resumen.movimientos) _filaMovimiento(m),
          ],
          if (resumen.anulados.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${resumen.anulados.length} pago(s) anulado(s) en el período '
              '(${formatoMoneda(resumen.anuladosMonto)}), no incluidos en el total.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectorPeriodo() {
    Widget chip(String texto, _Periodo p) => ChoiceChip(
          label: Text(texto),
          selected: _periodo == p,
          onSelected: (_) {
            if (p == _Periodo.rango) {
              _elegirRango();
            } else {
              setState(() {
                _periodo = p;
                _ancla = DateTime.now();
              });
            }
          },
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              chip('Día', _Periodo.dia),
              chip('Semana', _Periodo.semana),
              chip('Mes', _Periodo.mes),
              chip('Rango', _Periodo.rango),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: _periodo == _Periodo.rango ? null : () => _mover(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _periodo == _Periodo.rango ? _elegirRango : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _tituloPeriodo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: _puedeAvanzar ? () => _mover(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTotal(ResumenCaja resumen, ResumenCaja anterior) {
    String? comparacion;
    var sube = true;
    if (anterior.total > 0) {
      final pct = (resumen.total - anterior.total) / anterior.total * 100;
      sube = pct >= 0;
      comparacion =
          '${sube ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% frente al período anterior '
          '(${formatoMoneda(anterior.total)})';
    } else if (resumen.total > 0) {
      comparacion = 'Sin cobros en el período anterior';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.rosaPrincipal, AppTheme.lavanda],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lavanda.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total cobrado',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatoMoneda(resumen.total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (comparacion != null) ...[
            const SizedBox(height: 4),
            Text(
              comparacion,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _mini('Pagos', '${resumen.cantidad}'),
              _mini('Promedio', formatoMoneda(resumen.promedioPorPago)),
              _mini(
                'Mejor día',
                resumen.porDia.isEmpty
                    ? '-'
                    : formatoMoneda(
                        resumen.porDia.values.reduce((a, b) => a > b ? a : b),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String etiqueta, String valor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            etiqueta,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.savings_outlined,
              size: 52, color: AppTheme.rosaPrincipal.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          const Text(
            'Sin cobros en este período',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Los pagos que registres en el presupuesto de cada paciente aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaGrafico(ResumenCaja resumen) {
    final rango = _rango;
    final dias = <DateTime>[];
    for (var d = rango.inicio; d.isBefore(rango.fin); d = DateTime(d.year, d.month, d.day + 1)) {
      dias.add(d);
    }
    final maximo = resumen.porDia.values.fold(0.0, (m, v) => v > m ? v : m);
    const alto = 96.0;
    final pocas = dias.length <= 8;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cobrado por día', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: alto + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < dias.length; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${_fmt(dias[i])}: ${formatoMoneda(resumen.porDia[dias[i]] ?? 0)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: maximo <= 0
                                ? 2
                                : ((resumen.porDia[dias[i]] ?? 0) / maximo * alto)
                                    .clamp(2.0, alto)
                                    .toDouble(),
                            margin: EdgeInsets.symmetric(horizontal: pocas ? 6 : 1),
                            decoration: BoxDecoration(
                              color: (resumen.porDia[dias[i]] ?? 0) > 0
                                  ? AppTheme.rosaPrincipal
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          SizedBox(
                            height: 18,
                            child: Center(
                              child: Text(
                                pocas
                                    ? _diasSemana[dias[i].weekday - 1]
                                    : (i == 0 || dias[i].day % 5 == 0
                                        ? '${dias[i].day}'
                                        : ''),
                                style: const TextStyle(fontSize: 9, color: Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaMetodos(ResumenCaja resumen) {
    final metodos = MetodoPago.values
        .where((m) => (resumen.porMetodo[m] ?? 0) > 0)
        .toList()
      ..sort((a, b) => resumen.porMetodo[b]!.compareTo(resumen.porMetodo[a]!));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Por forma de pago', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final m in metodos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(iconoMetodoPago[m], size: 18, color: AppTheme.rosaOscuro),
                      const SizedBox(width: 8),
                      Expanded(child: Text(etiquetaMetodoPago[m]!)),
                      Text(
                        formatoMoneda(resumen.porMetodo[m]!),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        width: 46,
                        child: Text(
                          '${(resumen.porMetodo[m]! / resumen.total * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (resumen.porMetodo[m]! / resumen.total).clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      backgroundColor: AppTheme.rosaClaro,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.rosaPrincipal),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaMovimiento(MovimientoCaja m) {
    final detalle = <String>[
      _fmt(m.pago.fecha),
      etiquetaMetodoPago[m.pago.metodo]!,
      'Recibo ${m.pago.numeroTexto}',
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _verRecibo(m),
        leading: CircleAvatar(
          backgroundColor: AppTheme.rosaClaro,
          child: Icon(iconoMetodoPago[m.pago.metodo], size: 20, color: AppTheme.rosaOscuro),
        ),
        title: Text(
          m.paciente.nombre.isEmpty ? 'Paciente sin nombre' : m.paciente.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detalle, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          formatoMoneda(m.pago.monto),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.rosaOscuro,
          ),
        ),
      ),
    );
  }

  // ---------------- Pestaña Por cobrar ----------------

  Widget _pestanaPorCobrar(List<DeudaPaciente> deudas) {
    final filtro = _filtroDeuda.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? deudas
        : deudas
            .where((d) =>
                d.paciente.nombre.toLowerCase().contains(filtro) ||
                d.paciente.cedula.contains(filtro))
            .toList();
    final totalGeneral = CajaService.totalPorCobrar(deudas);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, AppTheme.rosaPrincipal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  'Total por cobrar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatoMoneda(totalGeneral),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${deudas.length} paciente(s) con saldo pendiente',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (deudas.isNotEmpty)
            TextField(
              controller: _busqueda,
              onChanged: (v) => setState(() => _filtroDeuda = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o cédula',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filtroDeuda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busqueda.clear();
                          setState(() => _filtroDeuda = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.92),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          const SizedBox(height: 6),
          if (deudas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 52, color: Colors.green.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    '¡Todo al día!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ningún paciente con tratamiento aceptado tiene saldo pendiente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          else if (visibles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Ningún paciente coincide con la búsqueda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            for (final d in visibles) _filaDeuda(d),
          if (deudas.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Solo aparecen pacientes con algún tratamiento aceptado o con pagos '
                'registrados; un presupuesto aún sin aprobar no cuenta como deuda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaDeuda(DeudaPaciente d) {
    final progreso =
        d.total <= 0 ? 0.0 : (d.pagado / d.total).clamp(0.0, 1.0).toDouble();
    final ultimo = d.ultimoPago == null
        ? 'Sin pagos aún'
        : 'Último pago: ${_fmt(d.ultimoPago!)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirPresupuesto(d),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.paciente.nombre.isEmpty ? 'Paciente sin nombre' : d.paciente.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Text(
                    formatoMoneda(d.saldo),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recordar saldo por WhatsApp',
                    icon: const Icon(Icons.chat_outlined, size: 20),
                    onPressed: () => _recordarSaldo(d),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 6,
                    backgroundColor: AppTheme.rosaClaro,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mentaFresca),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total ${formatoMoneda(d.total)}  ·  Pagado ${formatoMoneda(d.pagado)}  ·  $ultimo',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
