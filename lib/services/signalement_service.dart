import '../config/supabase_config.dart';
import '../models/signalement_model.dart';

class SignalementService {
  static final SignalementService _instance = SignalementService._internal();

  SignalementService._internal();

  factory SignalementService() => _instance;

  Future<void> creerSignalement(Signalement signalement) async {
    try {
      final data = signalement.toJson();
      await SupabaseConfig.client.from('signalements').insert(data);
    } catch (e) {
      throw Exception('Erreur creation: $e');
    }
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
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsParRegion(String region) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('region', region)
        .order('soumis_le', ascending: false)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
  }

  Stream<List<Signalement>> streamSignalementsAssignes(String pointFocalUid) {
    return SupabaseConfig.client
        .from('signalements')
        .stream(primaryKey: ['id'])
        .eq('assignee_uid', pointFocalUid)
        .order('soumis_le', ascending: false)
        .map((rows) => rows.map((r) => Signalement.fromJson(r)).toList());
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

  Map<String, int> calculerStats(List<Map<String, dynamic>> lignes) {
    return {
      'total': lignes.length,
      'en_cours': lignes.where((l) => l['statut'] == 'en_cours').length,
      'traites': lignes.where((l) => l['statut'] == 'traite').length,
      'clotures': lignes.where((l) => l['statut'] == 'cloture').length,
    };
  }
}
