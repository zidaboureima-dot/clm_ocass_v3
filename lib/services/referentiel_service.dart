import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/regions_prefectures.dart';
import '../models/referentiel_model.dart';

/// Accès au référentiel géographique et sanitaire.
///
/// Voir supabase/migrations/20261012_referentiel_geo_sanitaire.sql.
///
/// LE REPLI SUR LA LISTE CODÉE EN DUR
///   `obtenirRegions()` et `obtenirPrefectures()` reviennent à
///   `RegionsPrefectures` si la base est injoignable. Ce n'est pas de la
///   prudence de principe : le formulaire citoyen ne peut pas se permettre
///   d'être bloqué par une lecture de référentiel. Une personne venue
///   signaler un refus de soins et qui trouve une liste déroulante vide ne
///   revient pas.
///
///   Le repli sert donc le DÉPÔT, où une géographie légèrement datée est
///   sans conséquence — la région est de toute façon vérifiée côté serveur.
///   Il ne sert PAS l'administration : y masquer une panne ferait créer des
///   établissements sous des préfectures qui n'existent plus. Les méthodes
///   d'administration laissent donc remonter l'erreur.
///
/// CE QUE CE SERVICE NE FAIT PAS
///   Il ne touche jamais à `signalements.region` ni à `.prefecture`. Ces
///   colonnes portent le cloisonnement RLS via `region_du_demandeur()`, qui
///   compare du texte. Le référentiel s'ajoute à côté, il ne s'y substitue
///   pas.
class ReferentielService {
  static final ReferentielService _instance = ReferentielService._internal();

  ReferentielService._internal();

  factory ReferentielService() => _instance;

  /// Au-delà, on considère la base injoignable et on se replie. Même durée
  /// que la lecture de l'état de service : c'est le seuil au-delà duquel
  /// l'utilisateur a déjà quitté l'écran.
  static const Duration _delai = Duration(seconds: 5);

  // Mémorisation pour la session. Le référentiel change à la marge — un
  // décret, un établissement ajouté — et le relire à chaque ouverture de
  // liste déroulante coûterait une requête par frappe sur un réseau lent.
  List<RegionRef>? _regionsEnCache;
  final Map<String, List<PrefectureRef>> _prefecturesEnCache = {};

  /// À appeler après toute écriture sur le référentiel, et par
  /// l'administrateur qui veut forcer une relecture.
  void viderCache() {
    _regionsEnCache = null;
    _prefecturesEnCache.clear();
  }

  // -------------------------------------------------------------------
  // Lecture — avec repli
  // -------------------------------------------------------------------

  /// Régions actives, Conakry comprise. Se replie sur la liste codée en dur.
  Future<List<RegionRef>> obtenirRegions() async {
    if (_regionsEnCache != null) return _regionsEnCache!;

    try {
      final reponse = await SupabaseConfig.client
          .from('regions')
          .select()
          .eq('actif', true)
          .order('ordre')
          .timeout(_delai);

      final regions =
          (reponse as List).map((j) => RegionRef.fromJson(j)).toList();

      // Une base joignable mais vide n'est pas un succès : elle viderait les
      // listes déroulantes. On se replie, comme pour une panne.
      if (regions.isEmpty) return _regionsDeSecours();

      _regionsEnCache = regions;
      return regions;
    } catch (_) {
      return _regionsDeSecours();
    }
  }

  /// Préfectures d'une région. Se replie sur la liste codée en dur.
  Future<List<PrefectureRef>> obtenirPrefectures(String regionId) async {
    final enCache = _prefecturesEnCache[regionId];
    if (enCache != null) return enCache;

    try {
      final reponse = await SupabaseConfig.client
          .from('prefectures')
          .select()
          .eq('region_id', regionId)
          .eq('actif', true)
          .order('nom')
          .timeout(_delai);

      final prefectures =
          (reponse as List).map((j) => PrefectureRef.fromJson(j)).toList();

      if (prefectures.isEmpty) return _prefecturesDeSecours(regionId);

      _prefecturesEnCache[regionId] = prefectures;
      return prefectures;
    } catch (_) {
      return _prefecturesDeSecours(regionId);
    }
  }

  /// Identifiants de secours, construits à partir du nom.
  ///
  /// Ils ne correspondent à aucune ligne réelle : ils ne servent qu'à faire
  /// fonctionner les listes déroulantes hors ligne, où seul le NOM finit par
  /// être enregistré sur le signalement. Ne jamais les écrire en base.
  static String _idDeSecours(String nom) => 'secours:$nom';

  static bool estIdDeSecours(String id) => id.startsWith('secours:');

  List<RegionRef> _regionsDeSecours() {
    final noms = RegionsPrefectures.regions;
    return [
      for (var i = 0; i < noms.length; i++)
        RegionRef(
          id: _idDeSecours(noms[i]),
          code: noms[i],
          nom: noms[i],
          estZoneSpeciale: noms[i] == RegionsPrefectures.zoneSpeciale,
          actif: true,
          ordre: i,
        ),
    ];
  }

