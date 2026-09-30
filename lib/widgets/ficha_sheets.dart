import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/ficha_clinica.dart';
import '../models/paciente.dart';
import '../models/presupuesto.dart';
import 'firma_pad.dart';

// ---------------------------------------------------------------------------
// Paleta de colores por sección
// ---------------------------------------------------------------------------

class PaletaFicha {
  final String nombre;
  final IconData icono;
  final Color fuerte;
  final Color oscuro;
  final Color suave;
  const PaletaFicha(this.nombre, this.icono, this.fuerte, this.oscuro, this.suave);

  LinearGradient get degradado => LinearGradient(
        colors: [fuerte, oscuro],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const PaletaFicha paletaResumen = PaletaFicha(
  'Resumen', Icons.dashboard_outlined,
  Color(0xFFEC407A), Color(0xFFAD1457), Color(0xFFFFE4EC),
);
const PaletaFicha paletaMedica = PaletaFicha(
  'Historia', Icons.monitor_heart_outlined,
  Color(0xFFEF5350), Color(0xFFC62828), Color(0xFFFFEBEE),
);
const PaletaFicha paletaEvolucion = PaletaFicha(
  'Evolución', Icons.timeline,
  Color(0xFF26A69A), Color(0xFF00796B), Color(0xFFE0F2F1),
);
const PaletaFicha paletaReceta = PaletaFicha(
  'Recetas', Icons.medication_outlined,
  Color(0xFF42A5F5), Color(0xFF1565C0), Color(0xFFE3F2FD),
);
const PaletaFicha paletaConsent = PaletaFicha(
  'Consentimientos', Icons.draw_outlined,
  Color(0xFF7E57C2), Color(0xFF4527A0), Color(0xFFEDE7F6),
);

/// Resultado de una hoja de edición de un elemento de lista.
class ResultadoEdicion<T> {
  final T? valor;
  final bool eliminar;
  ResultadoEdicion.guardar(T this.valor) : eliminar = false;
  ResultadoEdicion.eliminar()
      : valor = null,
        eliminar = true;
}

final DateFormat _fmtFecha = DateFormat('dd/MM/yyyy');
const Uuid _uuid = Uuid();

// ---------------------------------------------------------------------------
// Piezas comunes
// ---------------------------------------------------------------------------

Future<T?> _hoja<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: builder,
  );
}

class _Marco extends StatelessWidget {
  final String titulo;
  final PaletaFicha paleta;
  final IconData? icono;
  final Widget child;
  const _Marco({
    required this.titulo,
    required this.paleta,
    required this.child,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.93),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  decoration: BoxDecoration(
                    gradient: paleta.degradado,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(icono ?? paleta.icono, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _campo(
  TextEditingController c,
  String label, {
  int maxLines = 1,
  TextInputType? tipo,
  String? hint,
  TextCapitalization cap = TextCapitalization.sentences,
  ValueChanged<String>? onChanged,
  List<TextInputFormatter>? formatters,
  IconData? icono,
}) {
  return TextField(
    controller: c,
    maxLines: maxLines,
    minLines: maxLines > 1 ? 2 : 1,
    keyboardType: tipo,
    textCapitalization: cap,
    onChanged: onChanged,
    inputFormatters: formatters,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icono == null ? null : Icon(icono, size: 20),
    ),
  );
}

Widget _seccion(String texto, PaletaFicha paleta) {
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: paleta.fuerte,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: paleta.oscuro,
          ),
        ),
      ],
    ),
  );
}

Widget _atajos(
  List<String> textos,
  ValueChanged<String> alTocar,
  PaletaFicha paleta,
) {
  return Wrap(
    spacing: 6,
    runSpacing: 0,
    children: [
      for (final t in textos)
        ActionChip(
          label: Text(t, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          backgroundColor: paleta.suave,
          side: BorderSide(color: paleta.fuerte.withValues(alpha: 0.35)),
          onPressed: () => alTocar(t),
        ),
    ],
  );
}

Widget _fila<T>(
  List<T> valores,
  T? actual,
  String Function(T) etiqueta,
  ValueChanged<T> alElegir,
  PaletaFicha paleta,
) {
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final v in valores)
        ChoiceChip(
          label: Text(etiqueta(v)),
          selected: actual == v,
          selectedColor: paleta.suave,
          checkmarkColor: paleta.oscuro,
          side: BorderSide(
            color: actual == v ? paleta.fuerte : Colors.black12,
          ),
          onSelected: (_) => alElegir(v),
        ),
    ],
  );
}

Widget _botonGuardar(String texto, VoidCallback alTocar, PaletaFicha paleta) {
  return FilledButton.icon(
    onPressed: alTocar,
    style: FilledButton.styleFrom(
      backgroundColor: paleta.fuerte,
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    icon: const Icon(Icons.check),
    label: Text(texto),
  );
}

Widget _mensajeError(String? texto) => texto == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(texto, style: const TextStyle(color: Colors.red)),
      );

Future<DateTime?> _elegirFecha(
  BuildContext context,
  DateTime inicial, {
  DateTime? primera,
  DateTime? ultima,
  String? ayuda,
}) {
  return showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: primera ?? DateTime(1920),
    lastDate: ultima ?? DateTime(2100),
    helpText: ayuda,
  );
}

// ===========================================================================
// 1. DATOS PERSONALES
// ===========================================================================

/// Devuelve true si se guardaron cambios (la ficha se modifica en el lugar).
Future<bool?> mostrarHojaDatosPersonales(
  BuildContext context, {
  required FichaClinica ficha,
}) {
  return _hoja<bool>(context, (_) => _HojaDatos(ficha: ficha));
}

class _HojaDatos extends StatefulWidget {
  final FichaClinica ficha;
  const _HojaDatos({required this.ficha});

  @override
  State<_HojaDatos> createState() => _HojaDatosState();
}

class _HojaDatosState extends State<_HojaDatos> {
  late final TextEditingController _ocupacion;
  late final TextEditingController _direccion;
  late final TextEditingController _correo;
  late final TextEditingController _referido;
  late final TextEditingController _contNombre;
  late final TextEditingController _contParentesco;
  late final TextEditingController _contTelefono;
  late final TextEditingController _motivo;
  late final TextEditingController _actual;
  DateTime? _nacimiento;
  Sexo? _sexo;

