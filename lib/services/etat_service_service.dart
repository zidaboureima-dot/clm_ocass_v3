import '../config/supabase_config.dart';

/// État de service du pays, tel que lu depuis la vue publique `etat_service`.
class EtatService {
  final bool actif;
  final String? message;

  const EtatService({required this.actif, this.message});

  /// État retenu quand la lecture échoue : **service considéré actif**.
  ///
  /// Voir `EtatServiceService.lire()` pour le raisonnement.
  static const EtatService parDefaut = EtatService(actif: true);
}

/// Lecture de l'interrupteur de maintenance.
///
/// L'interrupteur bloque l'accès aux tableaux de bord des responsables. Il ne
/// bloque jamais le dépôt d'un signalement par un citoyen : une personne qui a
/// pris le risque de venir signaler et qui tombe sur un écran de maintenance
/// ne reviendra pas forcément. Le signalement serait perdu, et la confiance
/// avec lui.
///
/// Voir `supabase/migrations/20261005_mode_maintenance.sql`.
class EtatServiceService {
  static final EtatServiceService _instance = EtatServiceService._internal();

  EtatServiceService._internal();

  factory EtatServiceService() => _instance;

  /// Code du pays de ce déploiement. Un seul pays par build (voir la directive
  /// de distribution mobile dans CADRAGE_SAAS_CONSOLIDE.md).
  static const paysCode = 'GN';

  /// Lit l'état du service.
  ///
  /// ÉCHOUE EN POSITION OUVERTE. Si la lecture échoue — réseau coupé, vue
  /// absente, délai dépassé — la méthode renvoie `EtatService.parDefaut`,
  /// c'est-à-dire un service actif.
  ///
  /// C'est contre-intuitif pour un interrupteur de sécurité, et c'est pourtant
  /// le seul choix défendable : dans le cas inverse, une simple coupure réseau
  /// verrouillerait l'application pour tout le monde, y compris pour des
  /// responsables qui n'ont qu'une fenêtre de connexion par jour. Un
  /// interrupteur de maintenance protège d'un incident connu ; il ne doit pas
  /// en créer un nouveau.
  ///
  /// Le délai est volontairement court : si la vérification traîne, mieux vaut
  /// laisser entrer que faire attendre.
  Future<EtatService> lire() async {
    try {
      final reponse = await SupabaseConfig.client
          .from('etat_service')
          .select('service_actif, service_message')
          .eq('pays_code', paysCode)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (reponse == null) return EtatService.parDefaut;

      return EtatService(
        actif: reponse['service_actif'] as bool? ?? true,
        message: reponse['service_message'] as String?,
      );
    } catch (_) {
      // Aucune journalisation : l'échec de cette lecture n'est pas un
      // incident, c'est un cas prévu.
      return EtatService.parDefaut;
    }
  }
}
