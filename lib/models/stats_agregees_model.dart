/// Statistiques publiques agrégées, construites depuis la vue `stats_publiques`.
/// Ne contient que des comptes, aucune donnée de signalement individuel.
class StatsAgregees {
  final Map<String, int> parStatut;
  final Map<String, int> parNature;
  final Map<String, int> parCategorie;
  final Map<String, int> parRegion;

  const StatsAgregees({
    required this.parStatut,
    required this.parNature,
    required this.parCategorie,
    required this.parRegion,
  });

  /// Total général, recalculé depuis la dimension statut (somme fiable).
  int get total => parStatut.values.fold(0, (somme, n) => somme + n);

  /// Construit l'objet depuis les lignes brutes de la vue,
  /// chaque ligne ayant la forme { dimension, valeur, nombre }.
  factory StatsAgregees.depuisLignesVue(List<Map<String, dynamic>> lignes) {
    final parStatut = <String, int>{};
    final parNature = <String, int>{};
    final parCategorie = <String, int>{};
    final parRegion = <String, int>{};

    for (final ligne in lignes) {
      final dimension = ligne['dimension'] as String?;
      final valeur = ligne['valeur'] as String?;
      final nombre = (ligne['nombre'] as num?)?.toInt() ?? 0;
      if (valeur == null || valeur.isEmpty) continue;

      switch (dimension) {
        case 'statut':
          parStatut[valeur] = nombre;
          break;
        case 'nature':
          parNature[valeur] = nombre;
          break;
        case 'categorie':
          parCategorie[valeur] = nombre;
          break;
        case 'region':
          parRegion[valeur] = nombre;
          break;
      }
    }

    return StatsAgregees(
      parStatut: parStatut,
      parNature: parNature,
      parCategorie: parCategorie,
      parRegion: parRegion,
    );
  }
}