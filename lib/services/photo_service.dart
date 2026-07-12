import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/photo_model.dart';

class PhotoService {
  static final PhotoService _instance = PhotoService._internal();

  PhotoService._internal();

  factory PhotoService() => _instance;

  static const _bucket = 'photos-signalements';

  Future<void> uploaderPhoto({
    required String signalementId,
    required File fichier,
  }) async {
    try {
      final chemin = '$signalementId/photo.jpg';
      await SupabaseConfig.client.storage.from(_bucket).upload(chemin, fichier);
      await SupabaseConfig.client.from('photos').insert({
        'signalement_id': signalementId,
        'chemin_stockage': chemin,
      });
    } catch (e) {
      throw Exception('Erreur upload photo: $e');
    }
  }

  Future<void> lierPhotoExistante({
    required String signalementId,
    required String cheminStockage,
  }) async {
    try {
      await SupabaseConfig.client.from('photos').insert({
        'signalement_id': signalementId,
        'chemin_stockage': cheminStockage,
      });
    } catch (e) {
      throw Exception('Erreur liaison photo: $e');
    }
  }

  Future<PhotoSignalement?> obtenirPhotoPourSignalement(String signalementId) async {
    try {
      final response = await SupabaseConfig.client
          .from('photos')
          .select()
          .eq('signalement_id', signalementId)
          .maybeSingle();
      if (response == null) return null;
      return PhotoSignalement.fromJson(response);
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
      throw Exception('Erreur génération URL photo: $e');
    }
  }
}
