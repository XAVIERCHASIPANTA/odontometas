import 'package:intl/intl.dart';
import 'odontograma.dart';
import 'pago.dart';

enum EstadoTratamiento { pendiente, aceptado, enProgreso, completado, cancelado }

const Map<EstadoTratamiento, String> etiquetaEstadoTratamiento = {
  EstadoTratamiento.pendiente: 'Pendiente',
  EstadoTratamiento.aceptado: 'Aceptado',
  EstadoTratamiento.enProgreso: 'En progreso',
  EstadoTratamiento.completado: 'Completado',
  EstadoTratamiento.cancelado: 'Cancelado',
};

const Map<EstadoTratamiento, int> colorEstadoTratamiento = {
  EstadoTratamiento.pendiente: 0xFF9E9E9E,
  EstadoTratamiento.aceptado: 0xFF1E88E5,
  EstadoTratamiento.enProgreso: 0xFFFB8C00,
  EstadoTratamiento.completado: 0xFF43A047,
  EstadoTratamiento.cancelado: 0xFFD32F2F,
};

/// Catálogo de precios por defecto (USD). Editable desde la propia pantalla
/// de presupuesto; cada clínica ajusta la tarifa a la suya.
const Map<EstadoDiente, double> preciosPorDefecto = {
  EstadoDiente.caries: 25,
  EstadoDiente.obturado: 25,
  EstadoDiente.sellante: 15,
  EstadoDiente.fracturado: 30,
  EstadoDiente.endodoncia: 120,
  EstadoDiente.extraccionIndicada: 20,
  EstadoDiente.implante: 600,
  EstadoDiente.protesisFija: 250,
  EstadoDiente.puente: 400,
};

/// Prestación frecuente para agregar con un toque desde "Agregar
/// tratamiento". Los precios son de referencia: siempre se pueden ajustar
/// antes de guardar.
class PrestacionCatalogo {
  final String nombre;
  final double precio;
  const PrestacionCatalogo(this.nombre, this.precio);
}

const List<PrestacionCatalogo> catalogoPrestaciones = [
  PrestacionCatalogo('Consulta / valoración', 15),
  PrestacionCatalogo('Profilaxis (limpieza)', 30),
  PrestacionCatalogo('Raspaje y alisado radicular', 50),
  PrestacionCatalogo('Blanqueamiento dental', 150),
  PrestacionCatalogo('Resina (restauración)', 25),
  PrestacionCatalogo('Endodoncia multirradicular', 180),
  PrestacionCatalogo('Extracción simple', 20),
  PrestacionCatalogo('Extracción de cordal', 60),
  PrestacionCatalogo('Corona de porcelana', 250),
  PrestacionCatalogo('Carilla estética', 200),
  PrestacionCatalogo('Placa de descarga', 120),
  PrestacionCatalogo('Control de ortodoncia', 40),
  PrestacionCatalogo('Radiografía periapical', 5),
  PrestacionCatalogo('Radiografía panorámica', 25),
];

/// Redondea a centavos para evitar errores de coma flotante al sumar dinero.
double redondear2(double v) => (v * 100).round() / 100;

final NumberFormat _formatoMoneda = NumberFormat('#,##0.00', 'en_US');

/// "$1,234.50" (con signo menos delante si es negativo).
String formatoMoneda(double v) {
  final texto = '\$${_formatoMoneda.format(v.abs())}';
  return v < -0.004 ? '-$texto' : texto;
}

T? _enumPorNombre<T extends Enum>(List<T> valores, Object? nombre) {
  if (nombre == null) {
    return null;
  }
  for (final v in valores) {
    if (v.name == nombre) {
      return v;
    }
  }
  return null;
}

class ItemPresupuesto {
  String id;
  String? piezaFdi;
  CaraDental? cara;
  EstadoDiente? estadoOrigen; // null si el ítem se agregó manualmente
  String descripcion;

  /// Precio UNITARIO. El total de la línea es precio × cantidad.
  double precio;
  int cantidad;
  EstadoTratamiento estado;
  bool generadoAutomaticamente;
  String notas;
  DateTime? fechaRealizacion;

