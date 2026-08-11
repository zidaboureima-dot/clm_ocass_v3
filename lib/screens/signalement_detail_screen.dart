import 'package:flutter/material.dart';
import '../models/annotation_model.dart';
import '../models/signalement_model.dart';
import '../models/user_profile_model.dart';
import '../services/annotation_service.dart';
import '../services/photo_service.dart';
import '../services/signalement_service.dart';
import '../services/user_service.dart';
import '../widgets/contacts_chaine_widget.dart';
import '../theme/app_colors.dart';

class SignalementDetailScreen extends StatefulWidget {
  final Signalement signalement;
  final UserProfile profil;

  final bool peutAssigner;

  const SignalementDetailScreen({
    super.key,
    required this.signalement,
    required this.profil,
    this.peutAssigner = false,
  });

  @override
  State<SignalementDetailScreen> createState() => _SignalementDetailScreenState();
}

class _SignalementDetailScreenState extends State<SignalementDetailScreen> {
  final _annotationController = TextEditingController();
  bool _envoiAnnotationEnCours = false;

  late String _statutActuel;
  bool _majStatutEnCours = false;

  List<UserProfile>? _pointsFocaux;
  bool _chargementFocaux = false;
  String? _focalSelectionneUid;
  bool _assignationEnCours = false;

  bool _chargementPhoto = true;
  String? _urlPhoto;

  static const _statuts = ['nouveau', 'en_cours', 'traite', 'cloture'];
  static const _libellesStatuts = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'traite': 'Traité',
    'cloture': 'Clôturé',
  };

  @override
  void initState() {
    super.initState();
    _statutActuel = widget.signalement.statut;
    if (widget.peutAssigner) _chargerPointsFocaux();
    _chargerPhoto();
  }

  Future<void> _chargerPhoto() async {
    final photo = await PhotoService().obtenirPhotoPourSignalement(widget.signalement.id!);
    if (photo == null) {
      if (!mounted) return;
      setState(() => _chargementPhoto = false);
      return;
    }
    final url = await PhotoService().obtenirUrlSignee(photo.cheminStockage);
    if (!mounted) return;
    setState(() {
      _urlPhoto = url;
      _chargementPhoto = false;
    });
  }

  @override
  void dispose() {
    _annotationController.dispose();
    super.dispose();
  }

  Future<void> _chargerPointsFocaux() async {
    setState(() => _chargementFocaux = true);
    try {
      final focaux = await UserService().obtenirPointsFocauxParPrefecture(widget.signalement.prefecture);
      if (!mounted) return;
      setState(() {
        _pointsFocaux = focaux;
        _focalSelectionneUid = widget.signalement.assigneeUid;
        _chargementFocaux = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementFocaux = false);
    }
  }

  Future<void> _envoyerAnnotation() async {
    final texte = _annotationController.text.trim();
    if (texte.isEmpty) return;
    setState(() => _envoiAnnotationEnCours = true);
    try {
      await AnnotationService().ajouterAnnotation(
        Annotation(
          signalementId: widget.signalement.id!,
          auteurUid: widget.profil.id,
          roleAuteur: widget.profil.role,
          contenu: texte,
          createdAt: DateTime.now(),
        ),
      );
      _annotationController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _envoiAnnotationEnCours = false);
    }
  }

  Future<void> _changerStatut(String nouveauStatut) async {
    setState(() => _majStatutEnCours = true);
    try {
      await SignalementService().mettreAJourStatut(widget.signalement.id!, nouveauStatut);
      if (!mounted) return;
      setState(() => _statutActuel = nouveauStatut);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : ${_libellesStatuts[nouveauStatut]}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _majStatutEnCours = false);
    }
  }

  Future<void> _assigner() async {
    if (_focalSelectionneUid == null) return;
    setState(() => _assignationEnCours = true);
    try {
      await SignalementService().assignerPointFocal(
        signalementId: widget.signalement.id!,
        pointFocalUid: _focalSelectionneUid!,
        superviseurUid: widget.profil.id,
        statutActuel: _statutActuel,
      );
      if (!mounted) return;
      if (_statutActuel == 'nouveau') setState(() => _statutActuel = 'en_cours');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement assigné')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _assignationEnCours = false);
    }
  }

  Color _couleurNature(String nature) {
    switch (nature) {
      case 'urgent':
        return AppColors.orange;
      case 'critique':
        return AppColors.rouge;
      default:
        return AppColors.bleu;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.signalement;
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du signalement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.vertTresClair,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _couleurNature(s.nature).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.nature.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _couleurNature(s.nature)),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${s.soumisLe.day}/${s.soumisLe.month}/${s.soumisLe.year}',
                      style: const TextStyle(fontSize: 12, color: AppColors.grisTexte),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${s.region} — ${s.prefecture}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
                const SizedBox(height: 2),
                Text(s.centreSante, style: const TextStyle(color: AppColors.grisTexte)),
                const SizedBox(height: 10),
                Text('${s.groupe} · ${s.categorieLibelle}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(s.description, style: const TextStyle(height: 1.5)),
                if (_chargementPhoto)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  )
                else if (_urlPhoto != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: const Text('Photo')),
                            backgroundColor: Colors.black,
                            body: Center(
                              child: InteractiveViewer(
                                child: Image.network(_urlPhoto!),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(_urlPhoto!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _statuts.map((statut) {
              final selectionne = statut == _statutActuel;
              return ChoiceChip(
                label: Text(_libellesStatuts[statut]!),
                selected: selectionne,
                onSelected: _majStatutEnCours ? null : (_) => _changerStatut(statut),
              );
            }).toList(),
          ),
          if (widget.peutAssigner) ...[
            const SizedBox(height: 20),
            const Text('Assigner à un point focal', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
            const SizedBox(height: 8),
            if (_chargementFocaux)
              const LinearProgressIndicator()
            else if (_pointsFocaux == null || _pointsFocaux!.isEmpty)
              const Text(
                'Aucun point focal actif pour cette préfecture. Vous pouvez traiter ce signalement vous-même : ajustez le statut et ajoutez vos annotations ci-dessous.',
                style: TextStyle(color: AppColors.grisTexte, fontSize: 13, height: 1.4),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _focalSelectionneUid,
                decoration: const InputDecoration(labelText: 'Point focal'),
                items: _pointsFocaux!
                    .map((f) => DropdownMenuItem(value: f.id, child: Text(f.nom)))
                    .toList(),
                onChanged: (v) => setState(() => _focalSelectionneUid = v),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _assignationEnCours ? null : _assigner,
                child: _assignationEnCours
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Assigner'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const Text('Contacter les acteurs du cas', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
          const SizedBox(height: 8),
          ContactsChaineWidget(signalement: s, profil: widget.profil),
          const SizedBox(height: 24),
          const Text('Annotations', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
          const SizedBox(height: 8),
          StreamBuilder<List<Annotation>>(
            stream: AnnotationService().streamAnnotations(s.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final annotations = snapshot.data!;
              if (annotations.isEmpty) {
                return const Text('Aucune annotation pour le moment.', style: TextStyle(color: AppColors.grisTexte, fontSize: 13));
              }
              return Column(
                children: annotations.map((a) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.grisLeger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              a.roleAuteur,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
                            ),
                            const Spacer(),
                            Text(
                              '${a.createdAt.day}/${a.createdAt.month} ${a.createdAt.hour}:${a.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: AppColors.grisTexte),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(a.contenu, style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _annotationController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Ajouter une annotation'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _envoiAnnotationEnCours ? null : _envoyerAnnotation,
                icon: _envoiAnnotationEnCours
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}