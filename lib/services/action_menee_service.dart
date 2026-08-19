import '../config/supabase_config.dart';
import '../models/action_menee_model.dart';

/// Accès aux actions menées sur un signalement.
///
/// ORDRE D'ÉCRITURE IMPORTANT : l'action doit être insérée AVANT le
/// changement de statut. Le trigger `trg_exiger_documentation_statut` refuse
/// le passage à « traité » sans action documentée, et à « clôturé » sans note
/// de synthèse. L'inverse échoue côté base.
class ActionMeneeService {
  static final ActionMeneeService _instance = ActionMeneeService._internal();

  ActionMeneeService._internal();

  factory ActionMeneeService() => _instance;

  Future<void> ajouterAction(ActionMenee action) async {
    try {
      await SupabaseConfig.client.from('actions_menees').insert(action.toJson());
    } catch (e) {
      throw Exception('Erreur ajout action menée: $e');
    }
  }

  Stream<List<ActionMenee>> streamActions(String signalementId) {
    return SupabaseConfig.client
        .from('actions_menees')
        .stream(primaryKey: ['id'])
        .eq('signalement_id', signalementId)
        .order('created_at')
        .map((rows) => rows.map((r) => ActionMenee.fromJson(r)).toList());
  }

  /// Actions d'une période, tous signalements du périmètre du demandeur
  /// (le RLS filtre). Destiné à l'extraction du rapport périodique.
  Future<List<ActionMenee>> obtenirActionsPeriode({
    required DateTime debut,
    required DateTime fin,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('actions_menees')
          .select()
          .gte('created_at', debut.toIso8601String())
          .lt('created_at', fin.toIso8601String())
          .order('created_at');
      return (response as List).map((json) => ActionMenee.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur récupération actions de la période: $e');
    }
  }
}
