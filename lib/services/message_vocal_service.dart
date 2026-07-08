import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/message_vocal_brut_model.dart';

class MessageVocalService {
  static final MessageVocalService _instance = MessageVocalService._internal();

  MessageVocalService._internal();

  factory MessageVocalService() => _instance;

  static const _bucket = 'audios-signalements';

  Future<void> uploaderMessageVocal({
    required File fichier,
    int? dureeSecondes,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final chemin = 'bruts/$id/audio.m4a';
      await SupabaseConfig.client.storage.from(_bucket).upload(
            chemin,
            fichier,
            fileOptions: FileOptions(upsert: true),
          );
      await SupabaseConfig.client.from('messages_vocaux_bruts').insert({
        'chemin_stockage': chemin,
        'duree_secondes': dureeSecondes,
        'statut': 'nouveau',
      });
    } catch (e) {
      throw Exception('Erreur upload message vocal: $e');
    }
  }

  Stream<List<MessageVocalBrut>> streamMessagesNonTraites() {
    return SupabaseConfig.client
        .from('messages_vocaux_bruts')
        .stream(primaryKey: ['id'])
        .eq('statut', 'nouveau')
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => MessageVocalBrut.fromJson(r)).toList());
  }

  Future<String> obtenirUrlSignee(String cheminStockage) async {
    try {
      return await SupabaseConfig.client.storage
          .from(_bucket)
          .createSignedUrl(cheminStockage, 3600);
    } catch (e) {
      throw Exception('Erreur génération URL audio: $e');
    }
  }

  Future<void> marquerTraite({
    required String messageId,
    required String signalementId,
  }) async {
    try {
      await SupabaseConfig.client.from('messages_vocaux_bruts').update({
        'statut': 'traite',
        'signalement_id': signalementId,
      }).eq('id', messageId);
    } catch (e) {
      throw Exception('Erreur mise à jour message vocal: $e');
    }
  }
}
