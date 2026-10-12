/// Modèles du référentiel géographique et sanitaire.
///
/// Voir supabase/migrations/20261012_referentiel_geo_sanitaire.sql pour le
/// raisonnement complet. Trois points à retenir de ce côté-ci :
///
///   - `region` et `prefecture` restent, sur un signalement, des colonnes
///     TEXTE. Le référentiel s'ajoute à côté du cloisonnement RLS, il ne le
///     traverse pas. Ne pas confondre `RegionRef.nom` avec
///     `Signalement.region` : le premier est une entrée de référentiel, le
///     second un périmètre de sécurité.
///
///   - Conakry est un gouvernorat, pas une région administrative. C'est
///     `estZoneSpeciale` qui le dit, jamais une comparaison de nom.
///
///   - Un établissement se DÉSACTIVE, il ne se supprime pas : sa suppression
///     emporterait le rattachement des signalements historiques.
library;

class RegionRef {
  final String id;
  final String code;
  final String nom;
  final bool estZoneSpeciale;
  final bool actif;
  final int ordre;

  const RegionRef({
    required this.id,
    required this.code,
    required this.nom,
    required this.estZoneSpeciale,
    required this.actif,
    required this.ordre,
  });

  factory RegionRef.fromJson(Map<String, dynamic> json) => RegionRef(
        id: json['id'] as String,
        code: json['code'] as String,
        nom: json['nom'] as String,
        estZoneSpeciale: json['est_zone_speciale'] ?? false,
        actif: json['actif'] ?? true,
        ordre: json['ordre'] ?? 0,
      );
}

class PrefectureRef {
  final String id;
  final String regionId;
  final String code;
  final String nom;
  final bool actif;

  const PrefectureRef({
    required this.id,
    required this.regionId,
    required this.code,
    required this.nom,
    required this.actif,
  });

  factory PrefectureRef.fromJson(Map<String, dynamic> json) => PrefectureRef(
        id: json['id'] as String,
        regionId: json['region_id'] as String,
        code: json['code'] as String,
        nom: json['nom'] as String,
        actif: json['actif'] ?? true,
      );
}

class FormationSanitaire {
  final String id;
  final String prefectureId;
  final String? code;
  final String nom;
  final String? typeEtablissement;
  final bool actif;

  /// D'où vient la ligne : 'saisie_manuelle', 'import_fichier' ou 'dhis2'.
  /// Sert à savoir ce qui a été saisi à la main et ce qui pourra être
  /// réécrasé par une ingestion ultérieure.
  final String source;

  /// Renseignés par la jointure de lecture, absents à l'écriture.
  final String? prefectureNom;
  final String? regionNom;

  const FormationSanitaire({
    required this.id,
    required this.prefectureId,
    required this.nom,
    this.code,
    this.typeEtablissement,
    this.actif = true,
    this.source = 'saisie_manuelle',
    this.prefectureNom,
    this.regionNom,
  });

  factory FormationSanitaire.fromJson(Map<String, dynamic> json) {
    // La jointure imbriquée de PostgREST renvoie un objet, ou null si la
    // préfecture a été désactivée depuis. On ne suppose ni l'un ni l'autre.
    final prefecture = json['prefectures'] as Map<String, dynamic>?;
    final region = prefecture?['regions'] as Map<String, dynamic>?;

    return FormationSanitaire(
      id: json['id'] as String,
      prefectureId: json['prefecture_id'] as String,
      code: json['code'] as String?,
      nom: json['nom'] as String,
      typeEtablissement: json['type_etablissement'] as String?,
      actif: json['actif'] ?? true,
      source: json['source'] ?? 'saisie_manuelle',
      prefectureNom: prefecture?['nom'] as String?,
      regionNom: region?['nom'] as String?,
    );
  }
}

/// Une graphie rencontrée dans les signalements et qui n'est rattachée à
/// aucun établissement. Lue depuis la vue `rapprochements_en_attente`.
class RapprochementEnAttente {
  final String libelleNorme;
  final String exempleSaisi;
  final String region;
  final String prefecture;
  final int occurrences;
  final DateTime? derniereOccurrence;

  const RapprochementEnAttente({
    required this.libelleNorme,
    required this.exempleSaisi,
    required this.region,
    required this.prefecture,
    required this.occurrences,
    this.derniereOccurrence,
  });

  factory RapprochementEnAttente.fromJson(Map<String, dynamic> json) =>
      RapprochementEnAttente(
        libelleNorme: json['libelle_norme'] as String,
        exempleSaisi: json['exemple_saisi'] as String,
        region: json['region'] as String,
        prefecture: json['prefecture'] as String,
        occurrences: json['occurrences'] ?? 0,
        derniereOccurrence: json['derniere_occurrence'] != null
            ? DateTime.tryParse(json['derniere_occurrence'] as String)
            : null,
      );
}

/// Résultat d'un import de fichier, ligne à ligne.
///
/// POURQUOI UN COMPTE RENDU DÉTAILLÉ, ET PAS UN SIMPLE « 130 lignes importées »
///   Un import qui annonce un succès global alors que douze lignes ont été
///   écartées laisse douze établissements absents du référentiel, donc douze
///   sites hors de la mesure, sans que personne ne le sache. L'écran doit
///   pouvoir dire QUELLE ligne a échoué et POURQUOI.
class ResultatImport {
  final int crees;
  final int misAJour;
  final List<String> rejets;

  const ResultatImport({
    required this.crees,
    required this.misAJour,
    required this.rejets,
  });

  int get total => crees + misAJour;
}
