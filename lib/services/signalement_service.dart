import '../config/supabase_config.dart';
import '../models/stats_agregees_model.dart';
import '../models/signalement_model.dart';
import 'marqueur_appareil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignalementService {
  static final SignalementService _instance = SignalementService._internal();

  SignalementService._internal();

  factory SignalementService() => _instance;

  /// Nombre de signalements que les flux temps réel rapportent au plus.
  ///
  /// POURQUOI BORNER
  ///   Sans limite, chaque tableau de bord ouvre un flux sur la table entière.
  ///   À 59 signalements tout va bien ; à 2 000, un superviseur sur un
  ///   téléphone modeste en 3G attend ; à 10 000, l'écran administrateur
  ///   devient inutilisable. Rien n'alerte entre-temps : ça ne casse pas, ça
  ///   ralentit — et le profil d'appareil et de connexion visé par le projet
  ///   est précisément celui qui encaisse le moins bien.
  ///
  /// CE QUE `limit` FAIT RÉELLEMENT
  ///   Vérifié dans supabase_stream_builder.dart (paquet `supabase` 2.14.0,
  ///   version verrouillée par pubspec.lock) : la limite est appliquée
  ///   CÔTÉ SERVEUR sur la requête initiale, puis ré-appliquée côté client à
  ///   chaque émission. Ce n'est donc pas un simple rognage d'affichage : la
  ///   charge réseau est réellement réduite.
  ///
  /// CONSÉQUENCE À NE PAS OUBLIER
  ///   Les écrans filtrent le statut CÔTÉ CLIENT. Sur un flux borné, un filtre
  ///   « Clôturé » ne cherche donc que parmi les plus récents. Tout écran qui
  ///   consomme ces flux DOIT dire qu'il est tronqué et renvoyer vers
  ///   l'historique, sans quoi il affiche trois cas en laissant croire qu'il
  ///   n'y en a que trois. L'exhaustivité passe par `obtenirHistorique()`.
  static const int limiteFluxTempsReel = 100;

  /// Taille d'une page d'historique. Volontairement modeste : la cible est un
  /// appareil d'entrée de gamme sur une connexion lente.
  static const int taillePageHistorique = 25;

  /// Crée un signalement et **renvoie l'identifiant attribué par la base**.
  ///
  /// POURQUOI CETTE MÉTHODE RENVOIE QUELQUE CHOSE
  ///   Elle ne renvoyait rien, et les écrans se rabattaient sur un UUID
  ///   généré localement pour rattacher la photo et le message vocal. Or la
  ///   RPC n'insère pas cet identifiant : la base génère le sien. Les deux
  ///   ne coïncidaient jamais, et depuis le 11 août 2026 aucune pièce jointe
  ///   ne pouvait se rattacher à son signalement.
  ///
  ///   L'identifiant doit donc venir de la base, et de nulle part ailleurs.
  ///
  /// NE JAMAIS REVENIR À UN IDENTIFIANT CÔTÉ CLIENT pour ce flux — ni en le
  /// générant ici, ni en le faisant insérer par la RPC. Un appelant anonyme
  /// choisirait alors la clé primaire d'un signalement, donc rendrait les
  /// identifiants prévisibles sur le flux le plus exposé du dispositif.
  ///
  /// Voir `supabase/migrations/20261006_rpc_retourne_id_signalement.sql`.
  Future<String> creerSignalement(Signalement signalement) async {
    // Déclaré hors du `try` et nullable à dessein : l'analyse d'assignation
    // définie de Dart ne considère pas qu'une affectation faite dans un bloc
    // `try` a forcément eu lieu après celui-ci.
    Object? id;
    try {
      final data = signalement.toJson();
      final marqueur = await obtenirMarqueurAppareil();
      id = await SupabaseConfig.client.rpc(
        'soumettre_signalement_anonyme',
        params: {
          'p_contenu': data,
          'p_marqueur': marqueur,
        },
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('RATE_LIMIT')) {
        throw Exception('Trop de dépôts depuis cet appareil. Réessayez dans quelques minutes.');
      }
      throw Exception('Erreur creation: ${e.message}');
    } catch (e) {
      throw Exception('Erreur creation: $e');
    }

    // Contrôle hors du bloc try, pour qu'il ne soit pas ré-emballé par le
    // `catch` ci-dessus : si la fonction déployée est encore l'ancienne
    // (`returns void`), le retour est nul. Mieux vaut une erreur franche
    // qu'un média rattaché à rien — c'est précisément le défaut corrigé.
    if (id is! String) {
      throw Exception(
        'Le serveur n\'a pas renvoyé l\'identifiant du signalement. '
        'La migration 20261006 n\'a probablement pas été exécutée.',
      );
    }
    return id;
  }

  Future<List<Signalement>> obtenirSignalements() async {
    try {
      final response = await SupabaseConfig.client
          .from('signalements')
          .select()
          .order('soumis_le', ascending: false);
      return (response as List).map((json) => Signalement.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur recuperation: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamSignalements() {
    return SupabaseConfig.client.from('signalements').stream(primaryKey: ['id']);
  }

  Stream<List<Signalement>> streamToutesSignalements() {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .order('soumis_le', ascending: false)
        .limit(limiteFluxTempsReel)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsParRegion(String region) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('region', region)
        .order('soumis_le', ascending: false)
        .limit(limiteFluxTempsReel)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  // =====================================================================
  // FLUX NON BORNÉS — RÉSERVÉS AUX ÉCRANS DE STATISTIQUES
  //
  // POURQUOI ILS EXISTENT SÉPARÉMENT
  //   Les écrans de statistiques comptent. Un comptage sur un flux borné aux
  //   100 plus récents afficherait des chiffres faux sans rien signaler —
  //   « 12 clôturés » au lieu de 400. Mieux vaut un écran lent qu'un écran
  //   qui ment.
  //
  //   Les tableaux de bord, eux, affichent une liste de travail : la tronquer
  //   est acceptable dès lors que la troncature est dite et que l'historique
  //   complet reste accessible.
  //
  // DETTE ASSUMÉE
  //   La bonne réponse est une agrégation CÔTÉ SERVEUR, comme la vue
  //   `stats_publiques` le fait déjà pour le public — mais par périmètre, et
  //   avec le cloisonnement RLS qui va avec. Tant qu'elle n'existe pas, ces
  //   flux restent le chemin lourd du dispositif. Voir DETTES_SAAS.md.
  // =====================================================================

  Stream<List<Signalement>> streamToutesSignalementsPourStats() {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .order('soumis_le', ascending: false)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsParRegionPourStats(String region) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('region', region)
        .order('soumis_le', ascending: false)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsParPrefecturePourStats(String prefecture) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('prefecture', prefecture)
        .order('soumis_le', ascending: false)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsAssignes(String pointFocalUid) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('assignee_uid', pointFocalUid)
        .order('soumis_le', ascending: false)
        .limit(limiteFluxTempsReel)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  /// Historique paginé, interrogé ponctuellement — sans temps réel.
  ///
  /// POURQUOI UN CHEMIN SÉPARÉ DES FLUX
  ///   Un flux Supabase n'accepte qu'UN SEUL filtre serveur, déjà pris par
  ///   `region` chez le superviseur et `assignee_uid` chez le point focal. Le
  ///   statut ne peut donc pas y être filtré côté serveur, et un flux borné
  ///   filtré côté client ment dès qu'on cherche autre chose que du récent.
  ///
  ///   Une requête ordinaire n'a pas cette limite : tous les filtres sont
  ///   appliqués par le serveur, et `range()` ne rapporte qu'une page. C'est
  ///   ce qui rend l'historique à la fois exhaustif et léger.
  ///
  /// CE QU'ON PERD, ET POURQUOI C'EST ACCEPTABLE
  ///   Pas de mise à jour automatique. L'historique se consulte, il n'a pas
  ///   besoin de bouger sous les yeux — contrairement aux cas ouverts, qui
  ///   restent sur le flux temps réel.
  ///
  /// LE CLOISONNEMENT RESTE CELUI DU RLS
  ///   Les filtres ci-dessous servent le confort de lecture, PAS la sécurité.
  ///   Le périmètre réellement opposable est celui des policies RLS sur
  ///   `signalements` (voir `region_du_demandeur()`). Ne jamais raisonner
  ///   l'inverse : un filtre oublié ici n'ouvre rien, mais une policy manquante
  ///   ouvrirait tout.
  Future<List<Signalement>> obtenirHistorique({
    String? region,
    String? prefecture,
    String? assigneeUid,
    String? statut,
    int page = 0,
    int taille = taillePageHistorique,
  }) async {
    try {
      var requete = SupabaseConfig.client.from('signalements').select();

      if (region != null) requete = requete.eq('region', region);
      if (prefecture != null) requete = requete.eq('prefecture', prefecture);
      if (assigneeUid != null) requete = requete.eq('assignee_uid', assigneeUid);
      if (statut != null) requete = requete.eq('statut', statut);

      final debut = page * taille;
      final reponse = await requete
          .order('soumis_le', ascending: false)
          .range(debut, debut + taille - 1);

      return (reponse as List).map((json) => Signalement.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur récupération historique: $e');
    }
  }

  Future<void> mettreAJourStatut(String signalementId, String statut) async {
    try {
      await SupabaseConfig.client.from('signalements').update({'statut': statut}).eq('id', signalementId);
    } catch (e) {
      throw Exception('Erreur mise à jour statut: $e');
    }
  }

  Future<void> assignerPointFocal({
    required String signalementId,
    required String pointFocalUid,
    required String superviseurUid,
    required String statutActuel,
  }) async {
    try {
      final donnees = <String, dynamic>{
        'assignee_uid': pointFocalUid,
        'superviseur_uid': superviseurUid,
      };
      if (statutActuel == 'nouveau') donnees['statut'] = 'en_cours';
      await SupabaseConfig.client.from('signalements').update(donnees).eq('id', signalementId);
    } catch (e) {
      throw Exception('Erreur assignation: $e');
    }
  }
/// Lit la vue d'agrégats publique (comptes uniquement, aucune ligne de
  /// signalement exposée) et renvoie un objet structuré prêt à afficher.
  Future<StatsAgregees> obtenirStatsPubliques() async {
    try {
      final response = await SupabaseConfig.client
          .from('stats_publiques')
          .select();
      final lignes = (response as List).cast<Map<String, dynamic>>();
      return StatsAgregees.depuisLignesVue(lignes);
    } catch (e) {
      throw Exception('Erreur récupération statistiques: $e');
    }
  }
  Map<String, int> calculerStats(List<Map<String, dynamic>> lignes) {
    return {
      'total': lignes.length,
      'en_cours': lignes.where((l) => l['statut'] == 'en_cours').length,
      'traites': lignes.where((l) => l['statut'] == 'traite').length,
      'clotures': lignes.where((l) => l['statut'] == 'cloture').length,
    };
  }
}
