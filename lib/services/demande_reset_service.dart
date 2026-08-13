import '../config/supabase_config.dart';
import '../models/demande_reset_model.dart';

class DemandeResetService {
  static final DemandeResetService _instance = DemandeResetService._internal();
  DemandeResetService._internal();
  factory DemandeResetService() => _instance;

  // Stream temps réel des demandes en attente, enrichies (nom, rôle, zone).
  //
  // .stream() ne fonctionne que sur une table, pas sur une vue. On écoute donc
  // la table demandes_reset (filtrée en_attente) pour la réactivité, et à
  // chaque émission on relit la vue demandes_reset_enrichies qui porte la
  // jointure avec users. asyncMap garde l'ordre des émissions.
  Stream<List<DemandeReset>> streamDemandesEnAttente() {
    return SupabaseConfig.client
        .from('demandes_reset')
        .stream(primaryKey: ['id'])
        .eq('statut', 'en_attente')
        .order('demande_le', ascending: true)
        .asyncMap((_) async {
      final rows = await SupabaseConfig.client
          .from('demandes_reset_enrichies')
          .select()
          .order('demande_le', ascending: true);
      return (rows as List)
          .map((r) => DemandeReset.fromMap(r as Map<String, dynamic>))
          .toList();
    });
  }

  // Déclenche le traitement d'une demande : appelle l'Edge Function
  // rapid-action (= traiter-reset). Le JWT admin part automatiquement
  // via le client authentifié. La fonction génère le mot de passe
  // temporaire, force doit_changer_mdp, envoie l'email et passe la
  // demande à 'traitee' (elle disparaît alors du stream ci-dessus).
  Future<void> traiterDemande(String demandeId) async {
    final res = await SupabaseConfig.client.functions.invoke(
      'rapid-action',
      body: {'demande_id': demandeId},
    );

    final data = res.data;
    if (data is Map && data['ok'] == true) {
      return; // succès
    }
    final message = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Échec du traitement de la demande';
    throw Exception(message);
  }
// Demande de réinitialisation déclenchée par un utilisateur DÉCONNECTÉ
  // depuis l'écran de login. Appelle quick-task (= demande-reset), qui ne
  // requiert aucune authentification et renvoie TOUJOURS une réponse uniforme
  // (anti-énumération). On ne peut donc pas savoir si l'email correspond à un
  // compte : c'est voulu. On ne remonte pas d'erreur métier, juste les erreurs
  // techniques (réseau).
  Future<void> demanderReset(String email) async {
    await SupabaseConfig.client.functions.invoke(
      'quick-task',
      body: {'email': email},
    );
    // Réponse toujours uniforme côté serveur : rien à interpréter ici.
  }
}