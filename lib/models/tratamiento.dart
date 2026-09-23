class Tratamiento {
  String tipo;
  DateTime? fecha;
  bool completado;

  Tratamiento({
    this.tipo = '',
    this.fecha,
    this.completado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'fecha': fecha?.toIso8601String(),
      'completado': completado,
    };
  }

  factory Tratamiento.fromMap(Map<String, dynamic> map) {
    return Tratamiento(
      tipo: map['tipo'] ?? '',
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha']) : null,
      completado: map['completado'] ?? false,
    );
  }
}
