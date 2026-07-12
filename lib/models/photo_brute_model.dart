class PhotoBrute {
  final String id;
  final String cheminStockage;
  final String statut;
  final String? signalementId;
  final DateTime createdAt;

  PhotoBrute({
    required this.id,
    required this.cheminStockage,
    required this.statut,
    this.signalementId,
    required this.createdAt,
  });

  factory PhotoBrute.fromJson(Map<String, dynamic> json) {
    return PhotoBrute(
      id: json['id'],
      cheminStockage: json['chemin_stockage'],
      statut: json['statut'] ?? 'nouveau',
      signalementId: json['signalement_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
