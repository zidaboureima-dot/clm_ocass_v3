class Categorie {
  final String id;
  final String groupe;
  final String libelle;
  final int ordre;
  final bool actif;

  Categorie({
    required this.id,
    required this.groupe,
    required this.libelle,
    required this.ordre,
    required this.actif,
  });

  factory Categorie.fromJson(Map<String, dynamic> json) {
    return Categorie(
      id: json['id'],
      groupe: json['groupe'],
      libelle: json['libelle'],
      ordre: json['ordre'] ?? 0,
      actif: json['actif'] ?? true,
    );
  }
}
