import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/audio_model.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  AudioService._internal();

  factory AudioService() => _instance;

  static const _bucket = 'audios-signalements';

  Future<void> uploaderAudio({
    required String signalementId,
    required File fichier,
    int? dureeSecondes,
  }) async {
    try {
      final chemin = '$signalementId/audio.m4a';
      await SupabaseConfig.client.storage.from(_bucket).upload(
            chemin,
            fichier,
            fileOptions: FileOptions(upsert: true),
          );
      await SupabaseConfig.client.from('audios').insert({
        'signalement_id': signalementId,
        'chemin_stockage': chemin,
        'storage_path': chemin,
        'duree_secondes': dureeSecondes,
        'recu_le': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur upload audio: $e');
    }
  }

  Future<void> lierAudioExistant({
    required String signalementId,
    required String cheminStockage,
    int? dureeSecondes,
  }) async {
    try {
      await SupabaseConfig.client.from('audios').insert({
        'signalement_id': signalementId,
        'chemin_stockage': cheminStockage,
        'storage_path': cheminStockage,
        'duree_secondes': dureeSecondes,
        'recu_le': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur liaison audio: $e');
    }
  }

  Future<AudioSignalement?> obtenirAudioPourSignalement(String signalementId) async {
    try {
      final response = await SupabaseConfig.client
          .from('audios')
          .select()
          .eq('signalement_id', signalementId)
          .maybeSingle();
      if (response == null) return null;
      return AudioSignalement.fromJson(response);
    } catch (e) {
      return null;
    }
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
}
