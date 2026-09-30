import 'package:flutter_test/flutter_test.dart';
import 'package:odontometas/models/ficha_clinica.dart';
import 'package:odontometas/models/paciente.dart';

void main() {
  group('Edad y revisión de la historia', () {
    test('calcula la edad y detecta menores', () {
      final hoy = DateTime.now();
      final f = FichaClinica(
        fechaNacimiento: DateTime(hoy.year - 10, hoy.month, hoy.day),
      );
      expect(f.edad, 10);
      expect(f.esMenor, isTrue);
      f.fechaNacimiento = DateTime(hoy.year - 30, hoy.month, hoy.day);
      expect(f.esMenor, isFalse);
      f.fechaNacimiento = null;
      expect(f.edad, isNull);
      expect(f.esMenor, isFalse);
    });

    test('la historia sin confirmar o vieja pide revisión', () {
      final f = FichaClinica();
      expect(f.historiaPorRevisar, isTrue);
      f.historiaActualizada = DateTime.now().subtract(const Duration(days: 30));
      expect(f.historiaPorRevisar, isFalse);
      f.historiaActualizada = DateTime.now().subtract(const Duration(days: 200));
      expect(f.historiaPorRevisar, isTrue);
    });
  });

  group('Alertas y alergias', () {
    test('solo las condiciones marcadas como alerta se destacan', () {
      final f = FichaClinica(condiciones: {'diabetes', 'anemia', 'embarazo'});
      expect(f.condicionesDeAlerta, ['Diabetes', 'Embarazo']);
      expect(f.tieneAlertas, isTrue);
      expect(FichaClinica(condiciones: {'anemia'}).tieneAlertas, isFalse);
    });

    test('las alergias graves van primero', () {
      final f = FichaClinica(alergias: [
        Alergia(id: '1', descripcion: 'Polen', severidad: SeveridadAlergia.leve),
        Alergia(id: '2', descripcion: 'Penicilina', severidad: SeveridadAlergia.grave),
      ]);
      expect(f.alergiasOrdenadas.first.descripcion, 'Penicilina');
    });

    test('avisa si el medicamento es de la misma familia que una alergia', () {
      final f = FichaClinica(alergias: [
        Alergia(id: '1', descripcion: 'Penicilina'),
        Alergia(id: '2', descripcion: 'Aspirina'),
      ]);
      expect(f.alergiaConflictiva('Amoxicilina')?.descripcion, 'Penicilina');
      expect(f.alergiaConflictiva('amoxicilina + ácido clavulánico'), isNotNull);
      expect(f.alergiaConflictiva('Ibuprofeno')?.descripcion, 'Aspirina');
      expect(f.alergiaConflictiva('Paracetamol'), isNull);
      expect(f.alergiaConflictiva('Clindamicina'), isNull);
      expect(f.alergiaConflictiva(''), isNull);
    });

    test('sin alergias registradas nunca avisa', () {
      expect(FichaClinica().alergiaConflictiva('Amoxicilina'), isNull);
    });
  });

  group('Recetas y citas', () {
    test('el número de receta no se reutiliza al borrar una intermedia', () {
      final f = FichaClinica();
      expect(f.siguienteNumeroReceta, 1);
      f.recetas.add(Receta(id: 'a', numero: 1, fecha: DateTime(2026, 1, 1)));
      f.recetas.add(Receta(id: 'b', numero: 2, fecha: DateTime(2026, 1, 2)));
      f.recetas.removeAt(0);
      expect(f.siguienteNumeroReceta, 3);
      expect(f.recetas.single.numeroTexto, '0002');
    });

    test('las próximas citas ignoran fechas pasadas y salen ordenadas', () {
      final hoy = DateTime.now();
      final f = FichaClinica(evoluciones: [
        Evolucion(
          id: '1',
          fecha: hoy,
          proximaCita: hoy.subtract(const Duration(days: 3)),
        ),
        Evolucion(
          id: '2',
          fecha: hoy,
          proximaCita: hoy.add(const Duration(days: 20)),
        ),
        Evolucion(
          id: '3',
          fecha: hoy,
          proximaCita: hoy.add(const Duration(days: 5)),
        ),
      ]);
      final citas = f.proximasCitas;
      expect(citas.length, 2);
      expect(citas.first.isBefore(citas.last), isTrue);
    });

    test('las evoluciones se ordenan de la más reciente a la más antigua', () {
      final f = FichaClinica(evoluciones: [
        Evolucion(id: '1', fecha: DateTime(2026, 1, 1)),
        Evolucion(id: '2', fecha: DateTime(2026, 3, 1)),
        Evolucion(id: '3', fecha: DateTime(2026, 2, 1)),
      ]);
      expect(f.evolucionesOrdenadas.map((e) => e.id).toList(), ['2', '3', '1']);
    });
  });

  group('Firma', () {
    test('los trazos se guardan como texto y se recuperan igual', () {
      final c = Consentimiento(
        id: 'c',
        fecha: DateTime(2026, 1, 1),
        titulo: 'General',
        texto: 'texto',
        firmaTrazos: [
          Consentimiento.codificarTrazo([
            [10.04, 20.06],
            [11.5, 22.0],
          ]),
          Consentimiento.codificarTrazo([
            [50.0, 50.0],
          ]),
        ],
        firmaAncho: 300,
        firmaAlto: 150,
        firmadoEn: DateTime(2026, 1, 1),
      );
      expect(c.firmado, isTrue);
      final t = c.trazos;
      expect(t.length, 2);
      expect(t.first.length, 2);
      expect(t.first.first, [10.0, 20.1]);
      expect(t.last.single, [50.0, 50.0]);
    });

    test('sin trazos o sin fecha de firma no cuenta como firmado', () {
      final c = Consentimiento(
        id: 'c',
        fecha: DateTime(2026, 1, 1),
        titulo: 'General',
        texto: 'texto',
      );
      expect(c.firmado, isFalse);
      expect(c.trazos, isEmpty);
    });

    test('los trazos guardados no usan listas anidadas (Firestore no las admite)', () {
      final c = Consentimiento(
        id: 'c',
        fecha: DateTime(2026, 1, 1),
        titulo: 'General',
        texto: 'texto',
        firmaTrazos: [
          Consentimiento.codificarTrazo([
            [1.0, 2.0],
            [3.0, 4.0],
          ]),
        ],
      );
      final mapa = c.toMap();
      final lista = mapa['firmaTrazos'] as List;
      expect(lista.every((e) => e is String), isTrue);
    });
  });

  group('Compatibilidad y guardado', () {
    test('un paciente guardado sin ficha sigue abriendo', () {
      final p = Paciente.fromMap({'nombre': 'Ana', 'cedula': '1', 'celular': '2'});
      expect(p.ficha, isNull);
      expect(p.nombre, 'Ana');
    });

    test('la ficha completa hace ida y vuelta sin perder datos', () {
      final f = FichaClinica(
        fechaNacimiento: DateTime(1990, 5, 17),
        sexo: Sexo.femenino,
        motivoConsulta: 'Dolor',
        condiciones: {'diabetes', 'asma'},
        alergias: [
          Alergia(
            id: 'a',
            descripcion: 'Penicilina',
            reaccion: 'Urticaria',
            severidad: SeveridadAlergia.grave,
          ),
        ],
        medicamentos: [MedicamentoActual(id: 'm', nombre: 'Metformina')],
        tabaco: NivelHabito.ocasional,
        cepilladosDia: 3,
        ansiedadDental: 4,
        evoluciones: [
          Evolucion(
            id: 'e',
            fecha: DateTime(2026, 9, 1),
            procedimiento: 'Resina',
            itemsRealizados: ['x'],
            descripcionItems: ['Pieza 16 · Caries'],
            proximaCita: DateTime(2026, 9, 20),
          ),
        ],
        recetas: [
          Receta(
            id: 'r',
            numero: 7,
            fecha: DateTime(2026, 9, 1),
            items: [RecetaItem(nombre: 'Ibuprofeno', posologia: 'x')],
          ),
        ],
        consentimientos: [
          Consentimiento(
            id: 'c',
            fecha: DateTime(2026, 9, 1),
            titulo: 'General',
            texto: 't',
            esRepresentante: true,
            parentesco: 'Madre',
          ),
        ],
      );
      final p = Paciente(nombre: 'Ana', ficha: f);
      final copia = Paciente.fromMap(p.toMap()).ficha!;
      expect(copia.sexo, Sexo.femenino);
      expect(copia.condiciones, {'diabetes', 'asma'});
      expect(copia.alergias.single.severidad, SeveridadAlergia.grave);
      expect(copia.medicamentos.single.nombre, 'Metformina');
      expect(copia.tabaco, NivelHabito.ocasional);
      expect(copia.ansiedadDental, 4);
      expect(copia.evoluciones.single.itemsRealizados, ['x']);
      expect(copia.evoluciones.single.proximaCita, DateTime(2026, 9, 20));
      expect(copia.recetas.single.numero, 7);
      expect(copia.consentimientos.single.parentesco, 'Madre');
      expect(copia.edad, f.edad);
    });

    test('los datos raros o incompletos no rompen la carga', () {
      final f = FichaClinica.fromMap({
        'sexo': 'valor_que_ya_no_existe',
        'tabaco': 'otro',
        'alergias': [
          {'descripcion': 'X', 'tipo': 'desconocido'},
        ],
        'recetas': [
          {'numero': 1},
        ],
      });
      expect(f.sexo, isNull);
      expect(f.tabaco, NivelHabito.ninguno);
      expect(f.alergias.single.tipo, TipoAlergia.otro);
      expect(f.recetas.single.items, isEmpty);
    });
  });

  group('Plantillas de consentimiento', () {
    test('todas usan marcas que se resuelven al guardar', () {
      for (final t in plantillasConsentimiento) {
        if (t.texto.isEmpty) {
          continue;
        }
        expect(t.texto.contains('{firmante}'), isTrue, reason: t.titulo);
      }
    });
  });
}