  ItemPresupuesto({
    required this.id,
    this.piezaFdi,
    this.cara,
    this.estadoOrigen,
    required this.descripcion,
    required this.precio,
    this.cantidad = 1,
    this.estado = EstadoTratamiento.pendiente,
    this.generadoAutomaticamente = false,
    this.notas = '',
    this.fechaRealizacion,
  });

  double get total => redondear2(precio * cantidad);

  /// Identifica el hallazgo del odontograma del que nació el ítem, para no
  /// duplicarlo al volver a generar el presupuesto.
  String get claveOrigen =>
      '${piezaFdi ?? ''}|${cara?.name ?? ''}|${estadoOrigen?.name ?? ''}';

  /// Cambia el estado y mantiene la fecha de realización coherente.
  void cambiarEstado(EstadoTratamiento nuevo) {
    if (nuevo == estado) {
      return;
    }
    estado = nuevo;
    if (nuevo == EstadoTratamiento.completado) {
      fechaRealizacion ??= DateTime.now();
    } else {
      fechaRealizacion = null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piezaFdi': piezaFdi,
      'cara': cara?.name,
      'estadoOrigen': estadoOrigen?.name,
      'descripcion': descripcion,
      'precio': precio,
      'cantidad': cantidad,
      'estado': estado.name,
      'generadoAutomaticamente': generadoAutomaticamente,
      'notas': notas,
      'fechaRealizacion': fechaRealizacion?.toIso8601String(),
    };
  }

  factory ItemPresupuesto.fromMap(Map<String, dynamic> map) {
    final cantidad = (map['cantidad'] as num?)?.toInt() ?? 1;
    return ItemPresupuesto(
      id: map['id'] ?? '',
      piezaFdi: map['piezaFdi'],
      cara: _enumPorNombre(CaraDental.values, map['cara']),
      estadoOrigen: _enumPorNombre(EstadoDiente.values, map['estadoOrigen']),
      descripcion: map['descripcion'] ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      cantidad: cantidad < 1 ? 1 : cantidad,
      estado: _enumPorNombre(EstadoTratamiento.values, map['estado']) ??
          EstadoTratamiento.pendiente,
      generadoAutomaticamente: map['generadoAutomaticamente'] ?? false,
      notas: map['notas'] ?? '',
      fechaRealizacion: map['fechaRealizacion'] == null
          ? null
          : DateTime.tryParse(map['fechaRealizacion'].toString()),
    );
  }
}

/// Situación de cobro del presupuesto.
enum EstadoCobro { sinPresupuesto, pendiente, parcial, pagado, saldoAFavor }

const Map<EstadoCobro, String> etiquetaEstadoCobro = {
  EstadoCobro.sinPresupuesto: 'Sin presupuesto',
  EstadoCobro.pendiente: 'Sin pagos',
  EstadoCobro.parcial: 'Pago parcial',
  EstadoCobro.pagado: 'Pagado',
  EstadoCobro.saldoAFavor: 'Saldo a favor',
};

const Map<EstadoCobro, int> colorEstadoCobro = {
  EstadoCobro.sinPresupuesto: 0xFF9E9E9E,
  EstadoCobro.pendiente: 0xFFE53935,
  EstadoCobro.parcial: 0xFFFB8C00,
  EstadoCobro.pagado: 0xFF43A047,
  EstadoCobro.saldoAFavor: 0xFF1E88E5,
};

/// Plan de tratamiento / presupuesto del paciente. Es un único documento
/// vivo (no una lista por fecha): se va actualizando a medida que el
/// tratamiento avanza, igual que un presupuesto real de clínica dental.
/// Los pagos (abonos) del paciente viven dentro del mismo documento.
class Presupuesto {
  DateTime fechaCreacion;
  List<ItemPresupuesto> items;
  double descuentoPorcentaje;
  Map<EstadoDiente, double> precios;
  List<Pago> pagos;
  String notas;

