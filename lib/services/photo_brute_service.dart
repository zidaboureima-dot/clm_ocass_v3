import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/photo_brute_model.dart';

class PhotoBruteService {
  static final PhotoBruteService _instance = PhotoBruteService._internal();

  PhotoBruteService._internal();

  factory PhotoBruteService() => _instance;

  static const _bucket = 'photos-signalements';

  Future<void> uploaderPhotoBrute({required File fichier}) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final chemin = 'bruts/$id/photo.jpg';
      await SupabaseConfig.client.storage.from(_bucket).upload(chemin, fichier);
      await SupabaseConfig.client.from('photos_brutes').insert({
        'chemin_stockage': chemin,
        'statut': 'nouveau',
      });
    } catch (e) {
      throw Exception('Erreur upload photo: $e');
    }
  }

  Stream<List<PhotoBrute>> streamPhotosNonTraitees() {
    return SupabaseConfig.client
        .from('photos_brutes')
        .stream(primaryKey: ['id'])
        .eq('statut', 'nouveau')
        .order('created_at', ascending: true)
        .map((rows) => rows.map((r) => PhotoBrute.fromJson(r)).toList());
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

  Future<void> marquerTraitee({
    required String photoId,
    required String signalementId,
  }) async {
    try {
      await SupabaseConfig.client.from('photos_brutes').update({
        'statut': 'traite',
        'signalement_id': signalementId,
      }).eq('id', photoId);
    } catch (e) {
      throw Exception('Erreur mise à jour photo: $e');
    }
  }
}
