/// Action menée sur un signalement.
///
/// À NE PAS CONFONDRE AVEC [Annotation]. Les deux portent du texte écrit par
/// un acteur sur un cas, mais leur destination diffère radicalement :
///
///   - Annotation   : espace de travail interne, jamais transmis à un tiers.
///   - ActionMenee  : écrit en sachant que cela pourra figurer dans un
///                    rapport transmis aux autorités sanitaires.
///
/// Cette distinction est le garde-fou central du rapport périodique
/// (voir CADRAGE_RAPPORT_LLM.md et 20260819_actions_menees.sql).
///
/// Saisie ancrée sur deux moments du workflow :
///   - le superviseur documente l'action avant de marquer « traité » ;
///   - l'admin rédige une synthèse ([typeSynthese]) avant de clôturer.
class ActionMenee {
  /// Types d'action décrivant une démarche entreprise.
  static const typeSaisine = 'saisine';
  static const typePlaidoyer = 'plaidoyer';
  static const typeCorrection = 'correction';
  static const typeRelance = 'relance';
  static const typeAutre = 'autre';

  /// Type à part : conclut le cas, rédigé par l'admin à la clôture.
  static const typeSynthese = 'synthese';

  /// Types proposés au superviseur au moment de marquer « traité ».
  /// La synthèse en est exclue : elle relève de la clôture par l'admin.
  static const typesDemarche = [
    typeSaisine,
    typePlaidoyer,
    typeCorrection,
    typeRelance,
    typeAutre,
  ];

  static const libellesTypes = {
    typeSaisine: 'Saisine du responsable de la structure',
    typePlaidoyer: 'Plaidoyer auprès d\'une autorité',
    typeCorrection: 'Correction obtenue ou constatée',
    typeRelance: 'Relance après absence de réponse',
    typeAutre: 'Autre (à préciser)',
    typeSynthese: 'Note de synthèse',
  };

  static const resultatObtenu = 'obtenu';
  static const resultatEnAttente = 'en_attente';
  static const resultatSansSuite = 'sans_suite';

  static const resultats = [resultatObtenu, resultatEnAttente, resultatSansSuite];

  static const libellesResultats = {
    resultatObtenu: 'Résultat obtenu',
    resultatEnAttente: 'En attente de réponse',
    resultatSansSuite: 'Restée sans suite',
  };

  final String? id;
  final String signalementId;
  final String auteurUid;
  final String roleAuteur;
  final String typeAction;
  final String description;
  final String resultat;
  final DateTime createdAt;

  ActionMenee({
    this.id,
    required this.signalementId,
    required this.auteurUid,
    required this.roleAuteur,
    required this.typeAction,
    required this.description,
    required this.resultat,
    required this.createdAt,
  });

  bool get estSynthese => typeAction == typeSynthese;

  String get libelleType => libellesTypes[typeAction] ?? typeAction;

  String get libelleResultat => libellesResultats[resultat] ?? resultat;

  factory ActionMenee.fromJson(Map<String, dynamic> json) {
    return ActionMenee(
      id: json['id'],
      signalementId: json['signalement_id'],
      auteurUid: json['auteur_uid'],
      roleAuteur: json['role_auteur'],
      typeAction: json['type_action'],
      description: json['description'],
      resultat: json['resultat'] ?? resultatEnAttente,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'signalement_id': signalementId,
    'auteur_uid': auteurUid,
    'role_auteur': roleAuteur,
    'type_action': typeAction,
    'description': description,
    'resultat': resultat,
    'created_at': createdAt.toIso8601String(),
  };
}
