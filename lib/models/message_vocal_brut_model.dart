class MessageVocalBrut {
  final String id;
  final String cheminStockage;
  final int? dureeSecondes;
  final String statut;
  final String? signalementId;
  final DateTime createdAt;

  MessageVocalBrut({
    required this.id,
    required this.cheminStockage,
    this.dureeSecondes,
    required this.statut,
    this.signalementId,
    required this.createdAt,
  });

  factory MessageVocalBrut.fromJson(Map<String, dynamic> json) {
    return MessageVocalBrut(
      id: json['id'],
      cheminStockage: json['chemin_stockage'],
      dureeSecondes: json['duree_secondes'],
      statut: json['statut'] ?? 'nouveau',
      signalementId: json['signalement_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
