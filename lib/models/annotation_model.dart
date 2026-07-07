class Annotation {
  final String? id;
  final String signalementId;
  final String auteurUid;
  final String roleAuteur; // 'point_focal', 'superviseur', 'admin'
  final String contenu;
  final DateTime createdAt;

  Annotation({
    this.id,
    required this.signalementId,
    required this.auteurUid,
    required this.roleAuteur,
    required this.contenu,
    required this.createdAt,
  });

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'],
      signalementId: json['signalement_id'],
      auteurUid: json['auteur_uid'],
      roleAuteur: json['role_auteur'],
      contenu: json['contenu'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'signalement_id': signalementId,
    'auteur_uid': auteurUid,
    'role_auteur': roleAuteur,
    'contenu': contenu,
    'created_at': createdAt.toIso8601String(),
  };
}
