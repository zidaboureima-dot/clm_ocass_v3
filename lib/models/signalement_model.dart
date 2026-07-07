class Signalement {
  final String? id;
  final bool anonyme;
  final String prefecture;
  final String centreSante;
  final String region;
  final String nature; // 'normal', 'urgent', 'critique'
  final String description;
  final DateTime? dateIncident;
  final DateTime soumisLe;
  final String statut; // 'nouveau', 'en_cours', 'traite', 'cloture'
  final String? assigneeUid;
  final String? superviseurUid;
  final String? adminUid;

  Signalement({
    this.id,
    required this.anonyme,
    required this.prefecture,
    required this.centreSante,
    required this.region,
    required this.nature,
    required this.description,
    this.dateIncident,
    required this.soumisLe,
    required this.statut,
    this.assigneeUid,
    this.superviseurUid,
    this.adminUid,
  });

  factory Signalement.fromJson(Map<String, dynamic> json) {
    return Signalement(
      id: json['id'],
      anonyme: json['anonyme'] ?? true,
      prefecture: json['prefecture'],
      centreSante: json['centre_sante'],
      region: json['region'],
      nature: json['nature'],
      description: json['description'],
      dateIncident: json['date_incident'] != null ? DateTime.parse(json['date_incident']) : null,
      soumisLe: DateTime.parse(json['soumis_le']),
      statut: json['statut'] ?? 'nouveau',
      assigneeUid: json['assignee_uid'],
      superviseurUid: json['superviseur_uid'],
      adminUid: json['admin_uid'],
    );
  }

  Map<String, dynamic> toJson() => {
    'anonyme': anonyme,
    'prefecture': prefecture,
    'centre_sante': centreSante,
    'region': region,
    'nature': nature,
    'description': description,
    'date_incident': dateIncident?.toIso8601String(),
    'soumis_le': soumisLe.toIso8601String(),
    'statut': statut,
    'assignee_uid': assigneeUid,
    'superviseur_uid': superviseurUid,
    'admin_uid': adminUid,
  };
}
