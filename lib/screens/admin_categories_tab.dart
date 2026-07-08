import 'package:flutter/material.dart';
import '../models/categorie_model.dart';
import '../services/categorie_service.dart';
import '../theme/app_colors.dart';

class AdminCategoriesTab extends StatefulWidget {
  const AdminCategoriesTab({super.key});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab> {
  late Stream<List<Categorie>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = CategorieService().streamToutesCategories();
  }

  Future<void> _ouvrirDialogueAjout(List<Categorie> categoriesExistantes) async {
    final groupesExistants = categoriesExistantes.map((c) => c.groupe).toSet().toList()..sort();
    String? groupeSelectionne = groupesExistants.isNotEmpty ? groupesExistants.first : null;
    bool nouveauGroupe = groupesExistants.isEmpty;
    final nouveauGroupeController = TextEditingController();
    final libelleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouvelle catégorie'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!nouveauGroupe && groupesExistants.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: groupeSelectionne,
                        decoration: const InputDecoration(labelText: 'Groupe'),
                        items: groupesExistants.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setDialogState(() => groupeSelectionne = v),
                      ),
                    if (groupesExistants.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(nouveauGroupe ? Icons.list : Icons.add, size: 16),
                        label: Text(nouveauGroupe ? 'Choisir un groupe existant' : 'Créer un nouveau groupe'),
                        onPressed: () => setDialogState(() => nouveauGroupe = !nouveauGroupe),
                      ),
                    if (nouveauGroupe)
                      TextFormField(
                        controller: nouveauGroupeController,
                        decoration: const InputDecoration(labelText: 'Nom du nouveau groupe'),
                        validator: (v) => (nouveauGroupe && (v == null || v.trim().isEmpty))
                            ? 'Indiquez le nom du groupe'
                            : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: libelleController,
                      decoration: const InputDecoration(labelText: 'Libellé de la catégorie'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le libellé' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    final groupe = nouveauGroupe ? nouveauGroupeController.text.trim() : groupeSelectionne!;
                    final ordreMax = categoriesExistantes.isEmpty
                        ? 0
                        : categoriesExistantes.map((c) => c.ordre).reduce((a, b) => a > b ? a : b);
                    try {
                      await CategorieService().ajouterCategorie(
                        groupe: groupe,
                        libelle: libelleController.text.trim(),
                        ordre: ordreMax + 1,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                      }
                    }
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Categorie>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final categories = snapshot.data!;
        final parGroupe = <String, List<Categorie>>{};
        for (final c in categories) {
          parGroupe.putIfAbsent(c.groupe, () => []).add(c);
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: parGroupe.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    ...entry.value.map((c) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.actif ? Colors.white : AppColors.grisLeger,
                          border: Border.all(color: AppColors.bordure),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.libelle,
                                style: TextStyle(
                                  color: c.actif ? Colors.black87 : AppColors.grisTexte,
                                  decoration: c.actif ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            Switch(
                              value: c.actif,
                              activeThumbColor: AppColors.vertPrimaire,
                              onChanged: (v) => CategorieService().basculerActif(c.id, v),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ouvrirDialogueAjout(categories),
            icon: const Icon(Icons.add),
            label: const Text('Catégorie'),
            backgroundColor: AppColors.vertPrimaire,
          ),
        );
      },
    );
  }
}