  List<PrefectureRef> _prefecturesDeSecours(String regionId) {
    // L'identifiant de secours porte le nom de la région ; un vrai uuid n'a
    // aucune correspondance dans la liste codée en dur, et renvoyer une liste
    // vide est alors la réponse juste.
    if (!estIdDeSecours(regionId)) return const [];
    final nomRegion = regionId.substring('secours:'.length);
    return [
      for (final p in RegionsPrefectures.prefecturesDe(nomRegion))
        PrefectureRef(
          id: _idDeSecours(p),
          regionId: regionId,
          code: p,
          nom: p,
          actif: true,
        ),
    ];
  }

  // -------------------------------------------------------------------
  // Formations sanitaires
  // -------------------------------------------------------------------

  /// Établissements, filtrés si demandé. Pas de repli : une liste vide due à
  /// une panne doit se voir, pas se deviner.
  Future<List<FormationSanitaire>> obtenirFormations({
    String? prefectureId,
    String? regionId,
    bool seulementActifs = false,
  }) async {
    var requete = SupabaseConfig.client
        .from('formations_sanitaires')
        .select('*, prefectures(nom, region_id, regions(nom))');

    if (prefectureId != null) requete = requete.eq('prefecture_id', prefectureId);
    if (regionId != null) requete = requete.eq('prefectures.region_id', regionId);
    if (seulementActifs) requete = requete.eq('actif', true);

    final reponse = await requete.order('nom');
    return (reponse as List)
        .map((j) => FormationSanitaire.fromJson(j))
        // Une jointure imbriquée filtrée renvoie la ligne avec `prefectures`
        // à null plutôt que de l'exclure. On écarte donc ici ce que le filtre
        // sur la région n'a pas retenu.
        .where((f) => regionId == null || f.prefectureNom != null)
        .toList();
  }

  Future<void> creerFormation({
    required String prefectureId,
    required String nom,
    String? code,
    String? typeEtablissement,
    String source = 'saisie_manuelle',
  }) async {
    try {
      await SupabaseConfig.client.from('formations_sanitaires').insert({
        'prefecture_id': prefectureId,
        'nom': nom,
        if (code != null && code.isNotEmpty) 'code': code,
        if (typeEtablissement != null && typeEtablissement.isNotEmpty)
          'type_etablissement': typeEtablissement,
        'source': source,
      });
    } on PostgrestException catch (e) {
      throw Exception(_messageLisible(e, nom));
    }
  }

