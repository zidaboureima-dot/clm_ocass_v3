import 'package:flutter/material.dart';
import '../data/regions_prefectures.dart';
import '../models/categorie_model.dart';
import '../models/signalement_model.dart';
import '../services/categorie_service.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';

class SignalementFormScreen extends StatefulWidget {
  const SignalementFormScreen({super.key});

  @override
  State<SignalementFormScreen> createState() => _SignalementFormScreenState();
}

class _SignalementFormScreenState extends State<SignalementFormScreen> {
  int _etapeActuelle = 0;
  bool _envoiEnCours = false;

  String? _region;
  String? _prefecture;
  final _centreSanteController = TextEditingController();

  Map<String, List<Categorie>>? _categoriesParGroupe;
  bool _chargementCategories = true;
  String? _erreurCategories;
  String? _groupeSelectionne;
  Categorie? _categorieSelectionnee;
  final _autrePreciseController = TextEditingController();

  String _nature = 'normal';
  final _descriptionController = TextEditingController();
  DateTime? _dateIncident;

  final _formKeyEtape1 = GlobalKey<FormState>();
  final _formKeyEtape2 = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  Future<void> _chargerCategories() async {
    try {
      final parGroupe = await CategorieService().obtenirCategoriesParGroupe();
      if (!mounted) return;
      setState(() {
        _categoriesParGroupe = parGroupe;
        _chargementCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurCategories = 'Impossible de charger les catégories : $e';
        _chargementCategories = false;
      });
    }
  }

  bool get _categorieEstAutre =>
      _categorieSelectionnee != null &&
      _categorieSelectionnee!.libelle.toLowerCase().startsWith('autre');

  @override
  void dispose() {
    _centreSanteController.dispose();
    _descriptionController.dispose();
    _autrePreciseController.dispose();
    super.dispose();
  }

  bool _validerEtape1() {
    return _formKeyEtape1.currentState?.validate() == true &&
        _region != null &&
        _prefecture != null;
  }

  bool _validerEtape2() {
    final formValide = _formKeyEtape2.currentState?.validate() == true;
    if (_categorieSelectionnee == null) return false;
    if (_categorieEstAutre && _autrePreciseController.text.trim().isEmpty) return false;
    return formValide;
  }

