import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ficha_clinica.dart';
import '../models/paciente.dart';
import '../models/presupuesto.dart';
import '../services/config_service.dart';
import '../services/ficha_pdf_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/ficha_sheets.dart';
import '../widgets/firma_pad.dart';
import '../widgets/fondo_decorativo.dart';
import 'odontograma_list_screen.dart';
import 'presupuesto_screen.dart';

const List<PaletaFicha> _paletas = [
  paletaResumen,
  paletaMedica,
  paletaEvolucion,
  paletaReceta,
  paletaConsent,
];

/// Ficha clínica del paciente: datos, historia médica con alertas, evolución
/// por cita, recetas y consentimientos firmados en pantalla.
///
/// [onGuardar] se llama después de CADA cambio, para que todo quede
/// respaldado al instante.
class FichaClinicaScreen extends StatefulWidget {
  final Paciente paciente;
  final Future<void> Function()? onGuardar;
  final int tabInicial;
  const FichaClinicaScreen({
    super.key,
    required this.paciente,
    this.onGuardar,
    this.tabInicial = 0,
  });

  @override
  State<FichaClinicaScreen> createState() => _FichaClinicaScreenState();
}

class _FichaClinicaScreenState extends State<FichaClinicaScreen>
    with SingleTickerProviderStateMixin {
  final DateFormat _fecha = DateFormat('dd/MM/yyyy');
  late final TabController _tab;
  late FichaClinica _f;
  String _nombreDoctor = '';

  Paciente get _p => widget.paciente;
  PaletaFicha get _pal => _paletas[_tab.index];

  @override
  void initState() {
    super.initState();
    _f = widget.paciente.ficha ?? FichaClinica();
    widget.paciente.ficha = _f;
    _tab = TabController(
      length: _paletas.length,
      vsync: this,
      initialIndex: widget.tabInicial.clamp(0, _paletas.length - 1),
    );
    _tab.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _cargarDoctor();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargarDoctor() async {
    final nombre = await ConfigService.obtenerNombreDoctor();
    if (mounted && nombre != null) {
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

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmar(String titulo, String texto, {String accion = 'Eliminar'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  String _relativa(DateTime d) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(d.year, d.month, d.day);
    final dias = a.difference(b).inDays;
    if (dias == 0) {
      return 'Hoy';
    }
    if (dias == 1) {
      return 'Ayer';
    }
    if (dias == -1) {
      return 'Mañana';
    }
    if (dias < 0) {
      return 'en ${-dias} días';
    }
    if (dias < 30) {
      return 'hace $dias días';
    }
    if (dias < 365) {
      final m = dias ~/ 30;
      return 'hace $m ${m == 1 ? 'mes' : 'meses'}';
    }
    final an = dias ~/ 365;
    return 'hace $an ${an == 1 ? 'año' : 'años'}';
  }

  // ------------------------------------------------------------------
  // ACCIONES
  // ------------------------------------------------------------------

  Future<void> _editarDatos() async {
    final r = await mostrarHojaDatosPersonales(context, ficha: _f);
    if (r == true && mounted) {
      _cambio();
    }
  }

  Future<void> _editarCondiciones() async {
    final r = await mostrarHojaCondiciones(context, ficha: _f);
    if (r == true && mounted) {
      _cambio();
    }
  }

  Future<void> _editarHabitos() async {
    final r = await mostrarHojaHabitos(context, ficha: _f);
    if (r == true && mounted) {
      _cambio();
    }
  }

  void _confirmarHistoria() {
    _f.historiaActualizada = DateTime.now();
    _cambio();
    _aviso('Historia médica confirmada como vigente.');
  }

  Future<void> _editarAlergia([Alergia? existente]) async {
    final r = await mostrarHojaAlergia(context, existente: existente);
    if (r == null || !mounted) {
      return;
    }
    if (r.eliminar) {
      _f.alergias.remove(existente);
    } else if (existente == null) {
      _f.alergias.add(r.valor!);
    }
    _f.historiaActualizada = DateTime.now();
    _cambio();
  }

  Future<void> _editarMedicamento([MedicamentoActual? existente]) async {
    final r = await mostrarHojaMedicamentoActual(context, existente: existente);
    if (r == null || !mounted) {
      return;
    }
    if (r.eliminar) {
      _f.medicamentos.remove(existente);
    } else if (existente == null) {
      _f.medicamentos.add(r.valor!);
    }
    _f.historiaActualizada = DateTime.now();
    _cambio();
  }

  Future<void> _editarEvolucion([Evolucion? existente]) async {
    // Se guarda cómo estaba antes de abrir la hoja (la hoja modifica el
    // objeto en el lugar al guardar).
    final previos = List<String>.from(existente?.itemsRealizados ?? const <String>[]);
    final r = await mostrarHojaEvolucion(
      context,
      paciente: _p,
      existente: existente,
    );
    if (r == null || !mounted) {
      return;
    }
    if (r.eliminar) {
      if (await _confirmar(
        'Eliminar evolución',
        'Se borrará esta nota clínica. Los tratamientos del presupuesto que se '
            'marcaron como completados seguirán así.',
      )) {
        _f.evoluciones.remove(existente);
        _cambio();
      }
      return;
    }
    final ev = r.valor!;
    if (existente == null) {
      _f.evoluciones.add(ev);
    }
    // Sincroniza el presupuesto con lo realizado en esta cita.
    var completados = 0;
    final presupuesto = _p.presupuesto;
    if (presupuesto != null) {
      for (final item in presupuesto.items) {
        final ahora = ev.itemsRealizados.contains(item.id);
        final antes = previos.contains(item.id);
        if (ahora && !antes) {
          item.cambiarEstado(EstadoTratamiento.completado);
          item.fechaRealizacion = ev.fecha;
          completados++;
        } else if (!ahora && antes && item.estado == EstadoTratamiento.completado) {
          item.cambiarEstado(EstadoTratamiento.aceptado);
        }
      }
    }
    _cambio();
    _aviso(
      completados > 0
          ? 'Evolución guardada. $completados tratamiento(s) marcado(s) como completado(s) en el presupuesto.'
          : 'Evolución guardada.',
    );
  }

  Future<void> _editarReceta([Receta? existente]) async {
    final r = await mostrarHojaReceta(context, ficha: _f, existente: existente);
    if (r == null || !mounted) {
      return;
    }
    if (r.eliminar) {
      if (await _confirmar(
        'Eliminar receta',
        'Se borrará la receta N° ${existente!.numeroTexto}. Su número no se reutiliza.',
      )) {
        _f.recetas.remove(existente);
        _cambio();
      }
      return;
    }
    if (existente == null) {
      _f.recetas.add(r.valor!);
    }
    _cambio();
    _aviso('Receta guardada.');
  }

  Future<void> _editarConsentimiento([Consentimiento? existente]) async {
    final r = await mostrarHojaConsentimiento(
      context,
      paciente: _p,
      nombreDoctor: _nombreDoctor,
      existente: existente,
    );
    if (r == null || !mounted) {
      return;
    }
    if (r.eliminar) {
      if (await _confirmar(
        'Eliminar consentimiento',
        'Se borrará este documento y su firma. Esta acción no se puede deshacer.',
      )) {
        _f.consentimientos.remove(existente);
        _cambio();
      }
      return;
    }
    if (existente == null) {
      _f.consentimientos.add(r.valor!);
    }
    _cambio();
    _aviso(r.valor!.firmado ? 'Consentimiento firmado y guardado.' : 'Consentimiento guardado (pendiente de firma).');
  }

  Future<void> _firmarPendiente(Consentimiento c) async {
    final r = await Navigator.push<ResultadoFirma>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FirmaPadPantalla(
          titulo: c.esRepresentante ? 'Firma del representante' : 'Firma del paciente',
        ),
      ),
    );
    if (r == null || !mounted) {
      return;
    }
    c.firmaTrazos = r.trazos;
    c.firmaAncho = r.ancho;
    c.firmaAlto = r.alto;
    c.firmadoEn = DateTime.now();
    _cambio();
    _aviso('Documento firmado.');
  }

  Future<void> _pdf(Future<void> Function() generar, String que) async {
    try {
      await generar();
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo generar el PDF de $que. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> _pdfFicha() => _pdf(
        () => FichaPdfService.imprimirFicha(paciente: _p, nombreDoctor: _nombreDoctor),
        'la historia clínica',
      );

  Future<void> _whatsApp(String mensaje) async {
    if (!WhatsAppService.celularValido(_p.celular)) {
      _aviso('El paciente no tiene un celular válido. Edítalo en sus datos (con código de país).');
      return;
    }
    final ok = await WhatsAppService.enviarRecordatorio(
      celular: _p.celular,
      mensaje: mensaje,
    );
    if (!ok && mounted) {
      _aviso('No se pudo abrir WhatsApp.');
    }
  }

  String get _firmaMensaje => _nombreDoctor.trim().isEmpty
      ? 'le escribimos del consultorio odontológico'
      : 'le escribe $_nombreDoctor, su odontólogo/a';

  Future<void> _recordarCita(DateTime cita) => _whatsApp(
        'Hola ${_p.nombre}, $_firmaMensaje.\n\n'
        'Le recordamos su próxima cita el ${_fecha.format(cita)}. '
        'Si necesita reprogramarla, avísenos con anticipación.\n\n¡Gracias!',
      );

  Future<void> _llamar(String telefono) async {
    final digitos = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitos.isEmpty) {
      return;
    }
    try {
      await launchUrl(Uri(scheme: 'tel', path: digitos));
    } catch (_) {
      if (mounted) {
        _aviso('No se pudo iniciar la llamada.');
      }
    }
  }

  Future<void> _abrirOdontograma() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OdontogramaListScreen(paciente: _p)),
    );
    if (mounted) {
      _cambio();
    }
  }

  Future<void> _abrirPresupuesto() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PresupuestoScreen(paciente: _p, onGuardar: widget.onGuardar),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  // ------------------------------------------------------------------
  // BLOQUES VISUALES REUTILIZABLES
  // ------------------------------------------------------------------

  Widget _tarjeta({
    required PaletaFicha pal,
    required String titulo,
    required IconData icono,
    required Widget child,
    Widget? accion,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: pal.fuerte.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [pal.suave, Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                left: BorderSide(color: pal.fuerte, width: 5),
              ),
            ),
            child: Row(
              children: [
                Icon(icono, size: 20, color: pal.oscuro),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: pal.oscuro,
                    ),
                  ),
                ),
                if (accion != null) accion,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _botonEditar(PaletaFicha pal, VoidCallback alTocar, {String texto = 'Editar', IconData icono = Icons.edit_outlined}) {
    return TextButton.icon(
      onPressed: alTocar,
      icon: Icon(icono, size: 17, color: pal.oscuro),
      label: Text(texto, style: TextStyle(color: pal.oscuro)),
    );
  }

  Widget _dato(String etiqueta, String valor, {Widget? extra}) {
    if (valor.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }

  Widget _etiqueta(String texto, Color fondo, Color letra, {IconData? icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: letra.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: letra),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              style: TextStyle(color: letra, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio(
    PaletaFicha pal,
    IconData icono,
    String titulo,
    String detalle, {
    List<Widget> acciones = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pal.suave,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 40, color: pal.fuerte),
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          if (acciones.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: acciones),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pal = _pal;
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: pal.oscuro,
        title: const Text('Ficha clínica'),
        flexibleSpace: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [pal.oscuro, pal.fuerte],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Historia clínica en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _pdfFicha,
          ),
        ],
      ),
      floatingActionButton: _fab(pal),
      body: FondoDecorativo(
        coloresGradiente: [
          pal.suave,
          Colors.white,
          pal.suave.withValues(alpha: 0.55),
        ],
        colorMuelitas: pal.fuerte,
        child: SafeArea(
          child: Column(
            children: [
              _cabecera(pal),
              _barraPestanas(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _tabResumen(),
                    _tabHistoria(),
                    _tabEvolucion(),
                    _tabRecetas(),
                    _tabConsentimientos(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _fab(PaletaFicha pal) {
    switch (_tab.index) {
      case 2:
        return FloatingActionButton.extended(
          backgroundColor: pal.fuerte,
          foregroundColor: Colors.white,
          onPressed: () => _editarEvolucion(),
          icon: const Icon(Icons.add),
          label: const Text('Nueva evolución'),
        );
      case 3:
        return FloatingActionButton.extended(
          backgroundColor: pal.fuerte,
          foregroundColor: Colors.white,
          onPressed: () => _editarReceta(),
          icon: const Icon(Icons.add),
          label: const Text('Nueva receta'),
        );
      case 4:
        return FloatingActionButton.extended(
          backgroundColor: pal.fuerte,
          foregroundColor: Colors.white,
          onPressed: () => _editarConsentimiento(),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo consentimiento'),
        );
      default:
        return null;
    }
  }

  // ---------------- Cabecera con alertas ----------------

  Widget _avatar() {
    final ruta = _p.fotoPerfil;
    final inicial = _p.nombre.trim().isEmpty ? '?' : _p.nombre.trim()[0].toUpperCase();
    Widget iniciales() => Center(
          child: Text(
            inicial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: (ruta != null && ruta.isNotEmpty)
          ? Image.file(
              File(ruta),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => iniciales(),
            )
          : iniciales(),
    );
  }

  Widget _cabecera(PaletaFicha pal) {
    final edad = _f.edad;
    final sub = [
      if (edad != null) '$edad años',
      if (_f.sexo != null) etiquetaSexo[_f.sexo]!,
      if (_p.cedula.isNotEmpty) 'C.I. ${_p.cedula}',
    ].join('  ·  ');
    final chips = <Widget>[];
    for (final a in _f.alergiasOrdenadas) {
      final grave = a.severidad == SeveridadAlergia.grave;
      chips.add(
        _etiqueta(
          'Alergia: ${a.descripcion}',
          grave ? Colors.red.shade700 : Colors.white,
          grave ? Colors.white : Colors.red.shade800,
          icono: Icons.warning_amber_rounded,
        ),
      );
    }
    for (final c in _f.condicionesDeAlerta) {
      chips.add(_etiqueta(c, Colors.white, Colors.red.shade800, icono: Icons.favorite_border));
    }
    if (_f.condicionesOtras.trim().isNotEmpty) {
      chips.add(_etiqueta(_f.condicionesOtras.trim(), Colors.white, Colors.orange.shade900));
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: pal.degradado,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: pal.fuerte.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _p.nombre.isEmpty ? 'Paciente sin nombre' : _p.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                        ),
                      ),
                    if (_p.celular.isNotEmpty)
                      Text(
                        _p.celular,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (_p.celular.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Llamar',
                  onPressed: () => _llamar(_p.celular),
                  icon: const Icon(Icons.call, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  onPressed: () => _whatsApp('Hola ${_p.nombre}, $_firmaMensaje.'),
                  icon: const Icon(Icons.chat, color: Colors.white),
                ),
              ],
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ] else if (!_f.tieneHistoriaMedica) ...[
            const SizedBox(height: 10),
            _etiqueta(
              'Historia médica sin completar',
              Colors.amber.shade100,
              Colors.orange.shade900,
              icono: Icons.info_outline,
            ),
          ],
        ],
      ),
    );
  }

  Widget _barraPestanas() {
    final n = [
      null,
      _f.alergias.length + _f.condicionesDeAlerta.length,
      _f.evoluciones.length,
      _f.recetas.length,
      _f.consentimientos.length,
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          gradient: _pal.degradado,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _pal.fuerte.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (var i = 0; i < _paletas.length; i++)
            Tab(
              height: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paletas[i].icono,
                      size: 18,
                      color: _tab.index == i ? Colors.white : _paletas[i].fuerte,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      n[i] == null || n[i] == 0
                          ? _paletas[i].nombre
                          : '${_paletas[i].nombre} (${n[i]})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _tab.index == i ? Colors.white : _paletas[i].oscuro,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================================================================
  // PESTAÑA 0: RESUMEN
  // ==================================================================

  Widget _tabResumen() {
    const pal = paletaResumen;
    final proximas = _f.proximasCitas;
    final ultima = _f.evolucionesOrdenadas.isEmpty ? null : _f.evolucionesOrdenadas.first;
    final presupuesto = _p.presupuesto;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
      children: [
        if (_f.historiaPorRevisar && _f.tieneHistoriaMedica) _bannerRevision(),
        // Acciones rápidas
        _tarjeta(
          pal: pal,
          titulo: 'Acciones rápidas',
          icono: Icons.bolt,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _accionRapida(paletaEvolucion, Icons.edit_note, 'Nueva evolución',
                  () => _editarEvolucion()),
              _accionRapida(paletaReceta, Icons.medication_outlined, 'Nueva receta',
                  () => _editarReceta()),
              _accionRapida(paletaConsent, Icons.draw_outlined, 'Consentimiento',
                  () => _editarConsentimiento()),
              _accionRapida(paletaMedica, Icons.warning_amber_rounded, 'Alergia',
                  () => _editarAlergia()),
              _accionRapida(paletaResumen, Icons.grid_view, 'Odontograma', _abrirOdontograma),
              _accionRapida(
                const PaletaFicha('', Icons.attach_money, Color(0xFFFFA726),
                    Color(0xFFEF6C00), Color(0xFFFFF3E0)),
                Icons.attach_money,
                'Presupuesto',
                _abrirPresupuesto,
              ),
            ],
          ),
        ),
        // Datos del paciente
        _tarjeta(
          pal: pal,
          titulo: 'Datos del paciente',
          icono: Icons.badge_outlined,
          accion: _botonEditar(pal, _editarDatos),
          child: _contenidoDatos(),
        ),
        // Próxima cita
        if (proximas.isNotEmpty)
          _tarjeta(
            pal: paletaEvolucion,
            titulo: 'Próxima cita',
            icono: Icons.event_available,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: paletaEvolucion.degradado,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${proximas.first.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MM/yyyy').format(proximas.first),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _relativa(proximas.first),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(_fecha.format(proximas.first),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _recordarCita(proximas.first),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Recordar'),
                ),
              ],
            ),
          ),
        // Plan de tratamiento
        _tarjeta(
          pal: const PaletaFicha('', Icons.attach_money, Color(0xFFFFA726),
              Color(0xFFEF6C00), Color(0xFFFFF3E0)),
          titulo: 'Plan de tratamiento',
          icono: Icons.checklist,
          accion: _botonEditar(
            const PaletaFicha('', Icons.attach_money, Color(0xFFFFA726),
                Color(0xFFEF6C00), Color(0xFFFFF3E0)),
            _abrirPresupuesto,
            texto: 'Abrir',
            icono: Icons.open_in_new,
          ),
          child: _contenidoPlan(presupuesto),
        ),
        // Última evolución
        _tarjeta(
          pal: paletaEvolucion,
          titulo: 'Última evolución',
          icono: Icons.timeline,
          accion: ultima == null
              ? null
              : _botonEditar(paletaEvolucion, () => _tab.animateTo(2),
                  texto: 'Ver todas', icono: Icons.arrow_forward),
          child: ultima == null
              ? const Text('Todavía no hay evoluciones registradas.',
                  style: TextStyle(color: Colors.black54))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_fecha.format(ultima.fecha)}  ·  ${_relativa(ultima.fecha)}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ultima.procedimiento,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (ultima.observaciones.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          ultima.observaciones,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _bannerRevision() {
    final dias = _f.diasDesdeConfirmacion;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dias == null
                      ? 'La historia médica nunca se ha confirmado con el paciente.'
                      : 'La historia médica se revisó por última vez hace $dias días.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pregúntale si cambió algo (medicamentos, enfermedades, alergias, embarazo).',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _tab.animateTo(1),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Revisar'),
              ),
              FilledButton.icon(
                onPressed: _confirmarHistoria,
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Sigue igual'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accionRapida(PaletaFicha pal, IconData icono, String texto, VoidCallback alTocar) {
    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: pal.degradado,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: pal.fuerte.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icono, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                texto,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenidoDatos() {
    final hay = _f.fechaNacimiento != null ||
        _f.sexo != null ||
        _f.ocupacion.isNotEmpty ||
        _f.direccion.isNotEmpty ||
        _f.correo.isNotEmpty ||
        _f.referidoPor.isNotEmpty ||
        _f.contactoNombre.isNotEmpty ||
        _f.contactoTelefono.isNotEmpty ||
        _f.motivoConsulta.isNotEmpty ||
        _f.enfermedadActual.isNotEmpty;
    if (!hay) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Completa fecha de nacimiento, contacto de emergencia y motivo de consulta.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          FilledButton(
            onPressed: _editarDatos,
            style: FilledButton.styleFrom(backgroundColor: paletaResumen.fuerte),
            child: const Text('Completar'),
          ),
        ],
      );
    }
    final contacto = [
      _f.contactoNombre,
      if (_f.contactoParentesco.isNotEmpty) '(${_f.contactoParentesco})',
    ].where((e) => e.trim().isNotEmpty).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dato(
          'Nacimiento',
          _f.fechaNacimiento == null
              ? ''
              : '${_fecha.format(_f.fechaNacimiento!)}'
                  '${_f.edad == null ? '' : '  (${_f.edad} años)'}',
        ),
        _dato('Sexo', _f.sexo == null ? '' : etiquetaSexo[_f.sexo]!),
        _dato('Ocupación', _f.ocupacion),
        _dato('Dirección', _f.direccion),
        _dato('Correo', _f.correo),
        _dato('Referido por', _f.referidoPor),
        _dato(
          'Emergencia',
          [contacto, _f.contactoTelefono].where((e) => e.isNotEmpty).join('\n'),
          extra: _f.contactoTelefono.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Llamar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.call, size: 20, color: paletaResumen.fuerte),
                  onPressed: () => _llamar(_f.contactoTelefono),
                ),
        ),
        if (_f.motivoConsulta.isNotEmpty) ...[
          const Divider(height: 18),
          const Text('Motivo de consulta',
              style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          Text(_f.motivoConsulta),
        ],
        if (_f.enfermedadActual.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Enfermedad actual',
              style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          Text(_f.enfermedadActual),
        ],
      ],
    );
  }

  Widget _contenidoPlan(Presupuesto? presupuesto) {
    if (presupuesto == null || presupuesto.items.isEmpty) {
      return const Text(
        'Aún no hay un presupuesto. Genéralo desde el odontograma.',
        style: TextStyle(color: Colors.black54),
      );
    }
    final activos = presupuesto.itemsActivos.length;
    final hechos = presupuesto.cantidadCompletados;
    final progreso = activos == 0 ? 0.0 : hechos / activos;
    final pendientes = presupuesto.items
        .where((i) =>
            i.estado == EstadoTratamiento.pendiente ||
            i.estado == EstadoTratamiento.aceptado ||
            i.estado == EstadoTratamiento.enProgreso)
        .take(4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$hechos de $activos realizados',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'Saldo ${formatoMoneda(presupuesto.saldo > 0 ? presupuesto.saldo : 0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: presupuesto.saldo > 0.004 ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 8,
            backgroundColor: const Color(0xFFFFF3E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFA726)),
          ),
        ),
        if (pendientes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Por hacer', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          for (final i in pendientes)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(colorEstadoTratamiento[i.estado]!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i.descripcion, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ==================================================================
  // PESTAÑA 1: HISTORIA MÉDICA
  // ==================================================================

  Widget _tabHistoria() {
    const pal = paletaMedica;
    final alergias = _f.alergiasOrdenadas;
    final condiciones = [
      for (final c in catalogoCondiciones)
        if (_f.condiciones.contains(c.clave)) c,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
      children: [
        if (_f.historiaPorRevisar && _f.tieneHistoriaMedica) _bannerRevision(),
        // Alergias
        _tarjeta(
          pal: pal,
          titulo: 'Alergias',
          icono: Icons.warning_amber_rounded,
          accion: _botonEditar(pal, () => _editarAlergia(),
              texto: 'Agregar', icono: Icons.add),
          child: alergias.isEmpty
              ? const Text('Ninguna alergia registrada.',
                  style: TextStyle(color: Colors.black54))
              : Column(
                  children: [for (final a in alergias) _filaAlergia(a)],
                ),
        ),
        // Condiciones
        _tarjeta(
          pal: pal,
          titulo: 'Condiciones y antecedentes',
          icono: Icons.health_and_safety_outlined,
          accion: _botonEditar(pal, _editarCondiciones),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (condiciones.isEmpty && _f.condicionesOtras.trim().isEmpty)
                const Text('Sin condiciones médicas registradas.',
                    style: TextStyle(color: Colors.black54))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in condiciones)
                      _etiqueta(
                        c.etiqueta,
                        c.alerta ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2),
                        c.alerta ? Colors.red.shade800 : Colors.orange.shade900,
                      ),
                    if (_f.condicionesOtras.trim().isNotEmpty)
                      _etiqueta(_f.condicionesOtras.trim(), const Color(0xFFFFE0B2),
                          Colors.orange.shade900),
                  ],
                ),
              const SizedBox(height: 8),
              _dato('Grupo sanguíneo', _f.grupoSanguineo),
              _dato('Cirugías', _f.cirugias),
              _dato('Fam. relevantes', _f.antecedentesFamiliares),
              _dato('Observaciones', _f.observacionesMedicas),
              if (_f.historiaActualizada != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Revisada el ${_fecha.format(_f.historiaActualizada!)} (${_relativa(_f.historiaActualizada!)})',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              if (_f.tieneHistoriaMedica && !_f.historiaPorRevisar)
                const SizedBox.shrink()
              else if (_f.tieneHistoriaMedica)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    onPressed: _confirmarHistoria,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirmar que sigue vigente'),
                  ),
                ),
            ],
          ),
        ),
        // Medicación
        _tarjeta(
          pal: pal,
          titulo: 'Medicación actual',
          icono: Icons.medication_liquid_outlined,
          accion: _botonEditar(pal, () => _editarMedicamento(),
              texto: 'Agregar', icono: Icons.add),
          child: _f.medicamentos.isEmpty
              ? const Text('No toma medicamentos registrados.',
                  style: TextStyle(color: Colors.black54))
              : Column(
                  children: [
                    for (final m in _f.medicamentos)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _editarMedicamento(m),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: pal.suave,
                          child: Icon(Icons.medication, size: 18, color: pal.fuerte),
                        ),
                        title: Text(m.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [m.dosis, m.motivo].where((e) => e.isNotEmpty).join('  ·  '),
                        ),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                      ),
                  ],
                ),
        ),
        // Hábitos
        _tarjeta(
          pal: paletaEvolucion,
          titulo: 'Hábitos y salud bucal',
          icono: Icons.sentiment_satisfied_alt_outlined,
          accion: _botonEditar(paletaEvolucion, _editarHabitos),
          child: _contenidoHabitos(),
        ),
      ],
    );
  }

  Widget _filaAlergia(Alergia a) {
    final color = {
      SeveridadAlergia.leve: Colors.green.shade700,
      SeveridadAlergia.moderada: Colors.orange.shade800,
      SeveridadAlergia.grave: Colors.red.shade700,
    }[a.severidad]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        dense: true,
        onTap: () => _editarAlergia(a),
        leading: Icon(Icons.warning_amber_rounded, color: color),
        title: Text(a.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [
            etiquetaTipoAlergia[a.tipo]!,
            if (a.reaccion.isNotEmpty) a.reaccion,
          ].join('  ·  '),
        ),
        trailing: _etiqueta(etiquetaSeveridad[a.severidad]!, Colors.white, color),
      ),
    );
  }

  Widget _contenidoHabitos() {
    final hay = _f.cepilladosDia > 0 ||
        _f.tabaco != NivelHabito.ninguno ||
        _f.alcohol != NivelHabito.ninguno ||
        _f.usaHilo ||
        _f.usaEnjuague ||
        _f.bruxismo ||
        _f.sangradoEncias ||
        _f.sensibilidad ||
        _f.ortodonciaPrevia ||
        _f.ansiedadDental > 0 ||
        _f.ultimaVisita.isNotEmpty ||
        _f.experienciasPrevias.isNotEmpty;
    if (!hay) {
      return const Text('Aún sin datos de hábitos ni antecedentes odontológicos.',
          style: TextStyle(color: Colors.black54));
    }
    const p = paletaEvolucion;
    Widget si(String t, bool v, {bool malo = false}) => _etiqueta(
          t,
          v ? (malo ? const Color(0xFFFFE0B2) : p.suave) : Colors.grey.shade100,
          v ? (malo ? Colors.orange.shade900 : p.oscuro) : Colors.black45,
          icono: v ? Icons.check_circle_outline : Icons.remove_circle_outline,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (_f.cepilladosDia > 0)
              _etiqueta('${_f.cepilladosDia} cepillado(s)/día', p.suave, p.oscuro,
                  icono: Icons.brush_outlined),
            si('Hilo dental', _f.usaHilo),
            si('Enjuague', _f.usaEnjuague),
            si('Bruxismo', _f.bruxismo, malo: true),
            si('Sangrado de encías', _f.sangradoEncias, malo: true),
            si('Sensibilidad', _f.sensibilidad, malo: true),
            si('Ortodoncia previa', _f.ortodonciaPrevia),
            if (_f.tabaco != NivelHabito.ninguno)
              _etiqueta('Fuma: ${etiquetaNivelHabito[_f.tabaco]!.toLowerCase()}',
                  const Color(0xFFFFE0B2), Colors.orange.shade900,
                  icono: Icons.smoking_rooms_outlined),
            if (_f.alcohol != NivelHabito.ninguno)
              _etiqueta('Alcohol: ${etiquetaNivelHabito[_f.alcohol]!.toLowerCase()}',
                  const Color(0xFFFFE0B2), Colors.orange.shade900,
                  icono: Icons.local_bar_outlined),
            if (_f.ansiedadDental > 0)
              _etiqueta('Ansiedad dental ${_f.ansiedadDental}/5',
                  _f.ansiedadDental >= 4 ? const Color(0xFFFFCDD2) : p.suave,
                  _f.ansiedadDental >= 4 ? Colors.red.shade800 : p.oscuro,
                  icono: Icons.mood_bad_outlined),
          ],
        ),
        const SizedBox(height: 8),
        _dato('Última visita', _f.ultimaVisita),
        _dato('Experiencias', _f.experienciasPrevias),
      ],
    );
  }

  // ==================================================================
  // PESTAÑA 2: EVOLUCIÓN
  // ==================================================================

  Widget _tabEvolucion() {
    const pal = paletaEvolucion;
    final lista = _f.evolucionesOrdenadas;
    if (lista.isEmpty) {
      return ListView(
        children: [
          _vacio(
            pal,
            Icons.timeline,
            'Aún no hay evoluciones',
            'Registra lo que se hizo en cada cita: procedimiento, anestesia, notas e indicaciones. '
                'Si eliges tratamientos del presupuesto, se marcan como completados.',
            acciones: [
              FilledButton.icon(
                onPressed: () => _editarEvolucion(),
                style: FilledButton.styleFrom(backgroundColor: pal.fuerte),
                icon: const Icon(Icons.add),
                label: const Text('Registrar primera evolución'),
              ),
            ],
          ),
        ],
      );
    }
    final proximas = _f.proximasCitas;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [pal.suave, Colors.white]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.fuerte.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              _cifraResumen('${lista.length}', lista.length == 1 ? 'visita' : 'visitas', pal),
              _cifraResumen(_relativa(lista.first.fecha), 'última', pal),
              _cifraResumen(
                proximas.isEmpty ? '-' : _fecha.format(proximas.first),
                'próxima cita',
                pal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < lista.length; i++)
          _lineaTiempo(lista[i], primero: i == 0, ultimo: i == lista.length - 1),
      ],
    );
  }

  Widget _cifraResumen(String valor, String etiqueta, PaletaFicha pal) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: pal.oscuro,
              ),
            ),
          ),
          Text(etiqueta, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _lineaTiempo(Evolucion e, {required bool primero, required bool ultimo}) {
    const pal = paletaEvolucion;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 14,
                  color: primero ? Colors.transparent : pal.fuerte.withValues(alpha: 0.4),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: pal.degradado,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: pal.fuerte.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: ultimo ? Colors.transparent : pal.fuerte.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _tarjetaEvolucion(e)),
        ],
      ),
    );
  }

  Widget _tarjetaEvolucion(Evolucion e) {
    const pal = paletaEvolucion;
    final detalles = <String>[
      if (e.piezas.isNotEmpty) 'Piezas: ${e.piezas}',
      if (e.anestesia.isNotEmpty) 'Anestesia: ${e.anestesia}',
      if (e.presionArterial.isNotEmpty) 'PA: ${e.presionArterial}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: pal.fuerte.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editarEvolucion(e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _etiqueta(_fecha.format(e.fecha), pal.suave, pal.oscuro,
                      icono: Icons.event),
                  const SizedBox(width: 8),
                  Text(_relativa(e.fecha),
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'editar') {
                        _editarEvolucion(e);
                      } else if (v == 'cita' && e.proximaCita != null) {
                        _recordarCita(e.proximaCita!);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar / eliminar'),
                        ),
                      ),
                      if (e.proximaCita != null)
                        const PopupMenuItem(
                          value: 'cita',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.chat_outlined),
                            title: Text('Recordar próxima cita'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  e.procedimiento,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (detalles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    detalles.join('  ·  '),
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ),
              if (e.descripcionItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final d in e.descripcionItems)
                        _etiqueta(d, const Color(0xFFE8F5E9), Colors.green.shade800,
                            icono: Icons.check_circle_outline),
                    ],
                  ),
                ),
              if (e.observaciones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Text(e.observaciones),
                ),
              if (e.indicaciones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pal.suave.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Indicaciones: ${e.indicaciones}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              if (e.proximaCita != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _etiqueta(
                    'Próxima cita: ${_fecha.format(e.proximaCita!)}',
                    const Color(0xFFE3F2FD),
                    Colors.blue.shade800,
                    icono: Icons.event_available,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // PESTAÑA 3: RECETAS
  // ==================================================================

  Widget _tabRecetas() {
    const pal = paletaReceta;
    final lista = List<Receta>.from(_f.recetas)
      ..sort((a, b) => b.numero.compareTo(a.numero));
    if (lista.isEmpty) {
      return ListView(
        children: [
          _vacio(
            pal,
            Icons.medication_outlined,
            'Sin recetas emitidas',
            'Crea una receta con medicamento, posología e indicaciones. '
                'Te avisa si algún medicamento coincide con una alergia registrada.',
            acciones: [
              FilledButton.icon(
                onPressed: () => _editarReceta(),
                style: FilledButton.styleFrom(backgroundColor: pal.fuerte),
                icon: const Icon(Icons.add),
                label: const Text('Crear primera receta'),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
      children: [for (final r in lista) _tarjetaReceta(r)],
    );
  }

  Widget _tarjetaReceta(Receta r) {
    const pal = paletaReceta;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: pal.fuerte.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editarReceta(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(gradient: pal.degradado),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receta N° ${r.numeroTexto}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _fecha.format(r.fecha),
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Imprimir / compartir PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                    onPressed: () => _pdf(
                      () => FichaPdfService.imprimirReceta(
                        paciente: _p,
                        receta: r,
                        nombreDoctor: _nombreDoctor,
                      ),
                      'la receta',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.diagnostico.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Dx: ${r.diagnostico}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                      ),
                    ),
                  for (var i = 0; i < r.items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: pal.suave,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(fontSize: 11, color: pal.oscuro),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.items[i].nombre}'
                                  '${r.items[i].presentacion.isEmpty ? '' : '  ·  ${r.items[i].presentacion}'}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  [
                                    r.items[i].posologia,
                                    if (r.items[i].duracion.isNotEmpty) r.items[i].duracion,
                                  ].join('  ·  '),
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // PESTAÑA 4: CONSENTIMIENTOS
  // ==================================================================

  Widget _tabConsentimientos() {
    const pal = paletaConsent;
    final lista = List<Consentimiento>.from(_f.consentimientos)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    if (lista.isEmpty) {
      return ListView(
        children: [
          _vacio(
            pal,
            Icons.draw_outlined,
            'Sin consentimientos',
            'Elige una plantilla (tratamiento general, extracción, endodoncia, anestesia, '
                'blanqueamiento, implantes o menores de edad) y el paciente firma con el dedo en la pantalla.',
            acciones: [
              FilledButton.icon(
                onPressed: () => _editarConsentimiento(),
                style: FilledButton.styleFrom(backgroundColor: pal.fuerte),
                icon: const Icon(Icons.add),
                label: const Text('Crear consentimiento'),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
      children: [for (final c in lista) _tarjetaConsentimiento(c)],
    );
  }

  Widget _tarjetaConsentimiento(Consentimiento c) {
    const pal = paletaConsent;
    final firmado = c.firmado;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: pal.fuerte.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editarConsentimiento(c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: pal.degradado,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '${_fecha.format(c.fecha)}'
                          '${c.nombreFirmante.isEmpty ? '' : '  ·  ${c.nombreFirmante}'}'
                          '${c.esRepresentante ? ' (representante)' : ''}',
                          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  _etiqueta(
                    firmado ? 'Firmado' : 'Pendiente',
                    firmado ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                    firmado ? Colors.green.shade800 : Colors.orange.shade900,
                    icono: firmado ? Icons.verified_outlined : Icons.hourglass_bottom,
                  ),
                ],
              ),
              if (firmado) ...[
                const SizedBox(height: 10),
                FirmaVista(consentimiento: c, alto: 64),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (!firmado)
                    FilledButton.icon(
                      onPressed: () => _firmarPendiente(c),
                      style: FilledButton.styleFrom(backgroundColor: pal.fuerte),
                      icon: const Icon(Icons.draw, size: 18),
                      label: const Text('Firmar ahora'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _pdf(
                      () => FichaPdfService.imprimirConsentimiento(
                        paciente: _p,
                        consentimiento: c,
                        nombreDoctor: _nombreDoctor,
                      ),
                      'el consentimiento',
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