  @override
  void initState() {
    super.initState();
    final f = widget.ficha;
    _ocupacion = TextEditingController(text: f.ocupacion);
    _direccion = TextEditingController(text: f.direccion);
    _correo = TextEditingController(text: f.correo);
    _referido = TextEditingController(text: f.referidoPor);
    _contNombre = TextEditingController(text: f.contactoNombre);
    _contParentesco = TextEditingController(text: f.contactoParentesco);
    _contTelefono = TextEditingController(text: f.contactoTelefono);
    _motivo = TextEditingController(text: f.motivoConsulta);
    _actual = TextEditingController(text: f.enfermedadActual);
    _nacimiento = f.fechaNacimiento;
    _sexo = f.sexo;
  }

  @override
  void dispose() {
    for (final c in [
      _ocupacion, _direccion, _correo, _referido, _contNombre,
      _contParentesco, _contTelefono, _motivo, _actual,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirNacimiento() async {
    final hoy = DateTime.now();
    final f = await _elegirFecha(
      context,
      _nacimiento ?? DateTime(hoy.year - 30, hoy.month, hoy.day),
      primera: DateTime(1900),
      ultima: hoy,
      ayuda: 'Fecha de nacimiento',
    );
    if (f != null) {
      setState(() => _nacimiento = f);
    }
  }

  int? get _edad {
    final n = _nacimiento;
    if (n == null) {
      return null;
    }
    final hoy = DateTime.now();
    var e = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) {
      e--;
    }
    return e;
  }

  void _guardar() {
    final f = widget.ficha;
    f.fechaNacimiento = _nacimiento;
    f.sexo = _sexo;
    f.ocupacion = _ocupacion.text.trim();
    f.direccion = _direccion.text.trim();
    f.correo = _correo.text.trim();
    f.referidoPor = _referido.text.trim();
    f.contactoNombre = _contNombre.text.trim();
    f.contactoParentesco = _contParentesco.text.trim();
    f.contactoTelefono = _contTelefono.text.trim();
    f.motivoConsulta = _motivo.text.trim();
    f.enfermedadActual = _actual.text.trim();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaResumen;
    final edad = _edad;
    return _Marco(
      titulo: 'Datos del paciente',
      paleta: p,
      icono: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccion('Datos personales', p),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _elegirNacimiento,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha de nacimiento',
                prefixIcon: Icon(Icons.cake_outlined, size: 20),
              ),
              child: Text(
                _nacimiento == null
                    ? 'Toca para elegir'
                    : '${_fmtFecha.format(_nacimiento!)}'
                        '${edad == null ? '' : '   ($edad años)'}',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _fila<Sexo>(
            Sexo.values, _sexo, (s) => etiquetaSexo[s]!,
            (s) => setState(() => _sexo = _sexo == s ? null : s), p,
          ),
          const SizedBox(height: 10),
          _campo(_ocupacion, 'Ocupación', icono: Icons.work_outline),
          const SizedBox(height: 10),
          _campo(_direccion, 'Dirección', icono: Icons.home_outlined),
          const SizedBox(height: 10),
          _campo(
            _correo, 'Correo electrónico',
            tipo: TextInputType.emailAddress,
            cap: TextCapitalization.none,
            icono: Icons.email_outlined,
          ),
          const SizedBox(height: 10),
          _campo(_referido, '¿Cómo nos conoció? / Referido por',
              icono: Icons.campaign_outlined),
          _seccion('Contacto de emergencia', p),
          _campo(_contNombre, 'Nombre',
              cap: TextCapitalization.words, icono: Icons.person_outline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _campo(_contParentesco, 'Parentesco',
                    cap: TextCapitalization.words),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campo(_contTelefono, 'Teléfono', tipo: TextInputType.phone),
              ),
            ],
          ),
          _seccion('Consulta', p),
          _campo(_motivo, 'Motivo de consulta',
              maxLines: 3, hint: 'Con sus propias palabras, ¿por qué viene?'),
          const SizedBox(height: 10),
          _campo(_actual, 'Enfermedad o problema actual',
              maxLines: 3, hint: 'Desde cuándo, cómo empezó, qué lo mejora o empeora'),
          const SizedBox(height: 16),
          _botonGuardar('Guardar datos', _guardar, p),
        ],
      ),
    );
  }
}

// ===========================================================================
// 2. CONDICIONES Y ANTECEDENTES MÉDICOS
// ===========================================================================

Future<bool?> mostrarHojaCondiciones(
  BuildContext context, {
  required FichaClinica ficha,
}) {
  return _hoja<bool>(context, (_) => _HojaCondiciones(ficha: ficha));
}

class _HojaCondiciones extends StatefulWidget {
  final FichaClinica ficha;
  const _HojaCondiciones({required this.ficha});

  @override
  State<_HojaCondiciones> createState() => _HojaCondicionesState();
}

class _HojaCondicionesState extends State<_HojaCondiciones> {
  late final Set<String> _condiciones;
  late final TextEditingController _otras;
  late final TextEditingController _cirugias;
  late final TextEditingController _familiares;
  late final TextEditingController _observaciones;
  late String _grupo;

  @override
  void initState() {
    super.initState();
    final f = widget.ficha;
    _condiciones = Set<String>.from(f.condiciones);
    _otras = TextEditingController(text: f.condicionesOtras);
    _cirugias = TextEditingController(text: f.cirugias);
    _familiares = TextEditingController(text: f.antecedentesFamiliares);
    _observaciones = TextEditingController(text: f.observacionesMedicas);
    _grupo = f.grupoSanguineo;
  }

