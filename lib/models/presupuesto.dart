import 'odontograma.dart';

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

class ItemPresupuesto {
  String id;
  String? piezaFdi;
  CaraDental? cara;
  EstadoDiente? estadoOrigen; // null si el ítem se agregó manualmente
  String descripcion;
  double precio;
  EstadoTratamiento estado;
  bool generadoAutomaticamente;

  ItemPresupuesto({
    required this.id,
    this.piezaFdi,
    this.cara,
    this.estadoOrigen,
    required this.descripcion,
    required this.precio,
    this.estado = EstadoTratamiento.pendiente,
    this.generadoAutomaticamente = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piezaFdi': piezaFdi,
      'cara': cara?.name,
      'estadoOrigen': estadoOrigen?.name,
      'descripcion': descripcion,
      'precio': precio,
      'estado': estado.name,
      'generadoAutomaticamente': generadoAutomaticamente,
    };
  }

  factory ItemPresupuesto.fromMap(Map<String, dynamic> map) {
    return ItemPresupuesto(
      id: map['id'] ?? '',
      piezaFdi: map['piezaFdi'],
      cara: map['cara'] == null
          ? null
          : CaraDental.values.firstWhere((c) => c.name == map['cara']),
      estadoOrigen: map['estadoOrigen'] == null
          ? null
          : EstadoDiente.values.firstWhere((e) => e.name == map['estadoOrigen']),
      descripcion: map['descripcion'] ?? '',
      precio: (map['precio'] as num?)?.toDouble() ?? 0,
      estado: EstadoTratamiento.values
          .firstWhere((e) => e.name == map['estado'], orElse: () => EstadoTratamiento.pendiente),
      generadoAutomaticamente: map['generadoAutomaticamente'] ?? false,
    );
  }
}

/// Plan de tratamiento / presupuesto del paciente. Es un único documento
/// vivo (no una lista por fecha): se va actualizando a medida que el
/// tratamiento avanza, igual que un presupuesto real de clínica dental.
class Presupuesto {
  DateTime fechaCreacion;
  List<ItemPresupuesto> items;
  double descuentoPorcentaje;
  Map<EstadoDiente, double> precios;

  Presupuesto({
    DateTime? fechaCreacion,
    List<ItemPresupuesto>? items,
    this.descuentoPorcentaje = 0,
    Map<EstadoDiente, double>? precios,
  })  : fechaCreacion = fechaCreacion ?? DateTime.now(),
        items = items ?? [],
        precios = precios ?? Map.of(preciosPorDefecto);

  double get subtotal => items
      .where((i) => i.estado != EstadoTratamiento.cancelado)
      .fold(0.0, (s, i) => s + i.precio);

  double get descuento => subtotal * (descuentoPorcentaje / 100);

  double get total => subtotal - descuento;

  Map<String, dynamic> toMap() {
    return {
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
      'descuentoPorcentaje': descuentoPorcentaje,
      'precios': precios.map((k, v) => MapEntry(k.name, v)),
    };
  }

  factory Presupuesto.fromMap(Map<String, dynamic> map) {
    final rawPrecios = (map['precios'] as Map?) ?? {};
    final rawItems = (map['items'] as List?) ?? [];
    return Presupuesto(
      fechaCreacion:
          DateTime.tryParse(map['fechaCreacion'] ?? '') ?? DateTime.now(),
      items: rawItems
          .map((i) => ItemPresupuesto.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      descuentoPorcentaje: (map['descuentoPorcentaje'] as num?)?.toDouble() ?? 0,
      precios: {
        for (final e in preciosPorDefecto.keys)
          e: (rawPrecios[e.name] as num?)?.toDouble() ?? preciosPorDefecto[e]!,
      },
    );
  }
}
