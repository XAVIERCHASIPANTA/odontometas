class CampoAdicional {
  String etiqueta;
  String valor;

  CampoAdicional({this.etiqueta = '', this.valor = ''});

  Map<String, dynamic> toMap() {
    return {'etiqueta': etiqueta, 'valor': valor};
  }

  factory CampoAdicional.fromMap(Map<String, dynamic> map) {
    return CampoAdicional(
      etiqueta: map['etiqueta'] ?? '',
      valor: map['valor'] ?? '',
    );
  }
}