  @override
  void dispose() {
    _otras.dispose();
    _cirugias.dispose();
    _familiares.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  void _guardar() {
    final f = widget.ficha;
    f.condiciones
      ..clear()
      ..addAll(_condiciones);
    f.condicionesOtras = _otras.text.trim();
    f.cirugias = _cirugias.text.trim();
    f.antecedentesFamiliares = _familiares.text.trim();
    f.observacionesMedicas = _observaciones.text.trim();
    f.grupoSanguineo = _grupo;
    // Al guardar, la doctora acaba de revisar la historia con el paciente.
    f.historiaActualizada = DateTime.now();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaMedica;
    return _Marco(
      titulo: 'Condiciones y antecedentes',
      paleta: p,
      icono: Icons.health_and_safety_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Marca lo que el paciente confirma. Las condiciones en rojo cambian '
            'la forma de atender y se destacan arriba de la ficha.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          _seccion('¿Tiene o ha tenido…?', p),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final c in catalogoCondiciones)
                FilterChip(
                  label: Text(c.etiqueta, style: const TextStyle(fontSize: 12.5)),
                  selected: _condiciones.contains(c.clave),
                  selectedColor: c.alerta
                      ? const Color(0xFFFFCDD2)
                      : const Color(0xFFFFE0B2),
                  checkmarkColor: c.alerta ? Colors.red.shade800 : Colors.orange.shade900,
                  side: BorderSide(
                    color: _condiciones.contains(c.clave)
                        ? (c.alerta ? Colors.red.shade400 : Colors.orange.shade400)
                        : Colors.black12,
                  ),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _condiciones.add(c.clave);
                    } else {
                      _condiciones.remove(c.clave);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _campo(_otras, 'Otras enfermedades o condiciones',
              maxLines: 2, icono: Icons.add_circle_outline),
          _seccion('Grupo sanguíneo', p),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in gruposSanguineos)
                ChoiceChip(
                  label: Text(g),
                  selected: _grupo == g,
                  selectedColor: p.suave,
                  side: BorderSide(color: _grupo == g ? p.fuerte : Colors.black12),
                  onSelected: (_) => setState(() => _grupo = _grupo == g ? '' : g),
                ),
            ],
          ),
          _seccion('Antecedentes', p),
          _campo(_cirugias, 'Cirugías u hospitalizaciones previas', maxLines: 2),
          const SizedBox(height: 10),
          _campo(_familiares, 'Antecedentes familiares relevantes', maxLines: 2,
              hint: 'Diabetes, hipertensión, problemas de sangrado...'),
          const SizedBox(height: 10),
          _campo(_observaciones, 'Observaciones médicas', maxLines: 3),
          const SizedBox(height: 16),
          _botonGuardar('Guardar y marcar como revisada', _guardar, p),
        ],
      ),
    );
  }
}

// ===========================================================================
// 3. ALERGIA
// ===========================================================================

Future<ResultadoEdicion<Alergia>?> mostrarHojaAlergia(
  BuildContext context, {
  Alergia? existente,
}) {
  return _hoja<ResultadoEdicion<Alergia>>(
    context,
    (_) => _HojaAlergia(existente: existente),
  );
}

class _HojaAlergia extends StatefulWidget {
  final Alergia? existente;
  const _HojaAlergia({this.existente});

  @override
  State<_HojaAlergia> createState() => _HojaAlergiaState();
}

class _HojaAlergiaState extends State<_HojaAlergia> {
  late final TextEditingController _descripcion;
  late final TextEditingController _reaccion;
  late TipoAlergia _tipo;
  late SeveridadAlergia _severidad;
  String? _error;

  static const Map<TipoAlergia, List<String>> _ejemplos = {
    TipoAlergia.medicamento: [
      'Penicilina', 'Amoxicilina', 'Ibuprofeno', 'Aspirina', 'Sulfas',
      'Clindamicina', 'Ketorolaco',
    ],
    TipoAlergia.anestesico: ['Lidocaína', 'Articaína', 'Mepivacaína', 'Epinefrina'],
    TipoAlergia.latex: ['Látex', 'Níquel', 'Acrílico', 'Yodo'],
    TipoAlergia.alimento: ['Mariscos', 'Frutos secos', 'Huevo', 'Lácteos'],
    TipoAlergia.otro: [],
  };

  static const List<String> _reacciones = [
    'Erupción en la piel', 'Urticaria', 'Hinchazón', 'Dificultad para respirar',
    'Anafilaxia', 'Malestar estomacal',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.existente;
    _descripcion = TextEditingController(text: a?.descripcion ?? '');
    _reaccion = TextEditingController(text: a?.reaccion ?? '');
    _tipo = a?.tipo ?? TipoAlergia.medicamento;
    _severidad = a?.severidad ?? SeveridadAlergia.moderada;
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _reaccion.dispose();
    super.dispose();
  }

