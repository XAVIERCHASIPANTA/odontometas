import '../models/meta_goal.dart';
import '../models/paciente.dart';
import '../models/pago.dart';
import '../models/presupuesto.dart';

/// Un pago junto con el paciente que lo hizo.
class MovimientoCaja {
  final Paciente paciente;
  final Pago pago;
  const MovimientoCaja(this.paciente, this.pago);
}

/// Rango de fechas [inicio, fin): el fin es exclusivo (medianoche del día
/// siguiente al último día incluido).
class RangoFechas {
  final DateTime inicio;
  final DateTime fin;
  const RangoFechas(this.inicio, this.fin);

  bool contiene(DateTime f) => !f.isBefore(inicio) && f.isBefore(fin);

  /// Cantidad de días; se redondea para no fallar en zonas con cambio de hora.
  int get dias => (fin.difference(inicio).inHours / 24).round();

  /// Último día incluido (sin hora).
  DateTime get ultimoDia => fin.subtract(const Duration(days: 1));

  static DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  factory RangoFechas.dia(DateTime d) {
    final i = soloFecha(d);
    return RangoFechas(i, DateTime(i.year, i.month, i.day + 1));
  }

  /// Semana de lunes a domingo que contiene [d].
  factory RangoFechas.semana(DateTime d) {
    final i = soloFecha(d);
    final lunes = DateTime(i.year, i.month, i.day - (i.weekday - 1));
    return RangoFechas(lunes, DateTime(lunes.year, lunes.month, lunes.day + 7));
  }

  factory RangoFechas.mes(DateTime d) =>
      RangoFechas(DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 1));

  /// Desde [desde] hasta [hasta], ambos días incluidos.
  factory RangoFechas.entre(DateTime desde, DateTime hasta) {
    final a = soloFecha(desde);
    final b = soloFecha(hasta);
    final inicio = a.isBefore(b) ? a : b;
    final ultimo = a.isBefore(b) ? b : a;
    return RangoFechas(inicio, DateTime(ultimo.year, ultimo.month, ultimo.day + 1));
  }

  /// El período inmediatamente anterior, con la misma duración.
  RangoFechas anteriorMismaDuracion() {
    final n = dias;
    return RangoFechas(
      DateTime(inicio.year, inicio.month, inicio.day - n),
      inicio,
    );
  }
}

class ResumenCaja {
  /// Total cobrado (sin pagos anulados).
  final double total;
  final int cantidad;
  final Map<MetodoPago, double> porMetodo;

  /// Cobrado por día (clave = fecha sin hora).
  final Map<DateTime, double> porDia;

  /// Pagos vigentes del período, del más reciente al más antiguo.
  final List<MovimientoCaja> movimientos;
  final List<MovimientoCaja> anulados;
  final double anuladosMonto;

  const ResumenCaja({
    required this.total,
    required this.cantidad,
    required this.porMetodo,
    required this.porDia,
    required this.movimientos,
    required this.anulados,
    required this.anuladosMonto,
  });

  double get promedioPorPago => cantidad == 0 ? 0 : redondear2(total / cantidad);
}

/// Paciente con saldo pendiente.
class DeudaPaciente {
  final Paciente paciente;
  final double total;
  final double pagado;
  final double saldo;
  final DateTime? ultimoPago;
  const DeudaPaciente({
    required this.paciente,
    required this.total,
    required this.pagado,
    required this.saldo,
    required this.ultimoPago,
  });
}

/// Lógica pura (sin pantallas) de la caja: fácil de probar.
class CajaService {
  /// Todos los pagos de todos los pacientes, incluidos los anulados.
  static List<MovimientoCaja> movimientos(List<MetaGoal> metas) {
    final resultado = <MovimientoCaja>[];
    for (final meta in metas) {
      for (final paciente in meta.pacientes) {
        final presupuesto = paciente?.presupuesto;
        if (paciente == null || presupuesto == null) {
          continue;
        }
        for (final pago in presupuesto.pagos) {
          resultado.add(MovimientoCaja(paciente, pago));
        }
      }
    }
    return resultado;
  }

  static ResumenCaja resumir(List<MovimientoCaja> todos, RangoFechas rango) {
    final enRango = todos.where((m) => rango.contiene(m.pago.fecha)).toList()
      ..sort((a, b) {
        final c = b.pago.fecha.compareTo(a.pago.fecha);
        return c != 0 ? c : b.pago.numero.compareTo(a.pago.numero);
      });
    final vigentes = enRango.where((m) => !m.pago.anulado).toList();
    final anulados = enRango.where((m) => m.pago.anulado).toList();

    final porMetodo = <MetodoPago, double>{};
    final porDia = <DateTime, double>{};
    var total = 0.0;
    for (final m in vigentes) {
      total += m.pago.monto;
      porMetodo[m.pago.metodo] = (porMetodo[m.pago.metodo] ?? 0) + m.pago.monto;
      final dia = RangoFechas.soloFecha(m.pago.fecha);
      porDia[dia] = (porDia[dia] ?? 0) + m.pago.monto;
    }
    return ResumenCaja(
      total: redondear2(total),
      cantidad: vigentes.length,
      porMetodo: porMetodo.map((k, v) => MapEntry(k, redondear2(v))),
      porDia: porDia.map((k, v) => MapEntry(k, redondear2(v))),
      movimientos: vigentes,
      anulados: anulados,
      anuladosMonto:
          redondear2(anulados.fold(0.0, (s, m) => s + m.pago.monto)),
    );
  }

  /// Pacientes con saldo pendiente, del que más debe al que menos.
  ///
  /// Solo cuentan los que ya tienen un compromiso real: al menos un pago
  /// registrado o algún tratamiento aceptado / en progreso / completado.
  /// Un presupuesto que el paciente todavía no aprobó no es una deuda.
  static List<DeudaPaciente> porCobrar(List<MetaGoal> metas) {
    final resultado = <DeudaPaciente>[];
    for (final meta in metas) {
      for (final paciente in meta.pacientes) {
        final p = paciente?.presupuesto;
        if (paciente == null || p == null || p.items.isEmpty) {
          continue;
        }
        final comprometido = p.pagosVigentes.isNotEmpty ||
            p.items.any((i) =>
                i.estado == EstadoTratamiento.aceptado ||
                i.estado == EstadoTratamiento.enProgreso ||
                i.estado == EstadoTratamiento.completado);
        if (!comprometido || p.saldo <= 0.004) {
          continue;
        }
        DateTime? ultimo;
        for (final pago in p.pagosVigentes) {
          if (ultimo == null || pago.fecha.isAfter(ultimo)) {
            ultimo = pago.fecha;
          }
        }
        resultado.add(DeudaPaciente(
          paciente: paciente,
          total: p.total,
          pagado: p.totalPagado,
          saldo: p.saldo,
          ultimoPago: ultimo,
        ));
      }
    }
    resultado.sort((a, b) => b.saldo.compareTo(a.saldo));
    return resultado;
  }

  static double totalPorCobrar(List<DeudaPaciente> deudas) =>
      redondear2(deudas.fold(0.0, (s, d) => s + d.saldo));
}