  Future<void> _soumettre() async {
    setState(() => _envoiEnCours = true);
    try {
      final signalement = Signalement(
        anonyme: true,
        prefecture: _prefecture!,
        centreSante: _centreSanteController.text.trim(),
        region: _region!,
        nature: _nature,
        groupe: _groupeSelectionne!,
        categorieId: _categorieSelectionnee!.id,
        categorieLibelle: _categorieEstAutre
            ? _autrePreciseController.text.trim()
            : _categorieSelectionnee!.libelle,
        description: _descriptionController.text.trim(),
        dateIncident: _dateIncident,
        soumisLe: DateTime.now(),
        statut: 'nouveau',
      );
      await SignalementService().creerSignalement(signalement);
      if (!mounted) return;
      _afficherConfirmation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi : $e')),
      );
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  void _afficherConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.statusTraite, size: 28),
            SizedBox(width: 12),
            Text('Signalement envoyé'),
          ],
        ),
        content: const Text(
          'Merci. Votre signalement a été enregistré de façon anonyme et sera traité par le point focal de la préfecture concernée.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un dysfonctionnement')),
      body: Stepper(
        currentStep: _etapeActuelle,
        onStepContinue: () {
          if (_etapeActuelle == 0) {
            if (_validerEtape1()) setState(() => _etapeActuelle = 1);
          } else if (_etapeActuelle == 1) {
            if (_validerEtape2()) setState(() => _etapeActuelle = 2);
          } else {
            _soumettre();
          }
        },
        onStepCancel: () {
          if (_etapeActuelle > 0) setState(() => _etapeActuelle -= 1);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _envoiEnCours ? null : details.onStepContinue,
                    child: _envoiEnCours
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_etapeActuelle == 2 ? 'Envoyer' : 'Continuer'),
                  ),
                ),
                if (_etapeActuelle > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _envoiEnCours ? null : details.onStepCancel,
                      child: const Text('Retour'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Localisation'),
            isActive: _etapeActuelle >= 0,
            state: _etapeActuelle > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKeyEtape1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _region,
                    decoration: const InputDecoration(labelText: 'Région'),
                    items: RegionsPrefectures.regions
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (valeur) {
                      setState(() {
                        _region = valeur;
                        _prefecture = null;
                      });
                    },
                    validator: (v) => v == null ? 'Sélectionnez une région' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _prefecture,
                    decoration: const InputDecoration(labelText: 'Préfecture / Commune'),
                    items: RegionsPrefectures.prefecturesDe(_region ?? '')
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: _region == null
                        ? null
                        : (valeur) => setState(() => _prefecture = valeur),
                    validator: (v) => v == null ? 'Sélectionnez une préfecture' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _centreSanteController,
                    decoration: const InputDecoration(labelText: 'Centre de santé concerné'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indiquez le centre de santé'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Détails'),
            isActive: _etapeActuelle >= 1,
            state: _etapeActuelle > 1 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKeyEtape2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_chargementCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_erreurCategories != null)
                    Text(_erreurCategories!, style: const TextStyle(color: AppColors.rouge))
                  else ...[
                    const Text('Catégorie du dysfonctionnement', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _groupeSelectionne,
                      decoration: const InputDecoration(labelText: 'Groupe'),
                      items: _categoriesParGroupe!.keys
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (valeur) {
                        setState(() {
                          _groupeSelectionne = valeur;
                          _categorieSelectionnee = null;
                        });
                      },
                      validator: (v) => v == null ? 'Sélectionnez un groupe' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Categorie>(
                      initialValue: _categorieSelectionnee,
                      decoration: const InputDecoration(labelText: 'Catégorie précise'),
                      items: (_categoriesParGroupe![_groupeSelectionne ?? ''] ?? [])
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.libelle)))
                          .toList(),
                      onChanged: _groupeSelectionne == null
                          ? null
                          : (valeur) => setState(() => _categorieSelectionnee = valeur),
                      validator: (v) => v == null ? 'Sélectionnez une catégorie' : null,
                    ),
                    if (_categorieEstAutre) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _autrePreciseController,
                        decoration: const InputDecoration(labelText: 'Précisez la catégorie'),
                        validator: (v) => (_categorieEstAutre && (v == null || v.trim().isEmpty))
                            ? 'Précisez la catégorie'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                  const Text('Nature du signalement', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _ChoixNature(
                        label: 'Normal',
                        valeur: 'normal',
                        couleur: AppColors.bleu,
                        groupe: _nature,
                        onSelect: (v) => setState(() => _nature = v),
                      ),
                      _ChoixNature(
                        label: 'Urgent',
                        valeur: 'urgent',
                        couleur: AppColors.orange,
                        groupe: _nature,
                        onSelect: (v) => setState(() => _nature = v),
                      ),
                      _ChoixNature(
                        label: 'Critique',
                        valeur: 'critique',
                        couleur: AppColors.rouge,
                        groupe: _nature,
                        onSelect: (v) => setState(() => _nature = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description des faits',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Décrivez les faits (10 caractères minimum)'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dateIncident == null
                          ? 'Date des faits (optionnel)'
                          : 'Faits du ${_dateIncident!.day}/${_dateIncident!.month}/${_dateIncident!.year}',
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _dateIncident = date);
                    },
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Récapitulatif'),
            isActive: _etapeActuelle >= 2,
            state: StepState.indexed,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.vertTresClair,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LigneRecap('Région', _region ?? ''),
                  _LigneRecap('Préfecture', _prefecture ?? ''),
                  _LigneRecap('Centre de santé', _centreSanteController.text),
                  _LigneRecap('Groupe', _groupeSelectionne ?? ''),
                  _LigneRecap(
                    'Catégorie',
                    _categorieEstAutre ? _autrePreciseController.text : (_categorieSelectionnee?.libelle ?? ''),
                  ),
                  _LigneRecap('Gravité', _nature),
                  _LigneRecap('Description', _descriptionController.text),
                  const SizedBox(height: 8),
                  const Text(
                    'Ce signalement est anonyme : aucune information permettant de vous identifier n\'est collectée.',
                    style: TextStyle(fontSize: 12, color: AppColors.grisTexte, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  const _ChoixNature({
    required this.label,
    required this.valeur,
    required this.couleur,
    required this.groupe,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selectionne = groupe == valeur;
    return ChoiceChip(
      label: Text(label),
      selected: selectionne,
      onSelected: (_) => onSelect(valeur),
      selectedColor: couleur.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selectionne ? couleur : AppColors.grisTexte,
        fontWeight: selectionne ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: selectionne ? couleur : AppColors.bordure),
    );
  }
}

class _LigneRecap extends StatelessWidget {
  final String label;
  final String valeur;
  const _LigneRecap(this.label, this.valeur);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.grisTexte, fontSize: 14),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.vertFonce)),
            TextSpan(text: valeur),
          ],
        ),
      ),
    );
  }
}
