class PhotoSignalement {
  final String id;
  final String signalementId;
  final String cheminStockage;
  final DateTime createdAt;

  PhotoSignalement({
    required this.id,
    required this.signalementId,
    required this.cheminStockage,
    required this.createdAt,
  });

  factory PhotoSignalement.fromJson(Map<String, dynamic> json) {
    return PhotoSignalement(
      id: json['id'],
      signalementId: json['signalement_id'],
      cheminStockage: json['chemin_stockage'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
