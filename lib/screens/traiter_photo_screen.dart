import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/regions_prefectures.dart';
import '../models/annotation_model.dart';
import '../models/categorie_model.dart';
import '../models/photo_brute_model.dart';
import '../models/signalement_model.dart';
import '../services/annotation_service.dart';
import '../services/categorie_service.dart';
import '../services/photo_brute_service.dart';
import '../services/photo_service.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';

class TraiterPhotoScreen extends StatefulWidget {
  final PhotoBrute photo;
  final String adminUid;

  const TraiterPhotoScreen({super.key, required this.photo, required this.adminUid});

  @override
  State<TraiterPhotoScreen> createState() => _TraiterPhotoScreenState();
}

class _TraiterPhotoScreenState extends State<TraiterPhotoScreen> {
  String? _urlSignee;
  bool _chargementImage = true;

  final _formKey = GlobalKey<FormState>();
  String? _region;
  String? _prefecture;
  final _centreSanteController = TextEditingController();

  Map<String, List<Categorie>>? _categoriesParGroupe;
  bool _chargementCategories = true;
  String? _groupeSelectionne;
  Categorie? _categorieSelectionnee;
  final _autrePreciseController = TextEditingController();

  String _nature = 'normal';
  final _descriptionController = TextEditingController();

  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerImage();
    _chargerCategories();
  }

  Future<void> _chargerImage() async {
    try {
      final url = await PhotoBruteService().obtenirUrlSignee(widget.photo.cheminStockage);
      if (!mounted) return;
      setState(() {
        _urlSignee = url;
        _chargementImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementImage = false);
    }
  }

  Future<void> _chargerCategories() async {
    final parGroupe = await CategorieService().obtenirCategoriesParGroupe();
    if (!mounted) return;
    setState(() {
      _categoriesParGroupe = parGroupe;
      _chargementCategories = false;
    });
  }

  bool get _categorieEstAutre =>
      _categorieSelectionnee != null && _categorieSelectionnee!.libelle.toLowerCase().startsWith('autre');

  @override
  void dispose() {
    _centreSanteController.dispose();
    _autrePreciseController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _creerSignalement() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_categorieSelectionnee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez une catégorie')));
      return;
    }
    setState(() => _envoiEnCours = true);
    try {
      final idSignalement = const Uuid().v4();
      final signalement = Signalement(
        id: idSignalement,
        anonyme: true,
        prefecture: _prefecture!,
        centreSante: _centreSanteController.text.trim(),
        region: _region!,
        nature: _nature,
        groupe: _groupeSelectionne!,
        categorieId: _categorieSelectionnee!.id,
        categorieLibelle: _categorieEstAutre ? _autrePreciseController.text.trim() : _categorieSelectionnee!.libelle,
        description: _descriptionController.text.trim(),
        soumisLe: widget.photo.createdAt,
        statut: 'nouveau',
      );
      await SignalementService().creerSignalement(signalement);
      await PhotoService().lierPhotoExistante(
        signalementId: idSignalement,
        cheminStockage: widget.photo.cheminStockage,
      );
      await AnnotationService().ajouterAnnotation(
        Annotation(
          signalementId: idSignalement,
          auteurUid: widget.adminUid,
          roleAuteur: 'admin',
          contenu: 'Signalement créé par l\'administration à partir d\'une photo directe reçue de l\'usager.',
          createdAt: DateTime.now(),
        ),
      );
      await PhotoBruteService().marquerTraitee(photoId: widget.photo.id, signalementId: idSignalement);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement créé et transmis au superviseur de la région.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traiter la photo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_chargementImage)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_urlSignee != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_urlSignee!, height: 240, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 20),
            const Text('En observant la photo, remplissez les champs ci-dessous :', style: TextStyle(fontSize: 12, color: AppColors.grisTexte)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _region,
              decoration: const InputDecoration(labelText: 'Région'),
              items: RegionsPrefectures.regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() {
                _region = v;
                _prefecture = null;
              }),
              validator: (v) => v == null ? 'Sélectionnez une région' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _prefecture,
              decoration: const InputDecoration(labelText: 'Préfecture / Commune'),
              items: RegionsPrefectures.prefecturesDe(_region ?? '').map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: _region == null ? null : (v) => setState(() => _prefecture = v),
              validator: (v) => v == null ? 'Sélectionnez une préfecture' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _centreSanteController,
              decoration: const InputDecoration(labelText: 'Centre de santé concerné'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le centre de santé' : null,
            ),
            const SizedBox(height: 20),
            if (_chargementCategories)
              const LinearProgressIndicator()
            else ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _groupeSelectionne,
                decoration: const InputDecoration(labelText: 'Groupe'),
                items: _categoriesParGroupe!.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() {
                  _groupeSelectionne = v;
                  _categorieSelectionnee = null;
                }),
                validator: (v) => v == null ? 'Sélectionnez un groupe' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Categorie>(
                isExpanded: true,
                initialValue: _categorieSelectionnee,
                decoration: const InputDecoration(labelText: 'Catégorie précise'),
                items: (_categoriesParGroupe![_groupeSelectionne ?? ''] ?? [])
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.libelle)))
                    .toList(),
                onChanged: _groupeSelectionne == null ? null : (v) => setState(() => _categorieSelectionnee = v),
                validator: (v) => v == null ? 'Sélectionnez une catégorie' : null,
              ),
              if (_categorieEstAutre) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _autrePreciseController,
                  decoration: const InputDecoration(labelText: 'Précisez la catégorie'),
                  validator: (v) => (_categorieEstAutre && (v == null || v.trim().isEmpty)) ? 'Précisez la catégorie' : null,
                ),
              ],
            ],
            const SizedBox(height: 20),
            const Text('Gravité', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChoixNature(label: 'Normal', valeur: 'normal', couleur: AppColors.bleu, groupe: _nature, onSelect: (v) => setState(() => _nature = v)),
                _ChoixNature(label: 'Urgent', valeur: 'urgent', couleur: AppColors.orange, groupe: _nature, onSelect: (v) => setState(() => _nature = v)),
                _ChoixNature(label: 'Critique', valeur: 'critique', couleur: AppColors.rouge, groupe: _nature, onSelect: (v) => setState(() => _nature = v)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description des faits (à partir de la photo)', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Décrivez les faits (10 caractères minimum)' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _envoiEnCours ? null : _creerSignalement,
              icon: _envoiEnCours
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_envoiEnCours ? 'Création…' : 'Créer le signalement'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoixNature extends StatelessWidget {
  final String label;
  final String valeur;
  final Color couleur;
  final String groupe;
  final ValueChanged<String> onSelect;

  const _ChoixNature({required this.label, required this.valeur, required this.couleur, required this.groupe, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final selectionne = groupe == valeur;
    return ChoiceChip(
      label: Text(label),
      selected: selectionne,
      onSelected: (_) => onSelect(valeur),
      selectedColor: couleur.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: selectionne ? couleur : AppColors.grisTexte, fontWeight: selectionne ? FontWeight.bold : FontWeight.normal),
      side: BorderSide(color: selectionne ? couleur : AppColors.bordure),
    );
  }
}
