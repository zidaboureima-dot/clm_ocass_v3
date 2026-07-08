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
}
