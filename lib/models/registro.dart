class Registro {
  final String remedioId;
  final DateTime dataHora; // quando foi tomado
  final String? horarioPrevisto; // "HH:mm" do horário agendado (para diários)

  Registro({
    required this.remedioId,
    required this.dataHora,
    this.horarioPrevisto,
  });

  Map<String, dynamic> toJson() => {
        'remedioId': remedioId,
        'dataHora': dataHora.toIso8601String(),
        'horarioPrevisto': horarioPrevisto,
      };

  factory Registro.fromJson(Map<String, dynamic> json) => Registro(
        remedioId: json['remedioId'] as String,
        dataHora: DateTime.parse(json['dataHora'] as String),
        horarioPrevisto: json['horarioPrevisto'] as String?,
      );

  /// Retorna só a data (sem hora) para comparações
  DateTime get data => DateTime(dataHora.year, dataHora.month, dataHora.day);
}
