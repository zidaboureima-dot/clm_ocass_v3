import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import '../data/regions_prefectures.dart';
import '../models/categorie_model.dart';
import '../models/message_vocal_brut_model.dart';
import '../models/signalement_model.dart';
import '../services/annotation_service.dart';
import '../models/annotation_model.dart';
import '../services/categorie_service.dart';
import '../services/message_vocal_service.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';

class TraiterMessageVocalScreen extends StatefulWidget {
  final MessageVocalBrut message;
  final String adminUid;

  const TraiterMessageVocalScreen({super.key, required this.message, required this.adminUid});

  @override
  State<TraiterMessageVocalScreen> createState() => _TraiterMessageVocalScreenState();
}

class _TraiterMessageVocalScreenState extends State<TraiterMessageVocalScreen> {
  final _player = AudioPlayer();
  bool _lectureEnCours = false;
  bool _chargementLecture = false;

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
    _chargerCategories();
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
    _player.dispose();
    _centreSanteController.dispose();
    _autrePreciseController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _ecouter() async {
    setState(() => _chargementLecture = true);
    try {
      final url = await MessageVocalService().obtenirUrlSignee(widget.message.cheminStockage);
      setState(() {
        _chargementLecture = false;
        _lectureEnCours = true;
      });
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _lectureEnCours = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementLecture = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lecture : $e')));
    }
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
        soumisLe: widget.message.createdAt,
        statut: 'nouveau',
      );
      await SignalementService().creerSignalement(signalement);
      await AnnotationService().ajouterAnnotation(
        Annotation(
          signalementId: idSignalement,
          auteurUid: widget.adminUid,
          roleAuteur: 'admin',
          contenu: 'Signalement créé par l\'administration à partir d\'un message vocal direct reçu de l\'usager.',
          createdAt: DateTime.now(),
        ),
      );
      // Confidentialité (Modèle A) : suppression de l'audio brut au moment
      // de la transcription. Le fichier est détruit du stockage et le
      // message est marqué traité. Aucun audio n'est conservé ni lié au
      // signalement, il n'est pas réécoutable par le superviseur.
      await MessageVocalService().marquerTraite(
        messageId: widget.message.id,
        signalementId: idSignalement,
        cheminStockage: widget.message.cheminStockage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement créé et transmis au superviseur. Enregistrement audio supprimé.')),
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
      appBar: AppBar(title: const Text('Traiter le message vocal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: (_chargementLecture || _lectureEnCours) ? null : _ecouter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.vertTresClair,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.vertPrimaire),
                ),
                child: Row(
                  children: [
                    _chargementLecture
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_lectureAudioIcone(), color: AppColors.vertPrimaire, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      _lectureEnCours ? 'Lecture en cours…' : 'Écouter le message (${widget.message.dureeSecondes ?? 0} s)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertPrimaire),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('En écoutant le message, remplissez les champs ci-dessous :', style: TextStyle(fontSize: 12, color: AppColors.grisTexte)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
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
              decoration: const InputDecoration(labelText: 'Résumé écrit du message (transcription/synthèse)', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Résumez le message (10 caractères minimum)' : null,
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

  IconData _lectureAudioIcone() => _lectureEnCours ? Icons.volume_up : Icons.play_circle_fill;
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
