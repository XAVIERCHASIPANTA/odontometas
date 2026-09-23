import 'paciente.dart';

class MetaGoal {
  String id;
  String titulo;
  int metaNumero;
  List<Paciente?> pacientes;

  MetaGoal({
    required this.id,
    required this.titulo,
    required this.metaNumero,
    List<Paciente?>? pacientes,
  }) : pacientes = pacientes ?? List<Paciente?>.generate(metaNumero, (_) => null);

  int get completados => pacientes.where((p) => p != null && p.tieneInfo).length;

  double get progreso => metaNumero == 0 ? 0 : completados / metaNumero;

  void ajustarTamano(int nuevoTamano) {
    if (nuevoTamano < 1) {
      nuevoTamano = 1;
    }
    if (nuevoTamano > pacientes.length) {
      final extra = nuevoTamano - pacientes.length;
      pacientes.addAll(List<Paciente?>.generate(extra, (_) => null));
    } else if (nuevoTamano < pacientes.length) {
      pacientes = pacientes.sublist(0, nuevoTamano);
    }
    metaNumero = nuevoTamano;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'metaNumero': metaNumero,
      'pacientes': pacientes.map((p) => p?.toMap()).toList(),
    };
  }

  factory MetaGoal.fromMap(Map<String, dynamic> map) {
    final rawList = (map['pacientes'] as List?) ?? [];
    final lista = rawList.map<Paciente?>((e) {
      if (e == null) {
        return null;
      }
      return Paciente.fromMap(Map<String, dynamic>.from(e as Map));
    }).toList();
    int meta = map['metaNumero'] ?? lista.length;
    if (lista.length < meta) {
      lista.addAll(List<Paciente?>.generate(meta - lista.length, (_) => null));
    }
    return MetaGoal(
      id: map['id'],
      titulo: map['titulo'] ?? '',
      metaNumero: meta,
      pacientes: lista,
    );
  }
}
