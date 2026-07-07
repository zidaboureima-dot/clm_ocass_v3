class UserProfile {
  final String id;
  final String email;
  final String role;
  final String? region;
  final String? prefecture;
  final String nom;
  final bool actif;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.region,
    this.prefecture,
    required this.nom,
    required this.actif,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      region: json['region'],
      prefecture: json['prefecture'],
      nom: json['nom'],
      actif: json['actif'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'role': role,
    'region': region,
    'prefecture': prefecture,
    'nom': nom,
    'actif': actif,
  };
}
