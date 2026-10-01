import 'package:flutter/material.dart';

/// Un tema de ayuda: qué hace una opción y cómo se usa.
class AyudaTema {
  final String clave;
  final String grupo;
  final String titulo;
  final IconData icono;
  final Color color;
  final Color colorOscuro;
  final String resumen;
  final List<String> pasos;
  final List<String> consejos;

  const AyudaTema({
    required this.clave,
    required this.grupo,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.colorOscuro,
    required this.resumen,
    this.pasos = const [],
    this.consejos = const [],
  });
}

const String grupoPresupuesto = 'Presupuesto y pagos';
const String grupoCaja = 'Caja';
const String grupoFicha = 'Ficha clínica';
const String grupoHojas = 'Formularios de la ficha';
const String grupoNube = 'Respaldo y seguridad';

const List<String> ordenGruposAyuda = [
  grupoPresupuesto,
  grupoCaja,
  grupoFicha,
  grupoHojas,
  grupoNube,
];

// Paleta de cada sección (la misma de las pestañas).
const Color _rosa = Color(0xFFEC407A);
const Color _rosaO = Color(0xFFAD1457);
const Color _rojo = Color(0xFFEF5350);
const Color _rojoO = Color(0xFFC62828);
const Color _teal = Color(0xFF26A69A);
const Color _tealO = Color(0xFF00796B);
const Color _azul = Color(0xFF42A5F5);
const Color _azulO = Color(0xFF1565C0);
const Color _violeta = Color(0xFF7E57C2);
const Color _violetaO = Color(0xFF4527A0);
const Color _naranja = Color(0xFFFFA726);
const Color _naranjaO = Color(0xFFEF6C00);
const Color _indigo = Color(0xFF5C6BC0);
const Color _indigoO = Color(0xFF283593);