  /// Fecha hasta la que el precio está vigente (opcional).
  DateTime? validoHasta;

  Presupuesto({
    DateTime? fechaCreacion,
    List<ItemPresupuesto>? items,
    this.descuentoPorcentaje = 0,
    Map<EstadoDiente, double>? precios,
    List<Pago>? pagos,
    this.notas = '',
    this.validoHasta,
  })  : fechaCreacion = fechaCreacion ?? DateTime.now(),
        items = items ?? [],
        precios = precios ?? Map.of(preciosPorDefecto),
        pagos = pagos ?? [];

  // ---------- Tratamientos ----------

  Iterable<ItemPresupuesto> get itemsActivos =>
      items.where((i) => i.estado != EstadoTratamiento.cancelado);

  int get cantidadCompletados =>
      items.where((i) => i.estado == EstadoTratamiento.completado).length;

  double get subtotal =>
      redondear2(itemsActivos.fold(0.0, (s, i) => s + i.total));

  double get descuento => redondear2(subtotal * (descuentoPorcentaje / 100));

  double get total => redondear2(subtotal - descuento);

  bool get vencido {
    final limite = validoHasta;
    if (limite == null) {
      return false;
    }
    final finDelDia = DateTime(limite.year, limite.month, limite.day, 23, 59, 59);
    return DateTime.now().isAfter(finDelDia);
  }

  // ---------- Pagos ----------

  Iterable<Pago> get pagosVigentes => pagos.where((p) => !p.anulado);

  double get totalPagado =>
      redondear2(pagosVigentes.fold(0.0, (s, p) => s + p.monto));

  /// Lo que todavía debe el paciente (negativo = saldo a favor).
  double get saldo => redondear2(total - totalPagado);

  int get siguienteNumeroRecibo {
    var maximo = 0;
    for (final p in pagos) {
      if (p.numero > maximo) {
        maximo = p.numero;
      }
    }
    return maximo + 1;
  }

  /// Total abonado hasta un recibo dado (inclusive), sin contar anulados.
  double pagadoHastaRecibo(int numero) => redondear2(pagosVigentes
      .where((p) => p.numero <= numero)
      .fold(0.0, (s, p) => s + p.monto));

  EstadoCobro get estadoCobro {
    if (total <= 0 && totalPagado <= 0) {
      return EstadoCobro.sinPresupuesto;
    }
    if (saldo < -0.004) {
      return EstadoCobro.saldoAFavor;
    }
    if (saldo <= 0.004) {
      return EstadoCobro.pagado;
    }
    return totalPagado > 0 ? EstadoCobro.parcial : EstadoCobro.pendiente;
  }

  Map<String, dynamic> toMap() {
    return {
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
      'descuentoPorcentaje': descuentoPorcentaje,
      'precios': precios.map((k, v) => MapEntry(k.name, v)),
      'pagos': pagos.map((p) => p.toMap()).toList(),
      'notas': notas,
      'validoHasta': validoHasta?.toIso8601String(),
    };
  }

  factory Presupuesto.fromMap(Map<String, dynamic> map) {
    final rawPrecios = (map['precios'] as Map?) ?? {};
    final rawItems = (map['items'] as List?) ?? [];
    final rawPagos = (map['pagos'] as List?) ?? [];
    return Presupuesto(
      fechaCreacion:
          DateTime.tryParse(map['fechaCreacion']?.toString() ?? '') ??
              DateTime.now(),
      items: rawItems
          .map((i) => ItemPresupuesto.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      descuentoPorcentaje: (map['descuentoPorcentaje'] as num?)?.toDouble() ?? 0,
      precios: {
        for (final e in preciosPorDefecto.keys)
          e: (rawPrecios[e.name] as num?)?.toDouble() ?? preciosPorDefecto[e]!,
      },
      pagos: rawPagos
          .map((p) => Pago.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
      notas: map['notas'] ?? '',
      validoHasta: map['validoHasta'] == null
          ? null
          : DateTime.tryParse(map['validoHasta'].toString()),
    );
  }
}
