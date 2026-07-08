class AudioSignalement {
  final String id;
  final String signalementId;
  final String cheminStockage;
  final int? dureeSecondes;
  final DateTime createdAt;

  AudioSignalement({
    required this.id,
    required this.signalementId,
    required this.cheminStockage,
    this.dureeSecondes,
    required this.createdAt,
  });

  factory AudioSignalement.fromJson(Map<String, dynamic> json) {
    return AudioSignalement(
      id: json['id'],
      signalementId: json['signalement_id'],
      cheminStockage: json['chemin_stockage'],
      dureeSecondes: json['duree_secondes'],
      createdAt: DateTime.parse(json['created_at'] ?? json['recu_le'] ?? DateTime.now().toIso8601String()),
    );
  }
}