/// Todos los temas, por clave. Cada pantalla y cada formulario tiene el suyo.
const Map<String, AyudaTema> temasAyuda = {
  // ------------------------------------------------------------------
  // PRESUPUESTO Y PAGOS
  // ------------------------------------------------------------------
  'presupuesto': AyudaTema(
    clave: 'presupuesto',
    grupo: grupoPresupuesto,
    titulo: 'Presupuesto y tratamientos',
    icono: Icons.checklist,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen:
        'El presupuesto es el plan de tratamiento del paciente con el precio de '
        'cada procedimiento. Es un solo documento vivo: se va actualizando a '
        'medida que avanza el tratamiento.',
    pasos: [
      'Toca «Generar desde odontograma» para traer los hallazgos del último odontograma (caries, endodoncias, extracciones…). Tú eliges cuáles cobrar.',
      'O usa «Agregar tratamiento» para añadir uno a mano: elige uno frecuente o escribe el nombre, el precio y la cantidad.',
      'Toca un tratamiento para editarlo. La etiqueta de color cambia su estado: Pendiente, Aceptado, En progreso, Completado o Cancelado.',
      'En el menú ⋮ de arriba ajustas el descuento, la vigencia y las notas, aceptas todo el plan de una vez, cambias los precios por hallazgo o envías el resumen por WhatsApp.',
      'El botón PDF imprime o comparte el presupuesto con el historial de pagos y el saldo.',
    ],
    consejos: [
      'Si un tratamiento no se hará, márcalo «Cancelado» en vez de eliminarlo: no suma al total y queda el historial.',
      'Volver a generar desde el odontograma no borra tu trabajo: solo ofrece los hallazgos nuevos.',
      'Los precios iniciales son de referencia. Ajústalos a tu tarifa.',
    ],
  ),
  'pagos': AyudaTema(
    clave: 'pagos',
    grupo: grupoPresupuesto,
    titulo: 'Pagos y recibos',
    icono: Icons.payments_outlined,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen:
        'Aquí registras los abonos del paciente. Cada pago genera un recibo '
        'numerado y el saldo se actualiza al instante.',
    pasos: [
      'En la pestaña «Pagos» toca «Registrar pago».',
      'Escribe el monto (o usa «Saldo completo» o «Mitad del saldo»), elige la forma de pago y, si es transferencia o tarjeta, anota el comprobante.',
      'Al guardar se crea el recibo (0001, 0002…). Toca «Ver recibo» para imprimirlo o compartirlo en PDF.',
      'Para corregir un error usa el menú ⋮ del pago → «Anular pago». No se borra: queda en el historial como ANULADO y deja de contar.',
    ],
    consejos: [
      'Si el pago supera el saldo te avisa antes de guardarlo: el excedente queda a favor del paciente.',
      'El número de recibo nunca se reutiliza, ni siquiera si anulas un pago.',
      '«Estado de cuenta (PDF)» resume presupuesto, pagos y saldo. «Recordar saldo» envía un WhatsApp al paciente.',
    ],
  ),

  // ------------------------------------------------------------------
  // CAJA
  // ------------------------------------------------------------------
  'caja_cobros': AyudaTema(
    clave: 'caja_cobros',
    grupo: grupoCaja,
    titulo: 'Cobros (Caja)',
    icono: Icons.savings_outlined,
    color: _rosa,
    colorOscuro: _rosaO,
    resumen:
        'La Caja suma los pagos de todos tus pacientes para que sepas cuánto '
        'cobraste en un período.',
    pasos: [
      'Elige Día, Semana, Mes o Rango y usa las flechas para moverte entre períodos.',
      'Arriba ves el total cobrado, cuántos pagos hubo, el promedio y el mejor día, comparado con el período anterior.',
      'El gráfico muestra lo cobrado cada día y, debajo, el desglose por forma de pago.',
      'Toca un pago de la lista para ver su recibo.',
      'El botón PDF de arriba genera el reporte del período.',
    ],
    consejos: [
      'Los pagos anulados no suman al total; se indica cuántos hubo.',
      'Desliza hacia abajo para actualizar los datos.',
    ],
  ),
  'caja_porcobrar': AyudaTema(
    clave: 'caja_porcobrar',
    grupo: grupoCaja,
    titulo: 'Por cobrar',
    icono: Icons.hourglass_bottom,
    color: _rosa,
    colorOscuro: _rosaO,
    resumen:
        'Lista a los pacientes que todavía deben dinero, del que más debe al '
        'que menos.',
    pasos: [
      'Solo aparecen pacientes con algún tratamiento aceptado o con pagos hechos: un presupuesto sin aprobar no cuenta como deuda.',
      'Usa el buscador por nombre o cédula.',
      'Toca a un paciente para abrir su presupuesto y registrar un pago.',
      'El ícono de chat envía un recordatorio de saldo por WhatsApp.',
    ],
    consejos: [
      'Para que alguien deje de aparecer, registra su pago o marca sus tratamientos como «Cancelado».',
    ],
  ),

  // ------------------------------------------------------------------
  // FICHA CLÍNICA
  // ------------------------------------------------------------------
  'ficha_resumen': AyudaTema(
    clave: 'ficha_resumen',
    grupo: grupoFicha,
    titulo: 'Ficha clínica: Resumen',
    icono: Icons.dashboard_outlined,
    color: _rosa,
    colorOscuro: _rosaO,
    resumen: 'El resumen junta lo más importante del paciente en una sola vista.',
    pasos: [
      'Las alergias y condiciones de riesgo aparecen arriba, en rojo, en todas las pestañas.',
      '«Acciones rápidas» te lleva directo a una nueva evolución, receta, consentimiento, alergia, odontograma o presupuesto.',
      'En «Datos del paciente» toca Editar para completar fecha de nacimiento, contacto de emergencia y motivo de consulta.',
      'Si la historia médica lleva más de 6 meses sin confirmarse aparece un aviso: pregúntale al paciente si algo cambió y toca «Sigue igual» o «Revisar».',
    ],
    consejos: [
      'La próxima cita sale de la última evolución que tenga fecha programada; desde ahí envías el recordatorio por WhatsApp.',
      'El botón PDF de arriba genera la historia clínica completa.',
    ],
  ),
  'ficha_historia': AyudaTema(
    clave: 'ficha_historia',
    grupo: grupoFicha,
    titulo: 'Ficha clínica: Historia',
    icono: Icons.monitor_heart_outlined,
    color: _rojo,
    colorOscuro: _rojoO,
    resumen:
        'La historia médica reúne alergias, enfermedades, medicación y hábitos '
        'que pueden cambiar cómo atiendes al paciente.',
    pasos: [
      'Alergias: toca Agregar y elige el tipo, a qué es alérgico, la reacción y la gravedad.',
      'Condiciones: marca lo que el paciente confirma. Las de color rojo cambian la atención (por ejemplo diabetes, anticoagulantes o embarazo) y se destacan arriba.',
      'Medicación actual: agrega lo que toma, con su dosis y el motivo.',
      'Hábitos y salud bucal: tabaco, higiene, sangrado de encías, bruxismo, ansiedad ante el tratamiento…',
      'Al guardar cambios en la historia se anota la fecha de revisión.',
    ],
    consejos: [
      'Repasa la historia con el paciente al menos cada 6 meses.',
      'Las alergias graves salen primero.',
    ],
  ),
  'ficha_evolucion': AyudaTema(
    clave: 'ficha_evolucion',
    grupo: grupoFicha,
    titulo: 'Ficha clínica: Evolución',
    icono: Icons.timeline,
    color: _teal,
    colorOscuro: _tealO,
    resumen:
        'La evolución es la nota de cada cita: qué se hizo, con qué anestesia, '
        'qué indicaciones se dieron y cuándo es la próxima cita.',
    pasos: [
      'Toca «Nueva evolución» después de cada cita.',
      'Si hay presupuesto, marca los tratamientos realizados hoy: pasan a «Completado» automáticamente.',
      'Anota procedimiento, piezas, anestesia, presión arterial, materiales, observaciones e indicaciones (hay atajos para las más comunes).',
      'Programa la próxima cita: aparece en el Resumen, y desde el menú ⋮ de la evolución envías el recordatorio por WhatsApp.',
      'Toca una evolución para editarla o eliminarla.',
    ],
    consejos: [
      'Si desmarcas un tratamiento al editar una evolución, vuelve a «Aceptado» en el presupuesto.',
      'La nota conserva el nombre del tratamiento aunque luego lo quites del presupuesto.',
    ],
  ),
  'ficha_recetas': AyudaTema(
    clave: 'ficha_recetas',
    grupo: grupoFicha,
    titulo: 'Ficha clínica: Recetas',
    icono: Icons.medication_outlined,
    color: _azul,
    colorOscuro: _azulO,
    resumen:
        'Crea recetas con número correlativo, avisos de alergia y PDF para '
        'imprimir o compartir.',
    pasos: [
      'Toca «Nueva receta». Cada una recibe un número correlativo.',
      'Toca un medicamento sugerido para poner su nombre y presentación, o escríbelo. La posología (dosis y frecuencia) siempre la escribes tú.',
      'Si el nombre coincide con una alergia registrada, o es de la misma familia de medicamentos, se marca en rojo y pide confirmar antes de guardar.',
      'El botón PDF imprime o comparte la receta.',
    ],
    consejos: [
      'El aviso de alergias funciona por coincidencia de nombres: es una ayuda y no reemplaza tu criterio clínico.',
      'Si eliminas una receta, su número no se reutiliza.',
    ],
  ),
  'ficha_consentimientos': AyudaTema(
    clave: 'ficha_consentimientos',
    grupo: grupoFicha,
    titulo: 'Ficha clínica: Consentimientos',
    icono: Icons.draw_outlined,
    color: _violeta,
    colorOscuro: _violetaO,
    resumen:
        'Documentos de consentimiento informado que el paciente firma con el '
        'dedo en la pantalla y que quedan guardados en su ficha.',
    pasos: [
      'Toca «Nuevo consentimiento» y elige una plantilla (general, extracción, endodoncia, anestesia, blanqueamiento, implante o menor de edad) o «En blanco».',
      'Puedes editar el texto. Las marcas {firmante}, {paciente} y {doctor} se completan al guardar.',
      'Si el paciente es menor de edad, activa «Firma un representante legal».',
      'Toca «Firmar ahora»: se abre una pantalla completa donde se firma con el dedo.',
      'Si todavía no firma, guárdalo como «Pendiente» y fírmalo después desde su tarjeta. El PDF incluye la firma.',
    ],
    consejos: [
      'Revisa los textos según tu criterio profesional y la normativa vigente antes de usarlos.',
      'La firma se guarda dentro de la ficha del paciente.',
    ],
  ),

  // ------------------------------------------------------------------
  // FORMULARIOS (hojas)
  // ------------------------------------------------------------------
  'sheet_item': AyudaTema(
    clave: 'sheet_item',
    grupo: grupoHojas,
    titulo: 'Agregar o editar tratamiento',
    icono: Icons.medical_services_outlined,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen: 'Agrega o modifica un tratamiento del presupuesto.',
    pasos: [
      'Toca uno de los tratamientos frecuentes para llenar nombre y precio, o escríbelos.',
      'Ajusta el precio unitario y la cantidad: el total se calcula solo.',
      'Al editar puedes cambiar el estado (Pendiente, Aceptado, En progreso, Completado, Cancelado).',
    ],
    consejos: [
      'Para no cobrarlo pero conservar el historial, márcalo «Cancelado» en vez de eliminarlo.',
    ],
  ),
  'sheet_pago': AyudaTema(
    clave: 'sheet_pago',
    grupo: grupoHojas,
    titulo: 'Registrar pago',
    icono: Icons.payments_outlined,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen: 'Registra un abono del paciente y genera su recibo.',
    pasos: [
      'El monto ya viene con el saldo pendiente: cámbialo si abonó menos, o usa «Mitad del saldo».',
      'Elige la forma de pago; con transferencia, tarjeta o cheque puedes anotar el comprobante.',
      'Si el pago no es de hoy, cambia la fecha.',
      'Al guardar se crea el recibo con su número.',
    ],
    consejos: [
      'Si el monto supera el saldo te pedirá confirmar: el excedente queda a favor del paciente.',
    ],
  ),
  'sheet_ajustes': AyudaTema(
    clave: 'sheet_ajustes',
    grupo: grupoHojas,
    titulo: 'Descuento, vigencia y notas',
    icono: Icons.tune,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen: 'Ajustes generales del presupuesto.',
    pasos: [
      'El descuento es un porcentaje (de 0 a 100) que se aplica al subtotal.',
      'La vigencia indica hasta cuándo se respetan los precios; sale en el PDF y el presupuesto se marca como vencido al pasar la fecha.',
      'Las notas salen impresas en el PDF (condiciones, aclaraciones).',
    ],
  ),
  'sheet_precios': AyudaTema(
    clave: 'sheet_precios',
    grupo: grupoHojas,
    titulo: 'Precios por hallazgo',
    icono: Icons.sell_outlined,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen:
        'Define cuánto cuesta cada hallazgo del odontograma al generar el '
        'presupuesto.',
    pasos: [
      'Escribe el precio de cada hallazgo (caries, endodoncia, extracción…).',
      'Se usan solo para tratamientos nuevos: los que ya están en la lista conservan su precio.',
    ],
    consejos: ['Los valores iniciales son de referencia; ajústalos a tu tarifa.'],
  ),
  'sheet_hallazgos': AyudaTema(
    clave: 'sheet_hallazgos',
    grupo: grupoHojas,
    titulo: 'Hallazgos del odontograma',
    icono: Icons.grid_view,
    color: _naranja,
    colorOscuro: _naranjaO,
    resumen: 'Elige qué hallazgos del último odontograma pasan al presupuesto.',
    pasos: [
      'Marca o desmarca cada hallazgo, o usa «Marcar todos».',
      'Si un hallazgo automático que seguía pendiente ya no aparece en el odontograma, se ofrece quitarlo.',
      'Lo que ya estaba en el presupuesto no se duplica.',
    ],
  ),
  'sheet_datos': AyudaTema(
    clave: 'sheet_datos',
    grupo: grupoHojas,
    titulo: 'Datos del paciente',
    icono: Icons.badge_outlined,
    color: _rosa,
    colorOscuro: _rosaO,
    resumen: 'Datos personales, contacto de emergencia y motivo de consulta.',
    pasos: [
      'La fecha de nacimiento calcula la edad sola; si es menor de 18, los consentimientos proponen firma de representante.',
      'El contacto de emergencia queda con un botón para llamarlo desde el Resumen.',
      'El motivo de consulta se anota con las palabras del paciente.',
    ],
  ),
  'sheet_condiciones': AyudaTema(
    clave: 'sheet_condiciones',
    grupo: grupoHojas,
    titulo: 'Condiciones y antecedentes',
    icono: Icons.health_and_safety_outlined,
    color: _rojo,
    colorOscuro: _rojoO,
    resumen: 'Enfermedades y antecedentes médicos del paciente.',
    pasos: [
      'Marca las condiciones que el paciente confirma. Las rojas se destacan como alerta en toda la ficha.',
      'Anota grupo sanguíneo, cirugías, antecedentes familiares y observaciones.',
      'Al guardar, la historia queda marcada como revisada hoy.',
    ],
    consejos: ['Si el paciente no sabe algo, déjalo sin marcar en vez de suponer.'],
  ),
  'sheet_alergia': AyudaTema(
    clave: 'sheet_alergia',
    grupo: grupoHojas,
    titulo: 'Alergia',
    icono: Icons.warning_amber_rounded,
    color: _rojo,
    colorOscuro: _rojoO,
    resumen: 'Registra a qué es alérgico el paciente y qué tan grave es.',
    pasos: [
      'Elige el tipo y toca un ejemplo o escribe el nombre.',
      'Anota la reacción (toca las opciones para agregarlas).',
      'Marca la gravedad: las graves salen primero y en rojo intenso.',
    ],
    consejos: [
      'Las alergias registradas activan el aviso al crear recetas.',
    ],
  ),
  'sheet_medicamento': AyudaTema(
    clave: 'sheet_medicamento',
    grupo: grupoHojas,
    titulo: 'Medicación actual',
    icono: Icons.medication_liquid_outlined,
    color: _rojo,
    colorOscuro: _rojoO,
    resumen: 'Medicamentos que el paciente toma actualmente.',
    pasos: [
      'Escribe el nombre del medicamento.',
      'Opcionalmente anota la dosis y para qué lo toma.',
    ],
    consejos: [
      'Pregunta especialmente por anticoagulantes, antihipertensivos y medicación para diabetes.',
    ],
  ),
  'sheet_habitos': AyudaTema(
    clave: 'sheet_habitos',
    grupo: grupoHojas,
    titulo: 'Hábitos y salud bucal',
    icono: Icons.sentiment_satisfied_alt_outlined,
    color: _teal,
    colorOscuro: _tealO,
    resumen: 'Hábitos de higiene y antecedentes odontológicos.',
    pasos: [
      'Marca tabaco y alcohol, y usa los interruptores para hilo dental, enjuague, bruxismo, sangrado y sensibilidad.',
      'Cepillados al día: usa − y +; «S/D» significa sin dato.',
      'La ansiedad ante el tratamiento va de 1 (nada) a 5 (mucha); toca otra vez la opción elegida para quitarla.',
    ],
  ),
  'sheet_evolucion': AyudaTema(
    clave: 'sheet_evolucion',
    grupo: grupoHojas,
    titulo: 'Evolución (nota de la cita)',
    icono: Icons.edit_note,
    color: _teal,
    colorOscuro: _tealO,
    resumen: 'Registra lo que se hizo en la cita.',
    pasos: [
      'Marca los tratamientos del presupuesto realizados hoy: se pasan a «Completado» y rellenan procedimiento y piezas.',
      'Usa los atajos para anestesia e indicaciones; se pueden combinar y editar.',
      'Programa la próxima cita si corresponde.',
    ],
    consejos: [
      'Debes indicar al menos el procedimiento o marcar un tratamiento del presupuesto.',
    ],
  ),
  'sheet_receta': AyudaTema(
    clave: 'sheet_receta',
    grupo: grupoHojas,
    titulo: 'Receta',
    icono: Icons.receipt_long_outlined,
    color: _azul,
    colorOscuro: _azulO,
    resumen: 'Arma una receta con uno o varios medicamentos.',
    pasos: [
      'Toca un medicamento sugerido para agregar su nombre y presentación.',
      'Escribe la posología de cada uno: es obligatoria.',
      'Si algún medicamento coincide con una alergia, se avisa en rojo y se pide confirmar.',
    ],
    consejos: ['Con «Agregar otro medicamento» puedes recetar varios en el mismo papel.'],
  ),
  'sheet_consentimiento': AyudaTema(
    clave: 'sheet_consentimiento',
    grupo: grupoHojas,
    titulo: 'Consentimiento informado',
    icono: Icons.gavel_outlined,
    color: _violeta,
    colorOscuro: _violetaO,
    resumen: 'Crea el documento, elige quién firma y recoge la firma.',
    pasos: [
      'Elige una plantilla y edita el texto si hace falta.',
      'Indica quién firma; si es un representante, anota su nombre, cédula y parentesco.',
      'Toca «Firmar ahora» para firmar en pantalla, o guarda sin firma y fírmalo después.',
    ],
    consejos: ['Las marcas entre llaves se reemplazan por los datos reales al guardar.'],
  ),
  'firma': AyudaTema(
    clave: 'firma',
    grupo: grupoHojas,
    titulo: 'Firma en pantalla',
    icono: Icons.draw,
    color: _violeta,
    colorOscuro: _violetaO,
    resumen: 'Pantalla completa para que el paciente firme con el dedo.',
    pasos: [
      'Pide al paciente que firme dentro del recuadro.',
      '«Deshacer» quita el último trazo y «Borrar todo» limpia el recuadro.',
      'Toca «Aceptar firma» para guardarla.',
    ],
    consejos: [
      'Es una firma dibujada en pantalla. Si necesitas firma manuscrita, imprime el PDF y fírmalo en papel.',
    ],
  ),

  // ------------------------------------------------------------------
  // RESPALDO
  // ------------------------------------------------------------------
  'nube': AyudaTema(
    clave: 'nube',
    grupo: grupoNube,
    titulo: 'Respaldo en la nube',
    icono: Icons.cloud_done_outlined,
    color: _indigo,
    colorOscuro: _indigoO,
    resumen:
        'Tus datos se guardan primero en el teléfono (por eso funciona sin '
        'internet) y se respaldan solos en la nube. Cada paciente tiene su '
        'propio documento en la nube.',
    pasos: [
      'Cada cambio se guarda al instante en el teléfono y se sube en segundo plano; solo se envía lo que cambió.',
      'Al abrir la app con sesión iniciada, si hay datos en la nube se descargan. Si el teléfono tiene cambios que no se subieron, se conservan los del teléfono y se suben.',
      'La primera vez, tus datos se pasan solos del formato anterior (un solo documento) al nuevo (un documento por paciente). El respaldo anterior no se borra.',
      'Antes de migrar se guarda una copia de seguridad del archivo local en el teléfono.',
    ],
    consejos: [
      'Si el estado muestra error de PERMISOS, agrega en Firebase la regla para subcolecciones (está copiable en el Centro de ayuda).',
      'Edita desde un solo dispositivo a la vez para evitar que un teléfono pise los cambios del otro.',
      '«Sincronizar ahora» fuerza la subida cuando quieras estar seguro.',
    ],
  ),
};

/// Reglas de Firestore que necesita el formato nuevo (se muestran copiables
/// en el Centro de ayuda).
const String reglasFirestoreSugeridas = '''match /usuarios/{uid}/{documento=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}''';
