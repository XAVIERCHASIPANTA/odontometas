import 'package:flutter_test/flutter_test.dart';
import 'package:odontometas/models/pago.dart';
import 'package:odontometas/models/presupuesto.dart';

Pago _pago(int numero, double monto) =>
    Pago(id: 'p$numero', numero: numero, fecha: DateTime(2026, 1, 1), monto: monto);

Presupuesto _base() => Presupuesto(items: [
      ItemPresupuesto(id: 'a', descripcion: 'Resina', precio: 25, cantidad: 2),
      ItemPresupuesto(id: 'b', descripcion: 'Limpieza', precio: 30),
      ItemPresupuesto(
        id: 'c',
        descripcion: 'No se hará',
        precio: 999,
        estado: EstadoTratamiento.cancelado,
      ),
    ]);

void main() {
  group('Totales', () {
    test('ignoran cancelados y aplican el descuento', () {
      final p = _base()..descuentoPorcentaje = 10;
      expect(p.subtotal, 80.0);
      expect(p.descuento, 8.0);
      expect(p.total, 72.0);
    });

    test('no arrastran errores de coma flotante', () {
      final p = Presupuesto(items: [
        ItemPresupuesto(id: 'a', descripcion: 'A', precio: 0.1),
        ItemPresupuesto(id: 'b', descripcion: 'B', precio: 0.2),
      ]);
      expect(p.subtotal, 0.3);
    });
  });

  group('Pagos y saldo', () {
    test('estado de cobro según lo abonado', () {
      final p = _base(); // total 80
      expect(p.estadoCobro, EstadoCobro.pendiente);

      p.pagos.add(_pago(1, 30));
      expect(p.saldo, 50.0);
      expect(p.estadoCobro, EstadoCobro.parcial);

      p.pagos.add(_pago(2, 50));
      expect(p.saldo, 0.0);
      expect(p.estadoCobro, EstadoCobro.pagado);

      p.pagos.add(_pago(3, 5));
      expect(p.saldo, -5.0);
      expect(p.estadoCobro, EstadoCobro.saldoAFavor);
    });

    test('un pago anulado no cuenta y su número no se reutiliza', () {
      final p = _base();
      p.pagos.add(_pago(1, 30));
      p.pagos.add(_pago(2, 20));
      p.pagos[1].anulado = true;
      expect(p.totalPagado, 30.0);
      expect(p.saldo, 50.0);
      expect(p.siguienteNumeroRecibo, 3);
    });

    test('pagado hasta un recibo suma solo los anteriores vigentes', () {
      final p = _base();
      p.pagos.addAll([_pago(1, 10), _pago(2, 20), _pago(3, 40)]);
      expect(p.pagadoHastaRecibo(2), 30.0);
    });
  });

  group('Compatibilidad de datos', () {
    test('un presupuesto guardado con el formato anterior sigue abriendo', () {
      final viejo = <String, dynamic>{
        'fechaCreacion': '2026-01-05T10:00:00.000',
        'items': [
          {
            'id': 'x',
            'descripcion': 'Pieza 16 · Caries',
            'precio': 25,
            'estado': 'aceptado',
            'generadoAutomaticamente': true,
          },
        ],
        'descuentoPorcentaje': 0,
        'precios': <String, dynamic>{},
      };
      final p = Presupuesto.fromMap(viejo);
      expect(p.items.single.cantidad, 1);
      expect(p.items.single.estado, EstadoTratamiento.aceptado);
      expect(p.pagos, isEmpty);
      expect(p.total, 25.0);
    });

    test('ida y vuelta toMap/fromMap conserva pagos y anulaciones', () {
      final p = _base()..notas = 'Sujeto a valoración';
      p.pagos.add(_pago(1, 30));
      p.pagos[0]
        ..anulado = true
        ..motivoAnulacion = 'Error de digitación';
      final copia = Presupuesto.fromMap(p.toMap());
      expect(copia.pagos.single.anulado, isTrue);
      expect(copia.pagos.single.motivoAnulacion, 'Error de digitación');
      expect(copia.notas, 'Sujeto a valoración');
      expect(copia.total, p.total);
    });
  });
}
