import '../config/supabase_config.dart';
import '../models/annotation_model.dart';

class AnnotationService {
  static final AnnotationService _instance = AnnotationService._internal();

  AnnotationService._internal();

  factory AnnotationService() => _instance;

  Future<void> ajouterAnnotation(Annotation annotation) async {
    try {
      await SupabaseConfig.client.from('annotations').insert(annotation.toJson());
    } catch (e) {
      throw Exception('Erreur ajout annotation: $e');
    }
  }

  Stream<List<Annotation>> streamAnnotations(String signalementId) {
    return SupabaseConfig.client
        .from('annotations')
        .stream(primaryKey: ['id'])
        .eq('signalement_id', signalementId)
        .order('created_at')
        .map((rows) => rows.map((r) => Annotation.fromJson(r)).toList());
  }
}
