/// Formas de pago que acepta el consultorio.
enum MetodoPago { efectivo, transferencia, tarjeta, cheque, otro }

const Map<MetodoPago, String> etiquetaMetodoPago = {
  MetodoPago.efectivo: 'Efectivo',
  MetodoPago.transferencia: 'Transferencia',
  MetodoPago.tarjeta: 'Tarjeta',
  MetodoPago.cheque: 'Cheque',
  MetodoPago.otro: 'Otro',
};

/// Un abono o pago registrado contra el presupuesto del paciente.
///
/// Los pagos nunca se borran: si hubo un error se "anulan" (queda el
/// historial y el motivo), igual que en cualquier sistema de caja serio.
/// Un pago anulado no cuenta en los totales.
class Pago {
  String id;

  /// Número correlativo de recibo dentro del presupuesto (1, 2, 3...).
  /// Nunca se reutiliza, ni siquiera si el pago se anula.
  int numero;
  DateTime fecha;
  double monto;
  MetodoPago metodo;

  /// N.º de transferencia, voucher, cheque, etc. (opcional).
  String referencia;
  String nota;
  bool anulado;
  String motivoAnulacion;
  DateTime? fechaAnulacion;

  Pago({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.monto,
    this.metodo = MetodoPago.efectivo,
    this.referencia = '',
    this.nota = '',
    this.anulado = false,
    this.motivoAnulacion = '',
    this.fechaAnulacion,
  });

  /// "0001", "0002"... tal como se imprime en el recibo.
  String get numeroTexto => numero.toString().padLeft(4, '0');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'fecha': fecha.toIso8601String(),
      'monto': monto,
      'metodo': metodo.name,
      'referencia': referencia,
      'nota': nota,
      'anulado': anulado,
      'motivoAnulacion': motivoAnulacion,
      'fechaAnulacion': fechaAnulacion?.toIso8601String(),
    };
  }

  factory Pago.fromMap(Map<String, dynamic> map) {
    var metodo = MetodoPago.otro;
    for (final m in MetodoPago.values) {
      if (m.name == map['metodo']) {
        metodo = m;
        break;
      }
    }
    return Pago(
      id: map['id'] ?? '',
      numero: (map['numero'] as num?)?.toInt() ?? 0,
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      metodo: metodo,
      referencia: map['referencia'] ?? '',
      nota: map['nota'] ?? '',
      anulado: map['anulado'] ?? false,
      motivoAnulacion: map['motivoAnulacion'] ?? '',
      fechaAnulacion: map['fechaAnulacion'] == null
          ? null
          : DateTime.tryParse(map['fechaAnulacion'].toString()),
    );
  }
}
