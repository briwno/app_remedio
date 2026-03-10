class NotificationSettings {
  final bool lembreteAntes;
  final int minutosAntes;
  final bool lembreteNaHora;
  final bool lembreteDepois;
  final int minutosDepois;

  const NotificationSettings({
    this.lembreteAntes = true,
    this.minutosAntes = 10,
    this.lembreteNaHora = true,
    this.lembreteDepois = true,
    this.minutosDepois = 30,
  });

  Map<String, dynamic> toJson() => {
        'lembreteAntes': lembreteAntes,
        'minutosAntes': minutosAntes,
        'lembreteNaHora': lembreteNaHora,
        'lembreteDepois': lembreteDepois,
        'minutosDepois': minutosDepois,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        lembreteAntes: json['lembreteAntes'] as bool? ?? true,
        minutosAntes: json['minutosAntes'] as int? ?? 10,
        lembreteNaHora: json['lembreteNaHora'] as bool? ?? true,
        lembreteDepois: json['lembreteDepois'] as bool? ?? true,
        minutosDepois: json['minutosDepois'] as int? ?? 30,
      );

  NotificationSettings copyWith({
    bool? lembreteAntes,
    int? minutosAntes,
    bool? lembreteNaHora,
    bool? lembreteDepois,
    int? minutosDepois,
  }) {
    return NotificationSettings(
      lembreteAntes: lembreteAntes ?? this.lembreteAntes,
      minutosAntes: minutosAntes ?? this.minutosAntes,
      lembreteNaHora: lembreteNaHora ?? this.lembreteNaHora,
      lembreteDepois: lembreteDepois ?? this.lembreteDepois,
      minutosDepois: minutosDepois ?? this.minutosDepois,
    );
  }
}