  void _guardar() {
    final d = _descripcion.text.trim();
    if (d.isEmpty) {
      setState(() => _error = 'Escribe a qué es alérgico/a.');
      return;
    }
    final a = widget.existente ??
        Alergia(id: _uuid.v4(), descripcion: d);
    a.tipo = _tipo;
    a.descripcion = d;
    a.reaccion = _reaccion.text.trim();
    a.severidad = _severidad;
    Navigator.pop(context, ResultadoEdicion<Alergia>.guardar(a));
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaMedica;
    final editando = widget.existente != null;
    final colorSev = {
      SeveridadAlergia.leve: Colors.green.shade600,
      SeveridadAlergia.moderada: Colors.orange.shade700,
      SeveridadAlergia.grave: Colors.red.shade700,
    };
    return _Marco(
      titulo: editando ? 'Editar alergia' : 'Agregar alergia',
      paleta: p,
      icono: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccion('Tipo', p),
          _fila<TipoAlergia>(
            TipoAlergia.values, _tipo, (t) => etiquetaTipoAlergia[t]!,
            (t) => setState(() => _tipo = t), p,
          ),
          if ((_ejemplos[_tipo] ?? []).isNotEmpty) ...[
            const SizedBox(height: 8),
            _atajos(
              _ejemplos[_tipo]!,
              (t) => setState(() {
                _descripcion.text = t;
                _error = null;
              }),
              p,
            ),
          ],
          const SizedBox(height: 10),
          _campo(_descripcion, 'Alérgico/a a',
              onChanged: (_) => setState(() => _error = null)),
          _seccion('Reacción', p),
          _atajos(
            _reacciones,
            (t) => setState(() {
              final actual = _reaccion.text.trim();
              _reaccion.text = actual.isEmpty ? t : '$actual, $t';
            }),
            p,
          ),
          const SizedBox(height: 8),
          _campo(_reaccion, 'Qué le ocurre (opcional)', maxLines: 2),
          _seccion('Gravedad', p),
          Wrap(
            spacing: 8,
            children: [
              for (final s in SeveridadAlergia.values)
                ChoiceChip(
                  label: Text(etiquetaSeveridad[s]!),
                  selected: _severidad == s,
                  selectedColor: colorSev[s]!.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: _severidad == s ? colorSev[s]! : Colors.black12,
                  ),
                  onSelected: (_) => setState(() => _severidad = s),
                ),
            ],
          ),
          _mensajeError(_error),
          const SizedBox(height: 16),
          Row(
            children: [
              if (editando)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, ResultadoEdicion<Alergia>.eliminar()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                style: FilledButton.styleFrom(backgroundColor: p.fuerte),
                icon: const Icon(Icons.check),
                label: Text(editando ? 'Guardar cambios' : 'Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 4. MEDICACIÓN ACTUAL
// ===========================================================================

Future<ResultadoEdicion<MedicamentoActual>?> mostrarHojaMedicamentoActual(
  BuildContext context, {
  MedicamentoActual? existente,
}) {
  return _hoja<ResultadoEdicion<MedicamentoActual>>(
    context,
    (_) => _HojaMedicamentoActual(existente: existente),
  );
}

class _HojaMedicamentoActual extends StatefulWidget {
  final MedicamentoActual? existente;
  const _HojaMedicamentoActual({this.existente});

  @override
  State<_HojaMedicamentoActual> createState() => _HojaMedicamentoActualState();
}

class _HojaMedicamentoActualState extends State<_HojaMedicamentoActual> {
  late final TextEditingController _nombre;
  late final TextEditingController _dosis;
  late final TextEditingController _motivo;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.existente;
    _nombre = TextEditingController(text: m?.nombre ?? '');
    _dosis = TextEditingController(text: m?.dosis ?? '');
    _motivo = TextEditingController(text: m?.motivo ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _dosis.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _guardar() {
    final n = _nombre.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Escribe el nombre del medicamento.');
      return;
    }
    final m = widget.existente ?? MedicamentoActual(id: _uuid.v4(), nombre: n);
    m.nombre = n;
    m.dosis = _dosis.text.trim();
    m.motivo = _motivo.text.trim();
    Navigator.pop(context, ResultadoEdicion<MedicamentoActual>.guardar(m));
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaMedica;
    final editando = widget.existente != null;
    return _Marco(
      titulo: editando ? 'Editar medicamento' : 'Medicación actual',
      paleta: p,
      icono: Icons.medication_liquid_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campo(_nombre, 'Medicamento',
              onChanged: (_) => setState(() => _error = null)),
          const SizedBox(height: 10),
          _campo(_dosis, 'Dosis y frecuencia (opcional)',
              hint: 'Ej. 1 tableta al día'),
          const SizedBox(height: 10),
          _campo(_motivo, '¿Para qué lo toma? (opcional)'),
          _mensajeError(_error),
          const SizedBox(height: 16),
          Row(
            children: [
              if (editando)
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    ResultadoEdicion<MedicamentoActual>.eliminar(),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                style: FilledButton.styleFrom(backgroundColor: p.fuerte),
                icon: const Icon(Icons.check),
                label: Text(editando ? 'Guardar cambios' : 'Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 5. HÁBITOS Y ANTECEDENTES ODONTOLÓGICOS
// ===========================================================================

Future<bool?> mostrarHojaHabitos(
  BuildContext context, {
  required FichaClinica ficha,
}) {
  return _hoja<bool>(context, (_) => _HojaHabitos(ficha: ficha));
}

class _HojaHabitos extends StatefulWidget {
  final FichaClinica ficha;
  const _HojaHabitos({required this.ficha});

  @override
  State<_HojaHabitos> createState() => _HojaHabitosState();
}

class _HojaHabitosState extends State<_HojaHabitos> {
  late NivelHabito _tabaco;
  late NivelHabito _alcohol;
  late int _cepillados;
  late bool _hilo;
  late bool _enjuague;
  late bool _bruxismo;
  late bool _sangrado;
  late bool _sensibilidad;
  late bool _ortodoncia;
  late int _ansiedad;
  late final TextEditingController _ultimaVisita;
  late final TextEditingController _experiencias;

  static const List<String> _etiquetasAnsiedad = [
    'Nada', 'Poca', 'Media', 'Bastante', 'Mucha',
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.ficha;
    _tabaco = f.tabaco;
    _alcohol = f.alcohol;
    _cepillados = f.cepilladosDia;
    _hilo = f.usaHilo;
    _enjuague = f.usaEnjuague;
    _bruxismo = f.bruxismo;
    _sangrado = f.sangradoEncias;
    _sensibilidad = f.sensibilidad;
    _ortodoncia = f.ortodonciaPrevia;
    _ansiedad = f.ansiedadDental;
    _ultimaVisita = TextEditingController(text: f.ultimaVisita);
    _experiencias = TextEditingController(text: f.experienciasPrevias);
  }

  @override
  void dispose() {
    _ultimaVisita.dispose();
    _experiencias.dispose();
    super.dispose();
  }

  void _guardar() {
    final f = widget.ficha;
    f.tabaco = _tabaco;
    f.alcohol = _alcohol;
    f.cepilladosDia = _cepillados;
    f.usaHilo = _hilo;
    f.usaEnjuague = _enjuague;
    f.bruxismo = _bruxismo;
    f.sangradoEncias = _sangrado;
    f.sensibilidad = _sensibilidad;
    f.ortodonciaPrevia = _ortodoncia;
    f.ansiedadDental = _ansiedad;
    f.ultimaVisita = _ultimaVisita.text.trim();
    f.experienciasPrevias = _experiencias.text.trim();
    Navigator.pop(context, true);
  }

  Widget _interruptor(String texto, bool valor, ValueChanged<bool> alCambiar) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(texto),
      value: valor,
      activeColor: paletaEvolucion.fuerte,
      onChanged: alCambiar,
    );
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaEvolucion;
    return _Marco(
      titulo: 'Hábitos y salud bucal',
      paleta: p,
      icono: Icons.sentiment_satisfied_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seccion('Hábitos', p),
          const Text('Fuma', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _fila<NivelHabito>(
            NivelHabito.values, _tabaco, (n) => etiquetaNivelHabito[n]!,
            (n) => setState(() => _tabaco = n), p,
          ),
          const SizedBox(height: 10),
          const Text('Consume alcohol', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _fila<NivelHabito>(
            NivelHabito.values, _alcohol, (n) => etiquetaNivelHabito[n]!,
            (n) => setState(() => _alcohol = n), p,
          ),
          _interruptor('Aprieta o rechina los dientes (bruxismo)', _bruxismo,
              (v) => setState(() => _bruxismo = v)),
          _seccion('Higiene oral', p),
          Row(
            children: [
              const Expanded(
                child: Text('Cepillados al día',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              IconButton.filledTonal(
                onPressed:
                    _cepillados > 0 ? () => setState(() => _cepillados--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  _cepillados == 0 ? 'S/D' : '$_cepillados',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filledTonal(
                onPressed:
                    _cepillados < 6 ? () => setState(() => _cepillados++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          _interruptor('Usa hilo dental', _hilo, (v) => setState(() => _hilo = v)),
          _interruptor('Usa enjuague bucal', _enjuague,
              (v) => setState(() => _enjuague = v)),
          _seccion('Salud bucal', p),
          _interruptor('Le sangran las encías', _sangrado,
              (v) => setState(() => _sangrado = v)),
          _interruptor('Sensibilidad dental', _sensibilidad,
              (v) => setState(() => _sensibilidad = v)),
          _interruptor('Ortodoncia previa', _ortodoncia,
              (v) => setState(() => _ortodoncia = v)),
          const SizedBox(height: 6),
          _campo(_ultimaVisita, 'Última visita al odontólogo',
              hint: 'Ej. hace 1 año, por una limpieza'),
          const SizedBox(height: 10),
          _campo(_experiencias, 'Experiencias previas relevantes',
              maxLines: 2, hint: 'Complicaciones, miedos, anestesia que le cayó mal...'),
          _seccion('Ansiedad ante el tratamiento', p),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text(_etiquetasAnsiedad[i - 1]),
                  selected: _ansiedad == i,
                  selectedColor: p.suave,
                  side: BorderSide(color: _ansiedad == i ? p.fuerte : Colors.black12),
                  onSelected: (_) => setState(() => _ansiedad = _ansiedad == i ? 0 : i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _botonGuardar('Guardar', _guardar, p),
        ],
      ),
    );
  }
}

// ===========================================================================
// 6. EVOLUCIÓN (nota por cita)
// ===========================================================================

Future<ResultadoEdicion<Evolucion>?> mostrarHojaEvolucion(
  BuildContext context, {
  required Paciente paciente,
  Evolucion? existente,
}) {
  return _hoja<ResultadoEdicion<Evolucion>>(
    context,
    (_) => _HojaEvolucion(paciente: paciente, existente: existente),
  );
}

class _HojaEvolucion extends StatefulWidget {
  final Paciente paciente;
  final Evolucion? existente;
  const _HojaEvolucion({required this.paciente, this.existente});

  @override
  State<_HojaEvolucion> createState() => _HojaEvolucionState();
}

class _HojaEvolucionState extends State<_HojaEvolucion> {
  late final TextEditingController _procedimiento;
  late final TextEditingController _piezas;
  late final TextEditingController _anestesia;
  late final TextEditingController _presion;
  late final TextEditingController _materiales;
  late final TextEditingController _observaciones;
  late final TextEditingController _indicaciones;
  late DateTime _fecha;
  DateTime? _proxima;
  late final Set<String> _realizados;
  String? _error;

  static const List<String> _indicacionesFrecuentes = [
    'Dieta blanda y fría durante 24 horas',
    'No enjuagar con fuerza las primeras 24 horas',
    'Compresas frías intermitentes',
    'No masticar hasta que pase la anestesia',
    'Cepillado suave de la zona',
    'No fumar ni tomar alcohol',
    'Acudir a control si hay fiebre, sangrado o dolor que aumenta',
  ];

  List<ItemPresupuesto> get _itemsDisponibles {
    final previos = widget.existente?.itemsRealizados ?? const <String>[];
    final items = widget.paciente.presupuesto?.items ?? const <ItemPresupuesto>[];
    return items
        .where((i) =>
            i.estado != EstadoTratamiento.cancelado &&
            (i.estado != EstadoTratamiento.completado || previos.contains(i.id)))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _procedimiento = TextEditingController(text: e?.procedimiento ?? '');
    _piezas = TextEditingController(text: e?.piezas ?? '');
    _anestesia = TextEditingController(text: e?.anestesia ?? '');
    _presion = TextEditingController(text: e?.presionArterial ?? '');
    _materiales = TextEditingController(text: e?.materiales ?? '');
    _observaciones = TextEditingController(text: e?.observaciones ?? '');
    _indicaciones = TextEditingController(text: e?.indicaciones ?? '');
    _fecha = e?.fecha ?? DateTime.now();
    _proxima = e?.proximaCita;
    final ids = _itemsDisponibles.map((i) => i.id).toSet();
    _realizados = {
      for (final id in (e?.itemsRealizados ?? const <String>[]))
        if (ids.contains(id)) id,
    };
  }

  @override
  void dispose() {
    for (final c in [
      _procedimiento, _piezas, _anestesia, _presion, _materiales,
      _observaciones, _indicaciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFechaCita() async {
    final f = await _elegirFecha(
      context, _fecha,
      primera: DateTime(2020),
      ultima: DateTime.now().add(const Duration(days: 1)),
      ayuda: 'Fecha de la cita',
    );
    if (f != null) {
      setState(() => _fecha = f);
    }
  }

  Future<void> _elegirProxima() async {
    final hoy = DateTime.now();
    final f = await _elegirFecha(
      context,
      _proxima ?? hoy.add(const Duration(days: 7)),
      primera: DateTime(hoy.year, hoy.month, hoy.day),
      ultima: hoy.add(const Duration(days: 365 * 3)),
      ayuda: 'Próxima cita',
    );
    if (f != null) {
      setState(() => _proxima = f);
    }
  }

  void _alMarcarItem(ItemPresupuesto item, bool marcado) {
    setState(() {
      if (marcado) {
        _realizados.add(item.id);
        if (_procedimiento.text.trim().isEmpty) {
          _procedimiento.text = item.descripcion;
        }
        final pieza = item.piezaFdi;
        if (pieza != null && pieza.isNotEmpty) {
          final actuales = _piezas.text
              .split(RegExp(r'[,\s]+'))
              .where((e) => e.isNotEmpty)
              .toList();
          if (!actuales.contains(pieza)) {
            actuales.add(pieza);
            _piezas.text = actuales.join(', ');
          }
        }
        _error = null;
      } else {
        _realizados.remove(item.id);
      }
    });
  }

  void _guardar() {
    final procedimiento = _procedimiento.text.trim();
    if (procedimiento.isEmpty && _realizados.isEmpty) {
      setState(() => _error = 'Indica el procedimiento realizado en esta cita.');
      return;
    }
    final elegidos =
        _itemsDisponibles.where((i) => _realizados.contains(i.id)).toList();
    final e = widget.existente ?? Evolucion(id: _uuid.v4(), fecha: _fecha);
    e.fecha = _fecha;
    e.procedimiento = procedimiento.isEmpty
        ? elegidos.map((i) => i.descripcion).join('; ')
        : procedimiento;
    e.piezas = _piezas.text.trim();
    e.anestesia = _anestesia.text.trim();
    e.presionArterial = _presion.text.trim();
    e.materiales = _materiales.text.trim();
    e.observaciones = _observaciones.text.trim();
    e.indicaciones = _indicaciones.text.trim();
    e.proximaCita = _proxima;
    e.itemsRealizados = elegidos.map((i) => i.id).toList();
    e.descripcionItems = elegidos.map((i) => i.descripcion).toList();
    Navigator.pop(context, ResultadoEdicion<Evolucion>.guardar(e));
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaEvolucion;
    final editando = widget.existente != null;
    final items = _itemsDisponibles;
    return _Marco(
      titulo: editando ? 'Editar evolución' : 'Nueva evolución',
      paleta: p,
      icono: Icons.edit_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _elegirFechaCita,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha de la cita',
                prefixIcon: Icon(Icons.event, size: 20),
              ),
              child: Text(_fmtFecha.format(_fecha)),
            ),
          ),
          if (items.isNotEmpty) ...[
            _seccion('Tratamientos del presupuesto realizados hoy', p),
            const Text(
              'Al guardar se marcan como "Completado" en el presupuesto.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            for (final i in items)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: p.fuerte,
                value: _realizados.contains(i.id),
                onChanged: (v) => _alMarcarItem(i, v == true),
                title: Text(i.descripcion),
                subtitle: Text(
                  etiquetaEstadoTratamiento[i.estado]!,
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Text(
                  formatoMoneda(i.total),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
          _seccion('Procedimiento', p),
          _atajos(
            [for (final c in catalogoPrestaciones.take(10)) c.nombre],
            (t) => setState(() {
              _procedimiento.text = t;
              _error = null;
            }),
            p,
          ),
          const SizedBox(height: 8),
          _campo(_procedimiento, 'Procedimiento realizado',
              maxLines: 2, onChanged: (_) => setState(() => _error = null)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _campo(_piezas, 'Piezas', hint: 'Ej. 16, 17',
                    tipo: TextInputType.text),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campo(_presion, 'Presión arterial', hint: '120/80',
                    tipo: TextInputType.text),
              ),
            ],
          ),
          _seccion('Anestesia y materiales', p),
          _atajos(atajosAnestesia, (t) => setState(() => _anestesia.text = t), p),
          const SizedBox(height: 8),
          _campo(_anestesia, 'Anestesia utilizada'),
          const SizedBox(height: 10),
          _campo(_materiales, 'Materiales usados (opcional)',
              hint: 'Ej. resina A2, ionómero, hipoclorito'),
          _seccion('Notas de la cita', p),
          _campo(_observaciones, 'Observaciones clínicas', maxLines: 4,
              hint: 'Hallazgos, evolución, complicaciones, respuesta del paciente'),
          _seccion('Indicaciones al paciente', p),
          _atajos(
            _indicacionesFrecuentes,
            (t) => setState(() {
              final actual = _indicaciones.text.trim();
              _indicaciones.text = actual.isEmpty ? t : '$actual\n$t';
            }),
            p,
          ),
          const SizedBox(height: 8),
          _campo(_indicaciones, 'Indicaciones posteriores', maxLines: 4),
          _seccion('Próxima cita', p),
          Row(
            children: [
              Expanded(
                child: Text(
                  _proxima == null
                      ? 'Sin próxima cita programada'
                      : _fmtFecha.format(_proxima!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_proxima != null)
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _proxima = null),
                ),
              TextButton.icon(
                onPressed: _elegirProxima,
                icon: const Icon(Icons.event_available, size: 18),
                label: Text(_proxima == null ? 'Elegir fecha' : 'Cambiar'),
              ),
            ],
          ),
          _mensajeError(_error),
          const SizedBox(height: 14),
          Row(
            children: [
              if (editando)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, ResultadoEdicion<Evolucion>.eliminar()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                style: FilledButton.styleFrom(backgroundColor: p.fuerte),
                icon: const Icon(Icons.check),
                label: Text(editando ? 'Guardar cambios' : 'Guardar evolución'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 7. RECETA
// ===========================================================================

Future<ResultadoEdicion<Receta>?> mostrarHojaReceta(
  BuildContext context, {
  required FichaClinica ficha,
  Receta? existente,
}) {
  return _hoja<ResultadoEdicion<Receta>>(
    context,
    (_) => _HojaReceta(ficha: ficha, existente: existente),
  );
}

class _CtrlsItemReceta {
  final TextEditingController nombre;
  final TextEditingController presentacion;
  final TextEditingController posologia;
  final TextEditingController duracion;
  final TextEditingController cantidad;
  _CtrlsItemReceta(RecetaItem? i)
      : nombre = TextEditingController(text: i?.nombre ?? ''),
        presentacion = TextEditingController(text: i?.presentacion ?? ''),
        posologia = TextEditingController(text: i?.posologia ?? ''),
        duracion = TextEditingController(text: i?.duracion ?? ''),
        cantidad = TextEditingController(text: i?.cantidad ?? '');

  void dispose() {
    nombre.dispose();
    presentacion.dispose();
    posologia.dispose();
    duracion.dispose();
    cantidad.dispose();
  }
}

class _HojaReceta extends StatefulWidget {
  final FichaClinica ficha;
  final Receta? existente;
  const _HojaReceta({required this.ficha, this.existente});

  @override
  State<_HojaReceta> createState() => _HojaRecetaState();
}

class _HojaRecetaState extends State<_HojaReceta> {
  late final TextEditingController _diagnostico;
  late final TextEditingController _indicaciones;
  late final List<_CtrlsItemReceta> _items;
  late DateTime _fecha;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.existente;
    _diagnostico = TextEditingController(text: r?.diagnostico ?? '');
    _indicaciones = TextEditingController(text: r?.indicaciones ?? '');
    _fecha = r?.fecha ?? DateTime.now();
    _items = [
      for (final i in (r?.items ?? <RecetaItem>[])) _CtrlsItemReceta(i),
    ];
    if (_items.isEmpty) {
      _items.add(_CtrlsItemReceta(null));
    }
  }

  @override
  void dispose() {
    _diagnostico.dispose();
    _indicaciones.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFechaReceta() async {
    final f = await _elegirFecha(
      context, _fecha,
      primera: DateTime(2020),
      ultima: DateTime.now().add(const Duration(days: 1)),
      ayuda: 'Fecha de la receta',
    );
    if (f != null) {
      setState(() => _fecha = f);
    }
  }

  void _agregarSugerido(MedicamentoSugerido m) {
    setState(() {
      // Reutiliza el primer renglón vacío si lo hay.
      final vacio = _items.where((i) => i.nombre.text.trim().isEmpty).toList();
      final destino = vacio.isNotEmpty ? vacio.first : _CtrlsItemReceta(null);
      destino.nombre.text = m.nombre;
      destino.presentacion.text = m.presentacion;
      if (vacio.isEmpty) {
        _items.add(destino);
      }
      _error = null;
    });
  }

  Future<void> _guardar() async {
    final validos = _items.where((i) => i.nombre.text.trim().isNotEmpty).toList();
    if (validos.isEmpty) {
      setState(() => _error = 'Agrega al menos un medicamento.');
      return;
    }
    final sinPosologia =
        validos.where((i) => i.posologia.text.trim().isEmpty).length;
    if (sinPosologia > 0) {
      setState(() => _error =
          'Falta la posología (dosis y frecuencia) de $sinPosologia medicamento(s).');
      return;
    }
    // Aviso de posible alergia antes de guardar.
    final conflictos = <String>[];
    for (final i in validos) {
      final a = widget.ficha.alergiaConflictiva(i.nombre.text);
      if (a != null) {
        conflictos.add('${i.nombre.text.trim()} (alergia registrada: ${a.descripcion})');
      }
    }
    if (conflictos.isNotEmpty) {
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade700, size: 36),
          title: const Text('Posible alergia'),
          content: Text(
            'El paciente tiene alergias registradas que podrían coincidir con:\n\n'
            '${conflictos.map((c) => '• $c').join('\n')}\n\n'
            '¿Quieres guardar la receta de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar igual'),
            ),
          ],
        ),
      );
      if (seguir != true || !mounted) {
        return;
      }
    }
    final r = widget.existente ??
        Receta(
          id: _uuid.v4(),
          numero: widget.ficha.siguienteNumeroReceta,
          fecha: _fecha,
        );
    r.fecha = _fecha;
    r.diagnostico = _diagnostico.text.trim();
    r.indicaciones = _indicaciones.text.trim();
    r.items = [
      for (final i in validos)
        RecetaItem(
          nombre: i.nombre.text.trim(),
          presentacion: i.presentacion.text.trim(),
          posologia: i.posologia.text.trim(),
          duracion: i.duracion.text.trim(),
          cantidad: i.cantidad.text.trim(),
        ),
    ];
    Navigator.pop(context, ResultadoEdicion<Receta>.guardar(r));
  }

  Widget _tarjetaItem(int indice) {
    const p = paletaReceta;
    final c = _items[indice];
    final conflicto = widget.ficha.alergiaConflictiva(c.nombre.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.suave.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conflicto != null ? Colors.red.shade400 : p.fuerte.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: p.fuerte,
                child: Text(
                  '${indice + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Medicamento',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (_items.length > 1)
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() {
                    _items.removeAt(indice).dispose();
                  }),
                ),
            ],
          ),
          _campo(c.nombre, 'Nombre', cap: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null)),
          if (conflicto != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Posible alergia registrada: ${conflicto.descripcion}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _campo(c.presentacion, 'Presentación', hint: 'Ej. 500 mg tabletas'),
          const SizedBox(height: 8),
          _campo(c.posologia, 'Posología (dosis y frecuencia)',
              maxLines: 2, hint: 'La indica la doctora'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _campo(c.duracion, 'Duración', hint: 'Ej. 5 días')),
              const SizedBox(width: 8),
              Expanded(child: _campo(c.cantidad, 'Cantidad', hint: 'Ej. 15 tabletas')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaReceta;
    final editando = widget.existente != null;
    final alergias = widget.ficha.alergiasOrdenadas;
    return _Marco(
      titulo: editando
          ? 'Editar receta N° ${widget.existente!.numeroTexto}'
          : 'Nueva receta N° ${widget.ficha.siguienteNumeroReceta.toString().padLeft(4, '0')}',
      paleta: p,
      icono: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alergias.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alergias del paciente: '
                      '${alergias.map((a) => a.descripcion).join(', ')}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _elegirFechaReceta,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                prefixIcon: Icon(Icons.event, size: 20),
              ),
              child: Text(_fmtFecha.format(_fecha)),
            ),
          ),
          const SizedBox(height: 10),
          _campo(_diagnostico, 'Diagnóstico (opcional)', maxLines: 2),
          _seccion('Medicamentos', p),
          const Text(
            'Toca uno para agregarlo con su presentación. La posología siempre la '
            'escribe la doctora.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final m in medicamentosSugeridos)
                ActionChip(
                  label: Text(m.nombre, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: p.suave,
                  side: BorderSide(color: p.fuerte.withValues(alpha: 0.35)),
                  onPressed: () => _agregarSugerido(m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _items.length; i++) _tarjetaItem(i),
          OutlinedButton.icon(
            onPressed: () => setState(() => _items.add(_CtrlsItemReceta(null))),
            icon: const Icon(Icons.add),
            label: const Text('Agregar otro medicamento'),
          ),
          _seccion('Indicaciones generales', p),
          _campo(_indicaciones, 'Indicaciones (opcional)', maxLines: 3,
              hint: 'Ej. Tomar con alimentos. Suspender si aparece erupción.'),
          _mensajeError(_error),
          const SizedBox(height: 14),
          Row(
            children: [
              if (editando)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, ResultadoEdicion<Receta>.eliminar()),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                style: FilledButton.styleFrom(backgroundColor: p.fuerte),
                icon: const Icon(Icons.check),
                label: Text(editando ? 'Guardar cambios' : 'Guardar receta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 8. CONSENTIMIENTO INFORMADO
// ===========================================================================

Future<ResultadoEdicion<Consentimiento>?> mostrarHojaConsentimiento(
  BuildContext context, {
  required Paciente paciente,
  required String nombreDoctor,
  Consentimiento? existente,
}) {
  return _hoja<ResultadoEdicion<Consentimiento>>(
    context,
    (_) => _HojaConsentimiento(
      paciente: paciente,
      nombreDoctor: nombreDoctor,
      existente: existente,
    ),
  );
}

class _HojaConsentimiento extends StatefulWidget {
  final Paciente paciente;
  final String nombreDoctor;
  final Consentimiento? existente;
  const _HojaConsentimiento({
    required this.paciente,
    required this.nombreDoctor,
    this.existente,
  });

  @override
  State<_HojaConsentimiento> createState() => _HojaConsentimientoState();
}

class _HojaConsentimientoState extends State<_HojaConsentimiento> {
  late final TextEditingController _titulo;
  late final TextEditingController _texto;
  late final TextEditingController _firmante;
  late final TextEditingController _cedula;
  late final TextEditingController _parentesco;
  late bool _representante;
  late List<String> _trazos;
  late double _ancho;
  late double _alto;
  DateTime? _firmadoEn;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.existente;
    final esMenor = widget.paciente.ficha?.esMenor ?? false;
    _titulo = TextEditingController(text: c?.titulo ?? '');
    _texto = TextEditingController(text: c?.texto ?? '');
    _representante = c?.esRepresentante ?? esMenor;
    _firmante = TextEditingController(
      text: c?.nombreFirmante ?? (_representante ? '' : widget.paciente.nombre),
    );
    _cedula = TextEditingController(
      text: c?.cedulaFirmante ?? (_representante ? '' : widget.paciente.cedula),
    );
    _parentesco = TextEditingController(text: c?.parentesco ?? '');
    _trazos = List<String>.from(c?.firmaTrazos ?? const <String>[]);
    _ancho = c?.firmaAncho ?? 0;
    _alto = c?.firmaAlto ?? 0;
    _firmadoEn = c?.firmadoEn;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    _firmante.dispose();
    _cedula.dispose();
    _parentesco.dispose();
    super.dispose();
  }

  void _elegirPlantilla(PlantillaConsentimiento t) {
    setState(() {
      _titulo.text = t.titulo;
      _texto.text = t.texto;
      _error = null;
      if (t.titulo.startsWith('Tratamiento en menor')) {
        _representante = true;
      }
    });
  }

  String _resolverMarcas(String texto) {
    final firmante = _firmante.text.trim().isEmpty
        ? (widget.paciente.nombre.isEmpty ? 'el/la paciente' : widget.paciente.nombre)
        : _firmante.text.trim();
    final paciente =
        widget.paciente.nombre.isEmpty ? 'el/la paciente' : widget.paciente.nombre;
    final doctor = widget.nombreDoctor.trim().isEmpty
        ? 'profesional tratante'
        : widget.nombreDoctor.trim();
    return texto
        .replaceAll('{firmante}', firmante)
        .replaceAll('{paciente}', paciente)
        .replaceAll('{doctor}', doctor)
        .replaceAll('{fecha}', _fmtFecha.format(DateTime.now()));
  }

  Future<void> _firmar() async {
    final r = await Navigator.push<ResultadoFirma>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FirmaPadPantalla(
          titulo: _representante ? 'Firma del representante' : 'Firma del paciente',
        ),
      ),
    );
    if (r == null || !mounted) {
      return;
    }
    setState(() {
      _trazos = r.trazos;
      _ancho = r.ancho;
      _alto = r.alto;
      _firmadoEn = DateTime.now();
    });
  }

  void _guardar() {
    final titulo = _titulo.text.trim();
    final texto = _texto.text.trim();
    if (titulo.isEmpty || texto.isEmpty) {
      setState(() => _error = 'Elige una plantilla o escribe el título y el texto.');
      return;
    }
    final c = widget.existente ??
        Consentimiento(
          id: _uuid.v4(),
          fecha: DateTime.now(),
          titulo: titulo,
          texto: texto,
        );
    c.titulo = titulo;
    c.texto = _resolverMarcas(texto);
    c.nombreFirmante = _firmante.text.trim();
    c.cedulaFirmante = _cedula.text.trim();
    c.esRepresentante = _representante;
    c.parentesco = _representante ? _parentesco.text.trim() : '';
    c.firmaTrazos = _trazos;
    c.firmaAncho = _ancho;
    c.firmaAlto = _alto;
    c.firmadoEn = _trazos.isEmpty ? null : (_firmadoEn ?? DateTime.now());
    Navigator.pop(context, ResultadoEdicion<Consentimiento>.guardar(c));
  }

  @override
  Widget build(BuildContext context) {
    const p = paletaConsent;
    final editando = widget.existente != null;
    final firmado = _trazos.isNotEmpty;
    final borrador = Consentimiento(
      id: 'x',
      fecha: DateTime.now(),
      titulo: '',
      texto: '',
      firmaTrazos: _trazos,
      firmaAncho: _ancho,
      firmaAlto: _alto,
    );
    return _Marco(
      titulo: editando ? 'Consentimiento informado' : 'Nuevo consentimiento',
      paleta: p,
      icono: Icons.gavel_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!editando) ...[
            _seccion('Plantilla', p),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final t in plantillasConsentimiento)
                  ActionChip(
                    label: Text(
                      t.titulo.startsWith('Documento en blanco') ? 'En blanco' : t.titulo,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: p.suave,
                    side: BorderSide(color: p.fuerte.withValues(alpha: 0.35)),
                    onPressed: () => _elegirPlantilla(t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _campo(_titulo, 'Título del documento',
              onChanged: (_) => setState(() => _error = null)),
          const SizedBox(height: 10),
          _campo(_texto, 'Texto del consentimiento', maxLines: 12,
              onChanged: (_) => setState(() => _error = null)),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Los datos entre llaves ({firmante}, {paciente}, {doctor}) se completan '
              'al guardar. Revisa el texto según tu criterio profesional y la '
              'normativa vigente antes de usarlo.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          _seccion('Quién firma', p),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: p.fuerte,
            title: const Text('Firma un representante legal'),
            subtitle: (widget.paciente.ficha?.esMenor ?? false)
                ? const Text('El paciente es menor de edad')
                : null,
            value: _representante,
            onChanged: (v) => setState(() {
              _representante = v;
              if (v && _firmante.text.trim() == widget.paciente.nombre.trim()) {
                _firmante.clear();
                _cedula.clear();
              } else if (!v && _firmante.text.trim().isEmpty) {
                _firmante.text = widget.paciente.nombre;
                _cedula.text = widget.paciente.cedula;
              }
            }),
          ),
          _campo(_firmante, _representante ? 'Nombre del representante' : 'Nombre',
              cap: TextCapitalization.words, icono: Icons.person_outline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _campo(_cedula, 'Cédula', tipo: TextInputType.number),
              ),
              if (_representante) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _campo(_parentesco, 'Parentesco',
                      cap: TextCapitalization.words),
                ),
              ],
            ],
          ),
          _seccion('Firma', p),
          if (firmado) ...[
            FirmaVista(consentimiento: borrador, alto: 110),
            if (_firmadoEn != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Firmado el ${_fmtFecha.format(_firmadoEn!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _firmar,
                  icon: Icon(firmado ? Icons.refresh : Icons.draw),
                  label: Text(firmado ? 'Volver a firmar' : 'Firmar ahora'),
                ),
              ),
              if (firmado) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar firma',
                  onPressed: () => setState(() {
                    _trazos = [];
                    _firmadoEn = null;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (!firmado)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Puedes guardarlo sin firma y firmarlo después: quedará como '
                '"Pendiente de firma".',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          _mensajeError(_error),
          const SizedBox(height: 14),
          Row(
            children: [
              if (editando)
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    ResultadoEdicion<Consentimiento>.eliminar(),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar,
                style: FilledButton.styleFrom(backgroundColor: p.fuerte),
                icon: const Icon(Icons.check),
                label: Text(editando ? 'Guardar cambios' : 'Guardar documento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
