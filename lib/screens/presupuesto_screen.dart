import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/odontograma.dart';
import '../models/pago.dart';
import '../models/paciente.dart';
import '../models/presupuesto.dart';
import '../services/config_service.dart';
import '../services/presupuesto_pdf_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_decorativo.dart';
import '../widgets/ayuda.dart';
import '../widgets/presupuesto_sheets.dart';

/// Presupuesto (plan de tratamiento) y cobros del paciente.
///
/// [onGuardar] se llama después de CADA cambio para que el dato quede
/// respaldado al instante (sobre todo los pagos): así no depende de que la
/// doctora salga ordenadamente de la pantalla.
class PresupuestoScreen extends StatefulWidget {
  final Paciente paciente;
  final Future<void> Function()? onGuardar;
  const PresupuestoScreen({super.key, required this.paciente, this.onGuardar});

  @override
  State<PresupuestoScreen> createState() => _PresupuestoScreenState();
}

class _PresupuestoScreenState extends State<PresupuestoScreen>
    with SingleTickerProviderStateMixin {
  final _uuid = const Uuid();
  final DateFormat _fecha = DateFormat('dd/MM/yyyy');
  late Presupuesto _p;
  late final TabController _tab;
  EstadoTratamiento? _filtro;
  String _nombreDoctor = '';

  @override
  void initState() {
    super.initState();
    _p = widget.paciente.presupuesto ?? Presupuesto();
    widget.paciente.presupuesto = _p;
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() {});
        unawaited(ayudaPrimeraVez(context, _temaAyuda));
      }
    });
    _cargarDoctor();
    programarAyudaPrimeraVez(this, 'presupuesto');
  }

  String get _temaAyuda => _tab.index == 1 ? 'pagos' : 'presupuesto';

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargarDoctor() async {
    final nombre = await ConfigService.obtenerNombreDoctor();
    if (!mounted) {
      return;
    }
    if (nombre != null) {
      setState(() => _nombreDoctor = nombre);
    }
  }

  /// Refresca la pantalla y respalda el cambio de inmediato.
  void _cambio() {
    setState(() {});
    final guardar = widget.onGuardar;
    if (guardar != null) {
      unawaited(guardar());
    }
  }

  void _aviso(String texto, {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), action: accion));
  }

  // ------------------------------------------------------------------
  // TRATAMIENTOS
  // ------------------------------------------------------------------

  Odontograma? get _ultimoOdontograma {
    if (widget.paciente.odontogramas.isEmpty) {
      return null;
    }
    final ordenados = List<Odontograma>.from(widget.paciente.odontogramas)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return ordenados.first;
  }

  ItemPresupuesto _crearItemDesdeHallazgo(
    String piezaFdi,
    CaraDental? cara,
    EstadoDiente estado,
  ) {
    final estilo = estiloEstadoDiente[estado]!;
    final descripcionCara = cara != null ? ' (${etiquetaCara[cara]})' : '';
    return ItemPresupuesto(
      id: _uuid.v4(),
      piezaFdi: piezaFdi,
      cara: cara,
      estadoOrigen: estado,
      descripcion: 'Pieza $piezaFdi · ${estilo.etiqueta}$descripcionCara',
      precio: _p.precios[estado] ?? preciosPorDefecto[estado] ?? 0,
      generadoAutomaticamente: true,
    );
  }

  /// Sincroniza el presupuesto con el último odontograma SIN pisar el
  /// trabajo ya hecho: lo que ya está en la lista (con su precio, estado y
  /// notas) se conserva, solo se ofrecen los hallazgos nuevos y solo se
  /// quitan los automáticos que siguen "pendientes" y ya no existen.
  Future<void> _generarDesdeOdontograma() async {
    final odontograma = _ultimoOdontograma;
    if (odontograma == null) {
      _aviso('Este paciente todavía no tiene un odontograma registrado.');
      return;
    }

    final candidatos = <ItemPresupuesto>[];
    for (final diente in odontograma.dientes.values) {
      if (diente.estadoGeneral != null) {
        final e = diente.estadoGeneral!;
        if (e != EstadoDiente.ausente && e != EstadoDiente.sano) {
          candidatos.add(_crearItemDesdeHallazgo(diente.numeroFdi, null, e));
        }
      } else {
        for (final entry in diente.caras.entries) {
          if (entry.value != EstadoDiente.sano &&
              entry.value != EstadoDiente.ausente) {
            candidatos
                .add(_crearItemDesdeHallazgo(diente.numeroFdi, entry.key, entry.value));
          }
        }
      }
    }

    final clavesVigentes = candidatos.map((c) => c.claveOrigen).toSet();
    final clavesExistentes = _p.items.map((i) => i.claveOrigen).toSet();
    final nuevos =
        candidatos.where((c) => !clavesExistentes.contains(c.claveOrigen)).toList()
          ..sort((a, b) =>
              (int.tryParse(a.piezaFdi ?? '') ?? 0)
                  .compareTo(int.tryParse(b.piezaFdi ?? '') ?? 0));
    final obsoletos = _p.items
        .where((i) =>
            i.generadoAutomaticamente &&
            i.estado == EstadoTratamiento.pendiente &&
            !clavesVigentes.contains(i.claveOrigen))
        .toList();

    if (nuevos.isEmpty && obsoletos.isEmpty) {
      _aviso(
        'El presupuesto ya está al día con el odontograma del '
        '${_fecha.format(odontograma.fecha)}.',
      );
      return;
    }

    final elegidos = await mostrarHojaHallazgos(
      context,
      candidatos: nuevos,
      fechaOdontograma: odontograma.fecha,
      pendientesQueSeQuitan: obsoletos.length,
    );
    if (elegidos == null || !mounted) {
      return;
    }
    _p.items.removeWhere((i) => obsoletos.contains(i));
    _p.items.addAll(elegidos);
    _cambio();
    _aviso(
      'Se agregaron ${elegidos.length} tratamiento(s)'
      '${obsoletos.isEmpty ? '' : ' y se quitaron ${obsoletos.length} pendiente(s) obsoleto(s)'}.',
    );
  }

  Future<void> _editarItem([ItemPresupuesto? existente]) async {
    final resultado = await mostrarHojaItem(context, existente: existente);
    if (resultado == null || !mounted) {
      return;
    }
    if (resultado.eliminar) {
      await _confirmarEliminarItem(existente!);
      return;
    }
    final item = resultado.item!;
    if (existente == null) {
      _p.items.add(item);
    }
    _cambio();
  }

  Future<void> _confirmarEliminarItem(ItemPresupuesto item) async {
    final tienePagos = _p.pagosVigentes.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tratamiento'),
        content: Text(
          '¿Eliminar "${item.descripcion}" del presupuesto?'
          '${tienePagos ? '\n\nYa hay pagos registrados: si solo no se va a realizar, es mejor marcarlo como "Cancelado" para conservar el historial.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _p.items.remove(item);
      _cambio();
    }
  }

  Future<void> _aceptarTodosLosPendientes() async {
    final pendientes =
        _p.items.where((i) => i.estado == EstadoTratamiento.pendiente).toList();
    if (pendientes.isEmpty) {
      _aviso('No hay tratamientos pendientes por aceptar.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceptar presupuesto'),
        content: Text(
          'El paciente aprobó el plan. ¿Marcar ${pendientes.length} tratamiento(s) '
          'pendiente(s) como "Aceptado"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aceptar todos'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      for (final i in pendientes) {
        i.cambiarEstado(EstadoTratamiento.aceptado);
      }
      _cambio();
    }
  }

  Future<void> _configurarPrecios() async {
    final nuevos = await mostrarHojaPrecios(context, precios: _p.precios);
    if (nuevos == null || !mounted) {
      return;
    }
    _p.precios
      ..clear()
      ..addAll(nuevos);
    _cambio();
  }

  Future<void> _ajustes() async {
    final ajustes = await mostrarHojaAjustes(context, presupuesto: _p);
    if (ajustes == null || !mounted) {
      return;
    }
    _p.descuentoPorcentaje = ajustes.descuentoPorcentaje;
    _p.validoHasta = ajustes.validoHasta;
    _p.notas = ajustes.notas;
    _cambio();
  }

  // ------------------------------------------------------------------
  // PAGOS
  // ------------------------------------------------------------------

  Future<void> _registrarPago() async {
    if (_p.items.isEmpty) {
      _aviso('Primero agrega tratamientos al presupuesto para poder registrar pagos.');
      _tab.animateTo(0);
      return;
    }
    final pago = await mostrarHojaPago(
      context,
      saldo: _p.saldo,
      numeroRecibo: _p.siguienteNumeroRecibo,
    );
    if (pago == null || !mounted) {
      return;
    }
    if (pago.monto > _p.saldo + 0.004) {
      final sobrante = redondear2(pago.monto - (_p.saldo > 0 ? _p.saldo : 0));
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('El pago supera el saldo'),
          content: Text(
            _p.saldo > 0
                ? 'El saldo pendiente es ${formatoMoneda(_p.saldo)} y estás registrando '
                    '${formatoMoneda(pago.monto)}. Quedarán ${formatoMoneda(sobrante)} a favor del paciente.'
                : 'El presupuesto ya está cubierto. Este pago de ${formatoMoneda(pago.monto)} '
                    'quedará como saldo a favor del paciente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revisar monto'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar igual'),
            ),
          ],
        ),
      );
      if (seguir != true || !mounted) {
        return;
      }
    }
    _p.pagos.add(pago);
    _cambio();
    _aviso(
      'Pago de ${formatoMoneda(pago.monto)} registrado (recibo ${pago.numeroTexto}).',
      accion: SnackBarAction(
        label: 'Ver recibo',
        onPressed: () => _imprimirRecibo(pago),
      ),
    );
  }

  Future<void> _anularPago(Pago pago) async {
    final motivo = await pedirMotivoAnulacion(context);
    if (motivo == null || !mounted) {
      return;
    }
    pago.anulado = true;
    pago.motivoAnulacion = motivo;
    pago.fechaAnulacion = DateTime.now();
    _cambio();
    _aviso('Pago ${pago.numeroTexto} anulado.');
  }

  Future<void> _imprimirRecibo(Pago pago) async {
    try {
      await PresupuestoPdfService.imprimirRecibo(
        paciente: widget.paciente,
        pago: pago,
        nombreDoctor: _nombreDoctor,
      );
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo generar el recibo. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> _imprimirPresupuesto() async {
    if (_p.items.isEmpty) {
      _aviso('Agrega al menos un tratamiento para generar el PDF.');
      return;
    }
    try {
      await PresupuestoPdfService.imprimirPresupuesto(
        paciente: widget.paciente,
        nombreDoctor: _nombreDoctor,
      );
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo generar el PDF. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> _enviarWhatsApp() async {
    final celular = widget.paciente.celular;
    if (!WhatsAppService.celularValido(celular)) {
      _aviso('El paciente no tiene un celular válido. Edítalo en sus datos (con código de país).');
      return;
    }
    if (_p.items.isEmpty) {
      _aviso('Agrega al menos un tratamiento antes de enviar el resumen.');
      return;
    }
    final saludo = _nombreDoctor.trim().isEmpty
        ? 'le escribimos del consultorio odontológico'
        : 'le escribe $_nombreDoctor, su odontólogo/a';
    final b = StringBuffer()
      ..writeln('Hola ${widget.paciente.nombre}, $saludo.')
      ..writeln()
      ..writeln('Resumen de su tratamiento:')
      ..writeln('- Total del presupuesto: ${formatoMoneda(_p.total)}');
    if (_p.pagosVigentes.isNotEmpty) {
      b.writeln('- Pagado: ${formatoMoneda(_p.totalPagado)}');
    }
    if (_p.saldo > 0.004) {
      b.writeln('- Saldo pendiente: ${formatoMoneda(_p.saldo)}');
    } else if (_p.total > 0) {
      b.writeln('- Su tratamiento está al día. ¡Gracias!');
    }
    if (_p.validoHasta != null) {
      b.writeln('- Presupuesto válido hasta el ${_fecha.format(_p.validoHasta!)}');
    }
    b
      ..writeln()
      ..write('Cualquier duda, con gusto le ayudamos.');
    final ok = await WhatsAppService.enviarRecordatorio(
      celular: celular,
      mensaje: b.toString(),
    );
    if (!ok && mounted) {
      _aviso('No se pudo abrir WhatsApp.');
    }
  }

  // ------------------------------------------------------------------
  // INTERFAZ
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: 'Presupuesto — ${widget.paciente.nombre}',
        colores: const [AppTheme.rosaPrincipal, AppTheme.lavanda],
        acciones: [
          BotonAyuda(tema: _temaAyuda),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Imprimir / compartir PDF',
            onPressed: _imprimirPresupuesto,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'ajustes':
                  _ajustes();
                case 'aceptar':
                  _aceptarTodosLosPendientes();
                case 'precios':
                  _configurarPrecios();
                case 'whatsapp':
                  _enviarWhatsApp();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'ajustes',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.tune),
                  title: Text('Descuento, vigencia y notas'),
                ),
              ),
              PopupMenuItem(
                value: 'aceptar',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.thumb_up_alt_outlined),
                  title: Text('Aceptar presupuesto'),
                ),
              ),
              PopupMenuItem(
                value: 'precios',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.sell_outlined),
                  title: Text('Precios por hallazgo'),
                ),
              ),
              PopupMenuItem(
                value: 'whatsapp',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.chat_outlined),
                  title: Text('Enviar resumen por WhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton.extended(
              onPressed: _registrarPago,
              icon: const Icon(Icons.add),
              label: const Text('Registrar pago'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _editarItem(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tratamiento'),
            ),
      body: FondoDecorativo(
        child: SafeArea(
          child: Column(
            children: [
              _encabezado(),
              _barraPestanas(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [_pestanaTratamientos(), _pestanaPagos()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cifra(String etiqueta, double valor, {bool destacada = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatoMoneda(valor),
              style: TextStyle(
                color: Colors.white,
                fontSize: destacada ? 24 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado() {
    final total = _p.total;
    final progreso =
        total <= 0 ? 0.0 : (_p.totalPagado / total).clamp(0.0, 1.0).toDouble();
    final estado = _p.estadoCobro;
    final colorEstado = Color(colorEstadoCobro[estado]!);
    final aFavor = _p.saldo < -0.004;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _cifra('Total', total),
              _cifra('Pagado', _p.totalPagado),
              _cifra(aFavor ? 'A favor' : 'Saldo', _p.saldo.abs(), destacada: true),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.30),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  etiquetaEstadoCobro[estado]!,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _resumenAvance(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _resumenAvance() {
    final activos = _p.itemsActivos.length;
    final partes = <String>[];
    if (activos > 0) {
      partes.add('${_p.cantidadCompletados} de $activos realizados');
    }
    if (_p.validoHasta != null) {
      partes.add(_p.vencido
          ? 'Vencido el ${_fecha.format(_p.validoHasta!)}'
          : 'Vigente hasta ${_fecha.format(_p.validoHasta!)}');
    }
    return partes.join('  ·  ');
  }

  Widget _barraPestanas() {
    final nPagos = _p.pagos.length;
    Widget etiqueta(IconData icono, String texto) => Tab(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icono, size: 18), const SizedBox(width: 6), Text(texto)],
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
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
          etiqueta(Icons.medical_services_outlined,
              'Tratamientos (${_p.items.length})'),
          etiqueta(Icons.payments_outlined, 'Pagos ($nPagos)'),
        ],
      ),
    );
  }

  // ---------------- Pestaña Tratamientos ----------------

  Widget _pestanaTratamientos() {
    if (_p.items.isEmpty) {
      return _estadoVacio(
        icono: Icons.medical_services_outlined,
        titulo: 'Aún no hay tratamientos',
        detalle:
            'Genera el plan desde el odontograma del paciente o agrega tratamientos a mano.',
        acciones: [
          FilledButton.icon(
            onPressed: _generarDesdeOdontograma,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Generar desde odontograma'),
          ),
        ],
      );
    }
    final visibles = _filtro == null
        ? _p.items
        : _p.items.where((i) => i.estado == _filtro).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
      children: [
        Row(
          children: [
            Expanded(child: _filtros()),
            IconButton.filledTonal(
              tooltip: 'Sincronizar con el odontograma',
              onPressed: _generarDesdeOdontograma,
              icon: const Icon(Icons.auto_fix_high),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No hay tratamientos con este estado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          for (final item in visibles) _tarjetaItem(item),
        const SizedBox(height: 10),
        _resumenTotales(),
      ],
    );
  }

  Widget _filtros() {
    Widget chip(String texto, EstadoTratamiento? valor, int cantidad) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text('$texto ($cantidad)', style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          selected: _filtro == valor,
          onSelected: (_) => setState(() => _filtro = valor),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Todos', null, _p.items.length),
          for (final e in EstadoTratamiento.values)
            if (_p.items.any((i) => i.estado == e))
              chip(
                etiquetaEstadoTratamiento[e]!,
                e,
                _p.items.where((i) => i.estado == e).length,
              ),
        ],
      ),
    );
  }

  Widget _tarjetaItem(ItemPresupuesto item) {
    final color = Color(colorEstadoTratamiento[item.estado]!);
    final cancelado = item.estado == EstadoTratamiento.cancelado;
    final estiloTexto = TextStyle(
      fontWeight: FontWeight.w600,
      decoration: cancelado ? TextDecoration.lineThrough : null,
      color: cancelado ? Colors.black45 : null,
    );
    final detalles = <String>[
      if (item.cantidad > 1) '${item.cantidad} × ${formatoMoneda(item.precio)}',
      if (!item.generadoAutomaticamente && item.piezaFdi != null)
        'Pieza ${item.piezaFdi}',
      if (item.fechaRealizacion != null)
        'Realizado el ${_fecha.format(item.fechaRealizacion!)}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.95),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _editarItem(item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(item.descripcion, style: estiloTexto)),
                          const SizedBox(width: 8),
                          Text(
                            formatoMoneda(item.total),
                            style: estiloTexto.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      if (detalles.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalles.join('  ·  '),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                      if (item.notas.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.notas,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _chipEstado(item, color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipEstado(ItemPresupuesto item, Color color) {
    return PopupMenuButton<EstadoTratamiento>(
      tooltip: 'Cambiar estado',
      onSelected: (nuevo) {
        item.cambiarEstado(nuevo);
        _cambio();
      },
      itemBuilder: (_) => [
        for (final e in EstadoTratamiento.values)
          PopupMenuItem<EstadoTratamiento>(
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              etiquetaEstadoTratamiento[item.estado]!,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _resumenTotales() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.rosaClaro.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filaTotal('Subtotal', _p.subtotal),
          if (_p.descuentoPorcentaje > 0)
            _filaTotal(
              'Descuento (${_p.descuentoPorcentaje.toStringAsFixed(_p.descuentoPorcentaje == _p.descuentoPorcentaje.roundToDouble() ? 0 : 1)}%)',
              -_p.descuento,
            ),
          const Divider(),
          _filaTotal('Total', _p.total, destacado: true),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _ajustes,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Descuento, vigencia y notas'),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: estilo),
          const Spacer(),
          Text(formatoMoneda(valor), style: estilo),
        ],
      ),
    );
  }

  // ---------------- Pestaña Pagos ----------------

  Widget _pestanaPagos() {
    if (_p.pagos.isEmpty) {
      return _estadoVacio(
        icono: Icons.payments_outlined,
        titulo: 'Sin pagos registrados',
        detalle: 'Cuando el paciente abone, registra el pago y se genera su recibo.',
        acciones: [
          FilledButton.icon(
            onPressed: _registrarPago,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Registrar primer pago'),
          ),
        ],
      );
    }
    final ordenados = List<Pago>.from(_p.pagos)
      ..sort((a, b) => b.numero.compareTo(a.numero));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
      children: [
        for (final pago in ordenados) _tarjetaPago(pago),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _imprimirPresupuesto,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Estado de cuenta (PDF)'),
            ),
            if (_p.saldo > 0.004)
              OutlinedButton.icon(
                onPressed: _enviarWhatsApp,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Recordar saldo'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tarjetaPago(Pago pago) {
    final anulado = pago.anulado;
    final estiloMonto = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      decoration: anulado ? TextDecoration.lineThrough : null,
      color: anulado ? Colors.black45 : AppTheme.rosaOscuro,
    );
    final detalle = <String>[
      _fecha.format(pago.fecha),
      etiquetaMetodoPago[pago.metodo]!,
      if (pago.referencia.isNotEmpty) 'Ref. ${pago.referencia}',
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  anulado ? Colors.grey.shade300 : AppTheme.rosaClaro,
              child: Icon(
                iconoMetodoPago[pago.metodo],
                size: 20,
                color: anulado ? Colors.grey : AppTheme.rosaOscuro,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Recibo ${pago.numeroTexto}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (anulado) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ANULADO',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (pago.nota.isNotEmpty)
                    Text(
                      pago.nota,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  if (anulado && pago.motivoAnulacion.isNotEmpty)
                    Text(
                      'Motivo: ${pago.motivoAnulacion}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
            Text(formatoMoneda(pago.monto), style: estiloMonto),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'recibo') {
                  _imprimirRecibo(pago);
                } else if (v == 'anular') {
                  _anularPago(pago);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'recibo',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('Ver / imprimir recibo'),
                  ),
                ),
                if (!anulado)
                  PopupMenuItem(
                    value: 'anular',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.block, color: Colors.red.shade700),
                      title: Text(
                        'Anular pago',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVacio({
    required IconData icono,
    required String titulo,
    required String detalle,
    required List<Widget> acciones,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppTheme.rosaPrincipal.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: acciones),
          ],
        ),
      ),
    );
  }
}
