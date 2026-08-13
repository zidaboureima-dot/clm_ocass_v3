class DemandeReset {
  final String id;
  final String email;
  final String nom;
  final String role;
  final String? region;
  final String? prefecture;
  final DateTime demandeLe;

  DemandeReset({
    required this.id,
    required this.email,
    required this.nom,
    required this.role,
    required this.region,
    required this.prefecture,
    required this.demandeLe,
  });

  factory DemandeReset.fromMap(Map<String, dynamic> map) {
    return DemandeReset(
      id: map['id'] as String,
      email: map['email'] as String,
      nom: (map['nom'] as String?) ?? '',
      role: (map['role'] as String?) ?? '',
      region: map['region'] as String?,
      prefecture: map['prefecture'] as String?,
      demandeLe: DateTime.parse(map['demande_le'] as String),
    );
  }

  // Libellé de zone lisible pour l'affichage (région ou préfecture).
  String get zone {
    if (role == 'point_focal' && prefecture != null) return prefecture!;
    if (region != null) return region!;
    return 'zone non définie';
  }

  String get libelleRole => role == 'superviseur' ? 'Superviseur' : 'Point focal';
}