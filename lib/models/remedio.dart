class Remedio {
  final String id;
  final String nome;
  final String? dosagem;
  final List<String> horarios; // formato "HH:mm"
  final bool diario; // true = todo dia, false = só quando precisa (SOS)
  bool ativo;

  Remedio({
    required this.id,
    required this.nome,
    this.dosagem,
    required this.horarios,
    required this.diario,
    this.ativo = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'dosagem': dosagem,
        'horarios': horarios,
        'diario': diario,
        'ativo': ativo,
      };

  factory Remedio.fromJson(Map<String, dynamic> json) => Remedio(
        id: json['id'] as String,
        nome: json['nome'] as String,
        dosagem: json['dosagem'] as String?,
        horarios: List<String>.from(json['horarios'] as List),
        diario: json['diario'] as bool,
        ativo: (json['ativo'] as bool?) ?? true,
      );

  Remedio copyWith({
    String? id,
    String? nome,
    String? dosagem,
    List<String>? horarios,
    bool? diario,
    bool? ativo,
  }) {
    return Remedio(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dosagem: dosagem ?? this.dosagem,
      horarios: horarios ?? this.horarios,
      diario: diario ?? this.diario,
      ativo: ativo ?? this.ativo,
    );
  }
}
