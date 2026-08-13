class UserProfile {
  final String id;
  final String email;
  final String role;
  final String? region;
  final String? prefecture;
  final String nom;
  final bool actif;
  final bool doitChangerMdp;
  final String? telephone;
  final String? whatsapp;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.region,
    this.prefecture,
    required this.nom,
    required this.actif,
    this.doitChangerMdp = false,
    this.telephone,
    this.whatsapp,
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
      doitChangerMdp: json['doit_changer_mdp'] ?? false,
      telephone: json['telephone'],
      whatsapp: json['whatsapp'],
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'role': role,
    'region': region,
    'prefecture': prefecture,
    'nom': nom,
    'actif': actif,
    'telephone': telephone,
    'whatsapp': whatsapp,
  };
}
