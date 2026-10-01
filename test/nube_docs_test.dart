import 'package:flutter_test/flutter_test.dart';
import 'package:odontometas/models/meta_goal.dart';
import 'package:odontometas/models/paciente.dart';
import 'package:odontometas/services/nube_docs.dart';

MetaGoal _meta(String id, String titulo, List<Paciente?> pacientes) =>
    MetaGoal(id: id, titulo: titulo, metaNumero: pacientes.length, pacientes: pacientes);

Map<String, String> _json(Map<String, Map<String, dynamic>> docs) =>
    {for (final e in docs.entries) e.key: DocsNube.serializar(e.value)};

void main() {
  group('Un documento por paciente', () {
    test('ida y vuelta conserva metas, orden, casillas vacías y pacientes', () {
      final ana = Paciente(id: 'a', nombre: 'Ana', cedula: '1');
      final beto = Paciente(id: 'b', nombre: 'Beto');
      final carla = Paciente(id: 'c', nombre: 'Carla');
      final metas = [
        _meta('m1', 'Septiembre', [ana, null, beto]),
        _meta('m2', 'Octubre', [null, carla]),
      ];
      final docs = DocsNube.construir(metas);
      expect(docs.pacientes.keys.toSet(), {'a', 'b', 'c'});
      expect(docs.metas['m1']!['slots'], ['a', null, 'b']);
      expect(docs.pacientes['a']!['metaId'], 'm1');

      // Se ensambla con las metas desordenadas para probar el orden.
      final vuelta = DocsNube.ensamblar(
        [docs.metas['m2']!, docs.metas['m1']!],
        docs.pacientes,
      );
      expect(vuelta.map((m) => m.id).toList(), ['m1', 'm2']);
      expect(vuelta[0].pacientes.map((p) => p?.id).toList(), ['a', null, 'b']);
      expect(vuelta[1].pacientes.map((p) => p?.nombre).toList(), [null, 'Carla']);
      expect(vuelta[0].titulo, 'Septiembre');
      expect(vuelta[0].metaNumero, 3);
    });

    test('una casilla que apunta a un paciente ausente queda vacía sin fallar', () {
      final docs = DocsNube.construir([
        _meta('m1', 'X', [Paciente(id: 'a', nombre: 'Ana'), Paciente(id: 'b', nombre: 'Beto')]),
      ]);
      docs.pacientes.remove('b'); // subida interrumpida
      final vuelta = DocsNube.ensamblar([docs.metas['m1']!], docs.pacientes);
      expect(vuelta.single.pacientes[0]?.nombre, 'Ana');
      expect(vuelta.single.pacientes[1], isNull);
    });

    test('ids repetidos se avisan', () {
      final docs = DocsNube.construir([
        _meta('m1', 'X', [Paciente(id: 'a', nombre: 'Ana')]),
        _meta('m2', 'Y', [Paciente(id: 'a', nombre: 'Otra')]),
      ]);
      expect(docs.advertencias, isNotEmpty);
    });
  });

  group('Ids estables', () {
    test('los pacientes nuevos reciben ids distintos', () {
      expect(Paciente().id, isNot(Paciente().id));
      expect(Paciente().id, isNotEmpty);
    });

    test('un paciente guardado con id lo conserva', () {
      final p = Paciente(id: 'fijo', nombre: 'Ana');
      expect(Paciente.fromMap(p.toMap()).id, 'fijo');
    });

    test('los datos antiguos sin id reciben el mismo id en cada carga', () {
      final viejo = {
        'id': 'meta7',
        'titulo': 'Antigua',
        'metaNumero': 3,
        'pacientes': [
          {'nombre': 'Ana'},
          null,
          {'nombre': 'Beto'},
        ],
      };
      final a = MetaGoal.fromMap(viejo);
      final b = MetaGoal.fromMap(viejo);
      expect(a.pacientes[0]!.id, 'meta7_p0');
      expect(a.pacientes[2]!.id, 'meta7_p2');
      expect(b.pacientes[0]!.id, a.pacientes[0]!.id);
      expect(a.pacientes[1], isNull);
    });
  });

  group('Plan de subida (solo lo que cambia)', () {
    test('sin cambios no hay nada que subir', () {
      final metas = [
        _meta('m1', 'X', [Paciente(id: 'a', nombre: 'Ana')]),
      ];
      final docs = DocsNube.construir(metas);
      final plan = PlanificadorNube.planificar(
        previosPacientes: _json(docs.pacientes),
        previosMetas: _json(docs.metas),
        deseado: DocsNube.construir(metas),
      );
      expect(plan.vacio, isTrue);
    });

    test('cambiar un paciente sube solo ese documento', () {
      final ana = Paciente(id: 'a', nombre: 'Ana');
      final beto = Paciente(id: 'b', nombre: 'Beto');
      final metas = [_meta('m1', 'X', [ana, beto])];
      final antes = DocsNube.construir(metas);
      beto.celular = '0999';
      final plan = PlanificadorNube.planificar(
        previosPacientes: _json(antes.pacientes),
        previosMetas: _json(antes.metas),
        deseado: DocsNube.construir(metas),
      );
      expect(plan.pacientesEscribir.keys, ['b']);
      expect(plan.metasEscribir, isEmpty);
      expect(plan.pacientesBorrar, isEmpty);
    });

    test('un paciente quitado se borra de la nube y la meta se actualiza', () {
      final ana = Paciente(id: 'a', nombre: 'Ana');
      final beto = Paciente(id: 'b', nombre: 'Beto');
      final metas = [_meta('m1', 'X', [ana, beto])];
      final antes = DocsNube.construir(metas);
      metas.first.pacientes[1] = null;
      final plan = PlanificadorNube.planificar(
        previosPacientes: _json(antes.pacientes),
        previosMetas: _json(antes.metas),
        deseado: DocsNube.construir(metas),
      );
      expect(plan.pacientesBorrar, ['b']);
      expect(plan.metasEscribir.keys, ['m1']);
    });

    test('primera subida: escribe todo', () {
      final metas = [
        _meta('m1', 'X', [Paciente(id: 'a', nombre: 'Ana'), Paciente(id: 'b', nombre: 'B')]),
      ];
      final plan = PlanificadorNube.planificar(
        previosPacientes: {},
        previosMetas: {},
        deseado: DocsNube.construir(metas),
      );
      expect(plan.pacientesEscribir.length, 2);
      expect(plan.metasEscribir.length, 1);
      expect(plan.totalOperaciones, 3);
    });

    test('si lo local queda vacío NO se borra toda la nube', () {
      final antes = DocsNube.construir([
        _meta('m1', 'X', [Paciente(id: 'a', nombre: 'Ana'), Paciente(id: 'b', nombre: 'B')]),
      ]);
      final plan = PlanificadorNube.planificar(
        previosPacientes: _json(antes.pacientes),
        previosMetas: _json(antes.metas),
        deseado: DocsNube.construir(<MetaGoal>[]),
      );
      expect(plan.pacientesBorrar, isEmpty);
      expect(plan.metasBorrar, isEmpty);
      expect(plan.advertencias, isNotEmpty);
    });

    test('un paciente demasiado grande no se sube y se avisa', () {
      final grande = Paciente(id: 'g', nombre: 'a' * 1000000);
      final normal = Paciente(id: 'n', nombre: 'Normal');
      final plan = PlanificadorNube.planificar(
        previosPacientes: {},
        previosMetas: {},
        deseado: DocsNube.construir([
          _meta('m1', 'X', [grande, normal]),
        ]),
      );
      expect(plan.pacientesEscribir.keys, ['n']);
      expect(plan.advertencias.any((a) => a.contains('demasiado espacio')), isTrue);
    });

    test('el respaldo no se borra si el paciente ahora es demasiado grande', () {
      final previo = Paciente(id: 'g', nombre: 'Pequeño');
      final metas = [_meta('m1', 'X', [previo])];
      final antes = DocsNube.construir(metas);
      previo.nombre = 'a' * 1000000;
      final plan = PlanificadorNube.planificar(
        previosPacientes: _json(antes.pacientes),
        previosMetas: _json(antes.metas),
        deseado: DocsNube.construir(metas),
      );
      expect(plan.pacientesEscribir, isEmpty);
      expect(plan.pacientesBorrar, isEmpty);
    });
  });
}
