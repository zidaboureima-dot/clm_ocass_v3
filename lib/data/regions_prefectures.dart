// Liste officielle des 8 régions et 46 préfectures/communes de Guinée
// utilisée pour la localisation des signalements.
class RegionsPrefectures {
  static const Map<String, List<String>> donnees = {
    'Boké': ['Boké', 'Boffa', 'Fria', 'Gaoual', 'Koundara'],
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
    'Kankan': ['Kankan', 'Kérouané', 'Kouroussa', 'Mandiana', 'Siguiri'],
    'Kindia': ['Kindia', 'Coyah', 'Dubréka', 'Forécariah', 'Télimélé'],
    'Labé': ['Labé', 'Koubia', 'Lélouma', 'Mali', 'Tougué'],
    'Mamou': ['Mamou', 'Dalaba', 'Pita'],
    'Nzérékoré': ['Nzérékoré', 'Beyla', 'Guéckédou', 'Lola', 'Macenta', 'Yomou'],
  };

  static List<String> get regions => donnees.keys.toList();

  static List<String> prefecturesDe(String region) => donnees[region] ?? [];
}