  Future<void> modifierFormation({
    required String id,
    String? nom,
    String? code,
    String? typeEtablissement,
    String? prefectureId,
    bool? actif,
  }) async {
    try {
      await SupabaseConfig.client.from('formations_sanitaires').update({
        if (nom != null) 'nom': nom,
        // Un champ vidé par l'administrateur devient NULL, jamais ''.
        // `code` porte une contrainte d'unicité : deux établissements sans
        // code, enregistrés avec une chaîne vide, se refuseraient l'un
        // l'autre — et le message parlerait d'un doublon de code que
        // personne n'a saisi.
        if (code != null) 'code': code.isEmpty ? null : code,
        if (typeEtablissement != null)
          'type_etablissement':
              typeEtablissement.isEmpty ? null : typeEtablissement,
        if (prefectureId != null) 'prefecture_id': prefectureId,
        if (actif != null) 'actif': actif,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(_messageLisible(e, nom ?? ''));
    }
  }

  /// Traduit les violations de contrainte en phrases exploitables.
  ///
  /// Le texte brut d'une PostgrestException cite noms de tables, de colonnes
  /// et d'index — information d'architecture, affichée sur un appareil qui
  /// peut être consulté par un tiers. Même règle que `EtatErreur`.
  String _messageLisible(PostgrestException e, String nom) {
    final m = e.message;
    if (m.contains('formations_nom_normalise_uniq')) {
      return nom.isEmpty
          ? 'Un établissement portant ce nom existe déjà dans cette préfecture.'
          : '« $nom » existe déjà dans cette préfecture.';
    }
    if (m.contains('formations_sanitaires_code_key')) {
      return 'Ce code est déjà attribué à un autre établissement.';
    }
    if (m.contains('formations_source_connue')) {
      return 'Origine inconnue : attendu saisie manuelle, import ou DHIS2.';
    }
    if (m.contains('row-level security') || e.code == '42501') {
      return 'Seul un administrateur peut modifier le référentiel.';
    }
    return 'L\'enregistrement a échoué. Réessayez dans un instant.';
  }

  // -------------------------------------------------------------------
  // Import de fichier
  // -------------------------------------------------------------------

  /// Importe des établissements depuis des lignes déjà découpées.
  ///
  /// Chaque ligne porte : région, préfecture, nom, et facultativement type et
  /// code. Le rattachement se fait sur les NOMS, pas sur des identifiants :
  /// un fichier préparé par un tiers ne connaît pas nos uuid.
  ///
  /// POURQUOI LES REJETS SONT COLLECTÉS ET NON LEVÉS
  ///   Interrompre à la première ligne fautive laisserait l'import à moitié
  ///   fait sans que personne sache où il s'est arrêté. On importe tout ce
  ///   qui est importable et on rend compte du reste, ligne à ligne.
  Future<ResultatImport> importerFormations(
    List<LigneImport> lignes, {
    bool mettreAJourSiExiste = true,
  }) async {
    final regions = await _chargerRegionsPourImport();
    final prefectures = await _chargerPrefecturesPourImport();
    final existants = {
      for (final f in await obtenirFormations())
        '${f.prefectureId}|${_normaliser(f.nom)}': f,
    };

    var crees = 0;
    var misAJour = 0;
    final rejets = <String>[];

    for (final ligne in lignes) {
      final numero = ligne.numeroLigne;

      if (ligne.nom.trim().isEmpty) {
        rejets.add('Ligne $numero : nom d\'établissement vide.');
        continue;
      }

      final regionId = regions[_normaliser(ligne.region)];
      if (regionId == null) {
        rejets.add('Ligne $numero : région « ${ligne.region} » inconnue.');
        continue;
      }

      final prefectureId = prefectures['$regionId|${_normaliser(ligne.prefecture)}'];
      if (prefectureId == null) {
        rejets.add('Ligne $numero : préfecture « ${ligne.prefecture} » '
            'absente de la région « ${ligne.region} ».');
        continue;
      }

      final cle = '$prefectureId|${_normaliser(ligne.nom)}';
      final dejaLa = existants[cle];

      try {
        if (dejaLa != null) {
          if (!mettreAJourSiExiste) continue;
          await modifierFormation(
            id: dejaLa.id,
            code: ligne.code,
            typeEtablissement: ligne.type,
          );
          misAJour++;
        } else {
          await creerFormation(
            prefectureId: prefectureId,
            nom: ligne.nom.trim(),
            code: ligne.code,
            typeEtablissement: ligne.type,
            source: 'import_fichier',
          );
          crees++;
        }
      } catch (e) {
        rejets.add('Ligne $numero : ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }

    viderCache();
    return ResultatImport(crees: crees, misAJour: misAJour, rejets: rejets);
  }

  Future<Map<String, String>> _chargerRegionsPourImport() async {
    final reponse =
        await SupabaseConfig.client.from('regions').select('id, nom');
    return {
      for (final r in reponse as List)
        _normaliser(r['nom'] as String): r['id'] as String,
    };
  }

  Future<Map<String, String>> _chargerPrefecturesPourImport() async {
    final reponse = await SupabaseConfig.client
        .from('prefectures')
        .select('id, nom, region_id');
    return {
      for (final p in reponse as List)
        '${p['region_id']}|${_normaliser(p['nom'] as String)}': p['id'] as String,
    };
  }

  /// Reproduit `public.normaliser_libelle` côté client, pour comparer sans
  /// aller-retour réseau.
  ///
  /// ATTENTION : cette fonction et son homologue SQL doivent rester
  /// identiques. Si l'une change, l'autre aussi — sans quoi l'import croira
  /// créer un établissement que la base refusera comme doublon, ou
  /// l'inverse. La base reste l'autorité : c'est son index unique qui
  /// tranche, celle-ci n'évite que des requêtes inutiles.
  static String _normaliser(String texte) {
    const avec = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ';
    const sans = 'aaaaaaceeeeiiiinooooouuuuyy';
    var s = texte.toLowerCase();
    for (var i = 0; i < avec.length; i++) {
      s = s.replaceAll(avec[i], sans[i]);
    }
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // -------------------------------------------------------------------
  // Rapprochement
  // -------------------------------------------------------------------

  /// Graphies rencontrées dans les signalements et rattachées à rien.
  Future<List<RapprochementEnAttente>> obtenirRapprochementsEnAttente({
    int limite = 100,
  }) async {
    final reponse = await SupabaseConfig.client
        .from('rapprochements_en_attente')
        .select()
        .limit(limite);
    return (reponse as List)
        .map((j) => RapprochementEnAttente.fromJson(j))
        .toList();
  }

  /// Rattache une graphie à un établissement, et renvoie le nombre de
  /// signalements déjà déposés qui viennent d'être repris.
  ///
  /// L'alias et la reprise de l'historique sont faits par la base, dans un
  /// seul appel : les séparer reviendrait à accepter qu'ils divergent.
  Future<int> rapprocher({
    required String libelle,
    required String formationId,
  }) async {
    try {
      final reponse = await SupabaseConfig.client.rpc(
        'rapprocher_libelle',
        params: {'p_libelle': libelle, 'p_formation_id': formationId},
      );
      return reponse is int ? reponse : 0;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw Exception('Seul un administrateur peut rapprocher un libellé.');
      }
      if (e.message.contains('inconnue ou désactivée')) {
        throw Exception('Cet établissement n\'est plus actif.');
      }
      throw Exception('Le rapprochement a échoué. Réessayez dans un instant.');
    }
  }
}

/// Une ligne de fichier d'import, déjà découpée.
class LigneImport {
  final int numeroLigne;
  final String region;
  final String prefecture;
  final String nom;
  final String? type;
  final String? code;

  const LigneImport({
    required this.numeroLigne,
    required this.region,
    required this.prefecture,
    required this.nom,
    this.type,
    this.code,
  });
}
