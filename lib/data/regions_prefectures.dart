/// Découpage administratif de la Guinée.
///
///   9 régions administratives + Conakry (gouvernorat, « zone spéciale »)
///   44 préfectures, hors les 13 communes de Conakry
///
/// Conakry figure ici parmi les zones sélectionnables parce que
/// l'application doit permettre d'y signaler, mais elle n'est pas une région
/// administrative au sens du découpage national : c'est un gouvernorat. Ses
/// 13 communes ne sont donc pas comptées dans les 44 préfectures.
///
/// MISE À JOUR DU 21 AOÛT 2026
///   Décret présidentiel du 20 août 2026 portant redécoupage territorial :
///   Beyla et Siguiri, jusque-là préfectures, sont érigées en RÉGIONS
///   administratives, et 11 préfectures nouvelles sont créées.
///
///     Kamsar                              -> Boké
///     Timbo                               -> Mamou
///     Tokounou, Dialakoro,                -> Kankan
///       Sabadou-Baranama
///     Doko, Siguirini, Kintinian          -> Siguiri (région nouvelle)
///     Sinko, Kouankan, Karala             -> Beyla (région nouvelle)
///
///   Siguiri quitte donc la région de Kankan, et Beyla celle de Nzérékoré :
///   toutes deux figurent désormais comme préfectures chefs-lieux de leur
///   propre région.
///
/// POINTS CONFIRMÉS PAR LE PORTEUR DU PROJET LE 21 AOÛT 2026
///   - Siguiri et Beyla demeurent des préfectures, chefs-lieux de leur
///     propre région, et sont retirées de Kankan et de Nzérékoré.
///   - Aucune autre préfecture existante n'est transférée vers ces deux
///     régions.
///   Le total de 44 préfectures vérifie ces deux points : toute autre
///   répartition donnerait un compte différent. La liste complète fournie
///   se contredisait sur ce point — son tableau laissait Siguiri sous
///   Kankan et Beyla sous Nzérékoré, sa note de bas de page disait
///   l'inverse. C'est la note qui fait foi.
///
/// POURQUOI CETTE LISTE NE DEVRAIT PAS ÊTRE DANS LE CODE
///   Cet événement illustre exactement la limite du modèle mono-pays : une
///   décision administrative impose une recompilation et une republication
///   de l'application. Dans l'architecture multi-pays visée, la hiérarchie
///   sanitaire relève de la configuration par pays — idéalement ingérée
///   depuis le système national d'information sanitaire — et se met à jour
///   sans toucher au code. Voir CADRAGE_SAAS_CONSOLIDE.md.
///
/// ATTENTION — LA RÉGION EST UN PÉRIMÈTRE DE SÉCURITÉ
///   `region` ne sert pas qu'à l'affichage : les policies RLS s'en servent
///   pour déterminer ce qu'un superviseur a le droit de lire (signalements,
///   annotations, actions menées). Créer une région ici ne suffit donc pas :
///   il faut aussi affecter un superviseur à cette région, faute de quoi ses
///   signalements ne seront visibles que de l'administrateur.
class RegionsPrefectures {
  static const Map<String, List<String>> donnees = {
    // Région créée par le décret du 20 août 2026 (ex-préfecture de Nzérékoré).
    'Beyla': ['Beyla', 'Karala', 'Kouankan', 'Sinko'],
    'Boké': ['Boké', 'Boffa', 'Fria', 'Gaoual', 'Kamsar', 'Koundara'],
    'Conakry': [
      'Dixinn',
      'Gbessia',
      'Kagbelen',
      'Kaloum',
      'Kassa',
      'Lambanyi',
      'Manéah',
      'Matam',
      'Matoto',
      'Ratoma',
      'Sanoyah',
      'Sonfonia',
      'Tombolia',
    ],
    'Faranah': ['Faranah', 'Dabola', 'Dinguiraye', 'Kissidougou'],
    'Kankan': [
      'Kankan',
      'Dialakoro',
      'Kérouané',
      'Kouroussa',
      'Mandiana',
      'Sabadou-Baranama',
      'Tokounou',
    ],
    'Kindia': ['Kindia', 'Coyah', 'Dubréka', 'Forécariah', 'Télimélé'],
    'Labé': ['Labé', 'Koubia', 'Lélouma', 'Mali', 'Tougué'],
    'Mamou': ['Mamou', 'Dalaba', 'Pita', 'Timbo'],
    'Nzérékoré': ['Nzérékoré', 'Guéckédou', 'Lola', 'Macenta', 'Yomou'],
    // Région créée par le décret du 20 août 2026 (ex-préfecture de Kankan).
    'Siguiri': ['Siguiri', 'Doko', 'Kintinian', 'Siguirini'],
  };

  static List<String> get regions => donnees.keys.toList();

  static List<String> prefecturesDe(String region) => donnees[region] ?? [];

  /// Conakry est un gouvernorat, pas une région administrative : ses communes
  /// ne sont pas des préfectures et ne sont donc pas comptées comme telles.
  static const zoneSpeciale = 'Conakry';

  /// Nombre officiel de préfectures — doit valoir 44 depuis le décret du
  /// 20 août 2026. Sert de contrôle de cohérence : si une modification de
  /// cette liste fait varier ce nombre sans qu'un texte l'ait décidé, c'est
  /// une erreur de saisie.
  static int get nombrePrefectures => donnees.entries
      .where((e) => e.key != zoneSpeciale)
      .fold(0, (n, e) => n + e.value.length);

  /// Nombre de régions administratives, Conakry exclue.
  static int get nombreRegionsAdministratives => donnees.length - 1;
}
