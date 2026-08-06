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

  // Marque un message vocal comme traité APRES avoir supprimé le fichier
  // audio du stockage. Confidentialité (Modèle A) : l'enregistrement vocal
  // brut est détruit dès qu'il est transformé en signalement structuré, il
  // n'est jamais conservé ni réécoutable. La suppression du fichier se fait
  // AVANT la mise à jour en base : si elle échoue, on ne marque pas le
  // message comme traité, pour ne pas laisser croire à une suppression qui
  // n'a pas eu lieu. Le chemin_stockage est vidé pour ne plus pointer vers
  // un fichier inexistant.
  //
  // ATTENTION : storage.remove() de Supabase ne lève PAS d'exception quand le
  // fichier est introuvable, il renvoie une liste vide. On doit donc vérifier
  // explicitement que le fichier a bien été supprimé avant de vider la base.
  Future<void> marquerTraite({
    required String messageId,
    required String signalementId,
    required String cheminStockage,
  }) async {
    try {
      // 1) Supprimer le fichier audio du bucket (étape critique, en premier).
      final supprimes = await SupabaseConfig.client.storage
          .from(_bucket)
          .remove([cheminStockage]);

      // 2) Vérifier que la suppression a RÉELLEMENT eu lieu. remove() renvoie
      //    la liste des objets effacés : si elle est vide, le fichier n'a pas
      //    été trouvé/supprimé, on refuse de continuer.
      final aSupprime = supprimes.any((obj) => obj.name == cheminStockage);
      if (!aSupprime) {
        throw Exception(
          'Le fichier audio n\'a pas pu être supprimé du stockage '
          '(chemin: $cheminStockage). Traitement annulé pour ne pas '
          'laisser croire à une suppression non effectuée.',
        );
      }

      // 3) Seulement si la suppression est confirmée : marquer traité et vider le chemin.
      await SupabaseConfig.client.from('messages_vocaux_bruts').update({
        'statut': 'traite',
        'signalement_id': signalementId,
        'chemin_stockage': null,
      }).eq('id', messageId);
    } catch (e) {
      throw Exception('Erreur suppression/traitement message vocal: $e');
    }
  }
}