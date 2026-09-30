import 'package:flutter_test/flutter_test.dart';
import 'package:odontometas/models/meta_goal.dart';
import 'package:odontometas/models/paciente.dart';
import 'package:odontometas/models/pago.dart';
import 'package:odontometas/models/presupuesto.dart';
import 'package:odontometas/services/caja_service.dart';

Pago _pago(int n, double monto, DateTime fecha,
        {MetodoPago metodo = MetodoPago.efectivo, bool anulado = false}) =>
    Pago(
      id: 'p$n${fecha.millisecondsSinceEpoch}',
      numero: n,
      fecha: fecha,
      monto: monto,
      metodo: metodo,
      anulado: anulado,
    );

Paciente _paciente(String nombre, double precio, List<Pago> pagos,
    {EstadoTratamiento estado = EstadoTratamiento.aceptado}) {
  return Paciente(
    nombre: nombre,
    presupuesto: Presupuesto(
      items: [
        ItemPresupuesto(
          id: nombre,
          descripcion: 'Tratamiento',
          precio: precio,
          estado: estado,
        ),
      ],
      pagos: pagos,
    ),
  );
}

MetaGoal _meta(List<Paciente> pacientes) => MetaGoal(
      id: 'm',
      titulo: 'Meta',
      metaNumero: pacientes.length,
      pacientes: pacientes,
    );

void main() {
  group('RangoFechas', () {
    test('la semana va de lunes a domingo', () {
      // 2026-09-30 es miércoles
      final r = RangoFechas.semana(DateTime(2026, 9, 30, 15, 20));
      expect(r.inicio, DateTime(2026, 9, 28));
      expect(r.ultimoDia, DateTime(2026, 10, 4));
      expect(r.dias, 7);
    });

    test('el mes incluye el último día y no el siguiente', () {
      final r = RangoFechas.mes(DateTime(2026, 2, 10));
      expect(r.contiene(DateTime(2026, 2, 28, 23, 59)), isTrue);
      expect(r.contiene(DateTime(2026, 3, 1)), isFalse);
      expect(r.dias, 28);
    });

    test('entre() acepta las fechas en cualquier orden e incluye ambos días', () {
      final r = RangoFechas.entre(DateTime(2026, 5, 10), DateTime(2026, 5, 3));
      expect(r.inicio, DateTime(2026, 5, 3));
      expect(r.contiene(DateTime(2026, 5, 10, 22)), isTrue);
    });

    test('el período anterior tiene la misma duración', () {
      final r = RangoFechas.entre(DateTime(2026, 5, 10), DateTime(2026, 5, 12));
      final a = r.anteriorMismaDuracion();
      expect(a.dias, 3);
      expect(a.fin, r.inicio);
    });
  });

  group('Resumen de caja', () {
    final hoy = DateTime(2026, 9, 29, 10);
    final ayer = DateTime(2026, 9, 28, 16);
    final mesPasado = DateTime(2026, 8, 15, 9);

    final ana = _paciente('Ana', 200, [
      _pago(1, 50, hoy),
      _pago(2, 30, ayer, metodo: MetodoPago.transferencia),
      _pago(3, 999, ayer, anulado: true),
      _pago(4, 20, mesPasado),
    ]);
    final beto = _paciente('Beto', 100, [
      _pago(1, 40, hoy, metodo: MetodoPago.tarjeta),
    ]);
    final metas = [_meta([ana, beto, null])];

    test('suma solo pagos vigentes del período y agrupa por método y día', () {
      final r = CajaService.resumir(
        CajaService.movimientos(metas),
        RangoFechas.mes(DateTime(2026, 9, 1)),
      );
      expect(r.total, 120.0); // 50 + 30 + 40; el anulado no cuenta
      expect(r.cantidad, 3);
      expect(r.porMetodo[MetodoPago.efectivo], 50.0);
      expect(r.porMetodo[MetodoPago.transferencia], 30.0);
      expect(r.porMetodo[MetodoPago.tarjeta], 40.0);
      expect(r.porDia[DateTime(2026, 9, 29)], 90.0);
      expect(r.porDia[DateTime(2026, 9, 28)], 30.0);
      expect(r.anulados.length, 1);
      expect(r.anuladosMonto, 999.0);
      expect(r.promedioPorPago, 40.0);
    });

    test('el más reciente aparece primero', () {
      final r = CajaService.resumir(
        CajaService.movimientos(metas),
        RangoFechas.mes(DateTime(2026, 9, 1)),
      );
      expect(r.movimientos.first.pago.fecha.day, 29);
      expect(r.movimientos.last.pago.fecha.day, 28);
    });

    test('un período sin cobros da cero sin fallar', () {
      final r = CajaService.resumir(
        CajaService.movimientos(metas),
        RangoFechas.mes(DateTime(2025, 1, 1)),
      );
      expect(r.total, 0.0);
      expect(r.cantidad, 0);
      expect(r.promedioPorPago, 0.0);
    });
  });

  group('Por cobrar', () {
    test('lista solo saldos pendientes de tratamientos comprometidos', () {
      final debe = _paciente('Debe', 100, [_pago(1, 30, DateTime(2026, 9, 1))]);
      final alDia = _paciente('AlDia', 100, [_pago(1, 100, DateTime(2026, 9, 1))]);
      final sinAprobar = _paciente('SinAprobar', 500, [],
          estado: EstadoTratamiento.pendiente);
      final aceptadoSinPago = _paciente('Aceptado', 250, []);
      final mayor = _paciente('Mayor', 900, [_pago(1, 100, DateTime(2026, 9, 2))]);
      final deudas = CajaService.porCobrar(
        [_meta([debe, alDia, sinAprobar, aceptadoSinPago, mayor, null])],
      );
      expect(deudas.map((d) => d.paciente.nombre).toList(),
          ['Mayor', 'Aceptado', 'Debe']);
      expect(deudas.first.saldo, 800.0);
      expect(deudas.last.saldo, 70.0);
      expect(deudas.last.ultimoPago, DateTime(2026, 9, 1));
      expect(CajaService.totalPorCobrar(deudas), 1120.0);
    });

    test('un pago anulado no reduce la deuda', () {
      final p = _paciente('Ana', 100, [
        _pago(1, 100, DateTime(2026, 9, 1), anulado: true),
      ]);
      final deudas = CajaService.porCobrar([_meta([p])]);
      expect(deudas.single.saldo, 100.0);
    });
  });
}
