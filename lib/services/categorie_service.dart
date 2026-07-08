import '../config/supabase_config.dart';
import '../models/categorie_model.dart';

class CategorieService {
  static final CategorieService _instance = CategorieService._internal();

  CategorieService._internal();

  factory CategorieService() => _instance;

  Future<Map<String, List<Categorie>>> obtenirCategoriesParGroupe() async {
    final response = await SupabaseConfig.client
        .from('categories')
        .select()
        .eq('actif', true)
        .order('ordre', ascending: true);

    final categories = (response as List).map((j) => Categorie.fromJson(j)).toList();

    final Map<String, List<Categorie>> parGroupe = {};
    for (final c in categories) {
      parGroupe.putIfAbsent(c.groupe, () => []).add(c);
    }
    return parGroupe;
  }

  Stream<List<Categorie>> streamToutesCategories() {
    return SupabaseConfig.client
        .from('categories')
        .stream(primaryKey: ['id'])
        .order('ordre', ascending: true)
        .map((rows) => rows.map((r) => Categorie.fromJson(r)).toList());
  }

  Future<void> basculerActif(String id, bool actif) async {
    try {
      await SupabaseConfig.client.from('categories').update({'actif': actif}).eq('id', id);
    } catch (e) {
      throw Exception('Erreur mise à jour catégorie: $e');
    }
  }

  Future<void> ajouterCategorie({
    required String groupe,
    required String libelle,
    required int ordre,
  }) async {
    try {
      await SupabaseConfig.client.from('categories').insert({
        'groupe': groupe,
        'libelle': libelle,
        'ordre': ordre,
        'actif': true,
      });
    } catch (e) {
      throw Exception('Erreur ajout catégorie: $e');
    }
  }
}
