import 'package:flutter/material.dart';

import '../models/referentiel_model.dart';
import '../services/referentiel_service.dart';
import '../theme/app_colors.dart';
import '../widgets/etat_erreur.dart';

/// Administration du référentiel des formations sanitaires.
///
/// POURQUOI CET ÉCRAN PASSE AVANT LA BASCULE DES LISTES DÉROULANTES
///   Un référentiel à zéro établissement ne sert à rien. C'est cet écran qui
///   le remplit — à la main, ou par import d'une liste. Basculer d'abord le
///   formulaire citoyen sur la base aurait déplacé les mêmes dix régions du
///   code vers une table, sans rien gagner de visible.
///
/// LES DEUX VUES, ET POURQUOI ELLES SONT ENSEMBLE
///   « Établissements » est le référentiel lui-même. « À rapprocher » est la
///   liste des graphies saisies par les citoyens qui ne correspondent à
///   aucun établissement connu.
///
///   Elles tiennent dans un seul onglet parce qu'on passe constamment de
///   l'une à l'autre : rapprocher une graphie suppose souvent de créer
///   d'abord l'établissement qui manque. Les séparer imposerait un
///   aller-retour entre deux onglets pour un seul geste.
///
/// L'IMPORT SE FAIT PAR COLLAGE, PAS PAR SÉLECTION DE FICHIER
///   Choisir un fichier demanderait une dépendance native nouvelle, donc un
///   `pub get` et une recompilation, pour une fonction employée quelques
///   fois par an. Le collage ne coûte rien et fonctionne partout — la liste
///   arrive de toute façon par courriel ou par messagerie. Si l'usage montre
///   que c'est pénible, le sélecteur de fichier reste une évolution simple.
class AdminReferentielTab extends StatefulWidget {
  const AdminReferentielTab({super.key});

  @override
  State<AdminReferentielTab> createState() => _AdminReferentielTabState();
}

class _AdminReferentielTabState extends State<AdminReferentielTab> {
  final _service = ReferentielService();

  int _vue = 0; // 0 = établissements, 1 = à rapprocher

  List<RegionRef> _regions = const [];
  List<PrefectureRef> _prefectures = const [];
  String? _regionId;
  String? _prefectureId;

  late Future<List<FormationSanitaire>> _futureFormations;
  late Future<List<RapprochementEnAttente>> _futureRapprochements;

  @override
  void initState() {
    super.initState();
    _futureFormations = _service.obtenirFormations();
    _futureRapprochements = _service.obtenirRapprochementsEnAttente();
    _chargerRegions();
  }

  Future<void> _chargerRegions() async {
    final regions = await _service.obtenirRegions();
    if (!mounted) return;
    setState(() => _regions = regions);
  }

  Future<void> _choisirRegion(String? id) async {
    setState(() {
      _regionId = id;
      _prefectureId = null;
      _prefectures = const [];
    });
    if (id != null) {
      final p = await _service.obtenirPrefectures(id);
      if (!mounted) return;
      setState(() => _prefectures = p);
    }
    _rechargerFormations();
  }

  void _rechargerFormations() {
    setState(() {
      _futureFormations = _service.obtenirFormations(
        regionId: _prefectureId == null ? _regionId : null,
        prefectureId: _prefectureId,
      );
    });
  }

  void _rechargerRapprochements() {
    setState(() {
      _futureRapprochements = _service.obtenirRapprochementsEnAttente();
    });
  }

  void _annoncer(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.rouge : null,
      ),
    );
  }

  // ===================================================================
  // Création et modification d'un établissement
  // ===================================================================

  Future<void> _ouvrirFormulaire({FormationSanitaire? existant}) async {
    final nomCtrl = TextEditingController(text: existant?.nom ?? '');
    final typeCtrl = TextEditingController(text: existant?.typeEtablissement ?? '');
    final codeCtrl = TextEditingController(text: existant?.code ?? '');
    final cleFormulaire = GlobalKey<FormState>();

    // Le formulaire porte ses propres listes : l'établissement en cours de
    // modification peut relever d'une autre région que celle filtrée à
    // l'écran, et on doit pouvoir l'y déplacer.
    var regionId = _regionId;
    var prefectureId = existant?.prefectureId ?? _prefectureId;
    var prefecturesFormulaire = _prefectures;

    if (existant != null) {
      regionId = _regionNommee(existant.regionNom)?.id;
      if (regionId != null) {
        prefecturesFormulaire = await _service.obtenirPrefectures(regionId);
      }
    }

    // Un DropdownButtonFormField à qui l'on passe une valeur absente de ses
    // éléments lève une assertion et fait tomber l'écran. Le cas se produit
    // quand la région de l'établissement n'a pas pu être retrouvée — base
    // injoignable, ou région désactivée depuis. On préfère un champ vide à
    // redonner qu'un écran qui tombe.
    if (regionId != null && !_regions.any((r) => r.id == regionId)) {
      regionId = null;
      prefecturesFormulaire = const [];
    }
    if (prefectureId != null &&
        !prefecturesFormulaire.any((p) => p.id == prefectureId)) {
      prefectureId = null;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (contexteDialogue, majDialogue) => AlertDialog(
          title: Text(existant == null
              ? 'Nouvel établissement'
              : 'Modifier l\'établissement'),
          content: SingleChildScrollView(
            child: Form(
              key: cleFormulaire,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: regionId,
                    decoration: const InputDecoration(labelText: 'Région'),
                    items: _regions
                        .map((r) => DropdownMenuItem(value: r.id, child: Text(r.nom)))
                        .toList(),
                    validator: (v) => v == null ? 'Choisissez une région' : null,
                    onChanged: (v) async {
                      final liste = v == null
                          ? <PrefectureRef>[]
                          : await _service.obtenirPrefectures(v);
                      majDialogue(() {
                        regionId = v;
                        prefectureId = null;
                        prefecturesFormulaire = liste;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: prefectureId,
                    decoration: const InputDecoration(labelText: 'Préfecture'),
                    items: prefecturesFormulaire
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nom)))
                        .toList(),
                    validator: (v) => v == null ? 'Choisissez une préfecture' : null,
                    onChanged: (v) => majDialogue(() => prefectureId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'établissement',
                      hintText: 'CHU Donka',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indiquez le nom'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type (facultatif)',
                      hintText: 'Centre de santé, hôpital préfectoral…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code national (facultatif)',
                      helperText: 'Identifiant DHIS2, s\'il est connu',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (!cleFormulaire.currentState!.validate()) return;

                // Les identifiants de secours viennent de la liste codée en
                // dur, employée quand la base est injoignable. Les écrire
                // créerait un établissement rattaché à une préfecture
                // inexistante.
                if (ReferentielService.estIdDeSecours(prefectureId!)) {
                  Navigator.of(contexteDialogue).pop();
                  _annoncer(
                    'Référentiel non chargé depuis le serveur. '
                    'Vérifiez la connexion avant de créer un établissement.',
                    erreur: true,
                  );
                  return;
                }

                try {
                  if (existant == null) {
                    await _service.creerFormation(
                      prefectureId: prefectureId!,
                      nom: nomCtrl.text.trim(),
                      code: codeCtrl.text.trim(),
                      typeEtablissement: typeCtrl.text.trim(),
                    );
                  } else {
                    await _service.modifierFormation(
                      id: existant.id,
                      nom: nomCtrl.text.trim(),
                      code: codeCtrl.text.trim(),
                      typeEtablissement: typeCtrl.text.trim(),
                      prefectureId: prefectureId,
                    );
                  }
                  if (contexteDialogue.mounted) {
                    Navigator.of(contexteDialogue).pop();
                  }
                  _annoncer(existant == null
                      ? 'Établissement créé.'
                      : 'Établissement modifié.');
                  _rechargerFormations();
                  // Un nouvel établissement devient alias de son propre nom :
                  // des graphies en attente peuvent donc s'être résolues.
                  _rechargerRapprochements();
                } catch (e) {
                  _annoncer(_sansPrefixe(e), erreur: true);
                }
              },
              child: Text(existant == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  static String _sansPrefixe(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  /// Région du référentiel portant ce nom, ou null.
  ///
  /// Écrit en boucle et non avec `firstOrNull` : cette extension vient de
  /// `package:collection`, qui n'est pas une dépendance du projet.
  RegionRef? _regionNommee(String? nom) {
    if (nom == null) return null;
    for (final r in _regions) {
      if (r.nom == nom) return r;
    }
    return null;
  }

  // ===================================================================
  // Import d'une liste
  // ===================================================================

  Future<void> _ouvrirImport() async {
    final texteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        title: const Text('Importer une liste'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Une ligne par établissement, champs séparés par des '
                'points-virgules :',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.grisLeger,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'région ; préfecture ; nom ; type ; code',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Le type et le code sont facultatifs. Une première ligne '
                'd\'en-têtes est ignorée.',
                style: TextStyle(fontSize: 12, color: AppColors.grisTexte),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: texteCtrl,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Conakry ; Dixinn ; CHU Donka ; Hôpital national',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final lignes = _decouper(texteCtrl.text);
              if (lignes.isEmpty) {
                _annoncer('Aucune ligne exploitable.', erreur: true);
                return;
              }
              Navigator.of(contexteDialogue).pop();
              await _lancerImport(lignes);
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  /// Découpe le texte collé. Accepte le point-virgule, la tabulation et la
  /// virgule — un même tableur produit l'un ou l'autre selon la machine, et
  /// imposer un seul séparateur ferait échouer l'import sans raison
  /// compréhensible pour l'administrateur.
  static List<LigneImport> _decouper(String texte) {
    final resultat = <LigneImport>[];
    final lignes = texte.split('\n');

    for (var i = 0; i < lignes.length; i++) {
      final brute = lignes[i].trim();
      if (brute.isEmpty) continue;

      final separateur = brute.contains(';')
          ? ';'
          : brute.contains('\t')
              ? '\t'
              : ',';
      final champs = brute.split(separateur).map((c) => c.trim()).toList();
      if (champs.length < 3) continue;

      // En-tête : reconnue sur le premier champ, et seulement sur la
      // première ligne non vide.
      if (resultat.isEmpty && champs[0].toLowerCase().startsWith('r')
          && champs[1].toLowerCase().startsWith('pr')) {
        continue;
      }

      resultat.add(LigneImport(
        numeroLigne: i + 1,
        region: champs[0],
        prefecture: champs[1],
        nom: champs[2],
        type: champs.length > 3 && champs[3].isNotEmpty ? champs[3] : null,
        code: champs.length > 4 && champs[4].isNotEmpty ? champs[4] : null,
      ));
    }
    return resultat;
  }

  Future<void> _lancerImport(List<LigneImport> lignes) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Import en cours…')),
          ],
        ),
      ),
    );

    ResultatImport resultat;
    try {
      resultat = await _service.importerFormations(lignes);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _annoncer(_sansPrefixe(e), erreur: true);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    _rechargerFormations();
    _rechargerRapprochements();
    await _montrerCompteRendu(resultat);
  }

  /// Compte rendu ligne à ligne.
  ///
  /// Un import qui annoncerait « 130 lignes importées » alors que douze ont
  /// été écartées laisserait douze établissements hors du référentiel, donc
  /// douze sites hors de la mesure, sans que personne ne le sache.
  Future<void> _montrerCompteRendu(ResultatImport r) async {
    await showDialog<void>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        title: const Text('Import terminé'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.crees} établissement(s) créé(s).'),
              Text('${r.misAJour} mis à jour.'),
              if (r.rejets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${r.rejets.length} ligne(s) écartée(s) :',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.rouge),
                ),
                const SizedBox(height: 6),
                ...r.rejets.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(m, style: const TextStyle(fontSize: 13)),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // Rapprochement d'une graphie
  // ===================================================================

  Future<void> _ouvrirRapprochement(RapprochementEnAttente attente) async {
    // On propose d'abord les établissements de la région déclarée sur le
    // signalement, sans s'y enfermer : on peut signaler un hôpital de
    // Conakry depuis ailleurs, et la préfecture saisie est parfois erronée.
    final region = _regionNommee(attente.region);

    // Initialisée à vide, et non simplement déclarée : l'analyse
    // d'assignation définie de Dart ne considère pas qu'une affectation faite
    // dans un bloc `try` a forcément eu lieu après celui-ci. Le piège a déjà
    // été rencontré dans signalement_service.dart.
    var candidats = const <FormationSanitaire>[];
    var toutesRegions = false;

    try {
      candidats = await _service.obtenirFormations(
        regionId: region?.id,
        seulementActifs: true,
      );
      // Aucun établissement dans la région déclarée : on élargit plutôt que
      // de conclure que le référentiel est vide.
      if (candidats.isEmpty) {
        toutesRegions = true;
        candidats = await _service.obtenirFormations(seulementActifs: true);
      }
    } catch (e) {
      _annoncer(_sansPrefixe(e), erreur: true);
      return;
    }

    if (!mounted) return;

    if (candidats.isEmpty) {
      _annoncer(
        'Aucun établissement au référentiel. Créez-en un d\'abord.',
        erreur: true,
      );
      return;
    }

    String? choix;

    await showDialog<void>(
      context: context,
      builder: (contexteDialogue) => StatefulBuilder(
        builder: (contexteDialogue, majDialogue) => AlertDialog(
          title: const Text('Rapprocher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '« ${attente.exempleSaisi} »',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${attente.region} · ${attente.prefecture} · '
                  '${attente.occurrences} signalement(s)',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.grisTexte),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: choix,
                  decoration: const InputDecoration(
                    labelText: 'Établissement du référentiel',
                  ),
                  items: candidats
                      .map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              f.prefectureNom == null
                                  ? f.nom
                                  : '${f.nom} — ${f.prefectureNom}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => majDialogue(() => choix = v),
                ),
                if (!toutesRegions) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.public, size: 16),
                    label: const Text('Chercher dans toutes les régions'),
                    onPressed: () async {
                      try {
                        final tous = await _service.obtenirFormations(
                            seulementActifs: true);
                        majDialogue(() {
                          candidats = tous;
                          toutesRegions = true;
                          choix = null;
                        });
                      } catch (e) {
                        _annoncer(_sansPrefixe(e), erreur: true);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Cette graphie sera rattachée définitivement : les '
                  'signalements déjà déposés sont repris, et toute saisie '
                  'ultérieure se rattache d\'elle-même.',
                  style: TextStyle(fontSize: 12, color: AppColors.grisTexte),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: choix == null
                  ? null
                  : () async {
                      try {
                        final repris = await _service.rapprocher(
                          libelle: attente.exempleSaisi,
                          formationId: choix!,
                        );
                        if (contexteDialogue.mounted) {
                          Navigator.of(contexteDialogue).pop();
                        }
                        _annoncer('$repris signalement(s) rattaché(s).');
                        _rechargerRapprochements();
                        _rechargerFormations();
                      } catch (e) {
                        _annoncer(_sansPrefixe(e), erreur: true);
                      }
                    },
              child: const Text('Rapprocher'),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // Construction
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _barreDeVues(),
          Expanded(
            child: _vue == 0 ? _vueEtablissements() : _vueRapprochements(),
          ),
        ],
      ),
      floatingActionButton: _vue != 0
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'import',
                  onPressed: _ouvrirImport,
                  backgroundColor: AppColors.vertFonce,
                  tooltip: 'Importer une liste',
                  child: const Icon(Icons.upload_file),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'ajout',
                  onPressed: () => _ouvrirFormulaire(),
                  icon: const Icon(Icons.add),
                  label: const Text('Établissement'),
                  backgroundColor: AppColors.vertPrimaire,
                ),
              ],
            ),
    );
  }

  Widget _barreDeVues() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<int>(
              segments: [
                const ButtonSegment(value: 0, label: Text('Établissements')),
                ButtonSegment(
                  value: 1,
                  label: FutureBuilder<List<RapprochementEnAttente>>(
                    future: _futureRapprochements,
                    builder: (context, snapshot) {
                      final n = snapshot.data?.length;
                      return Text(n == null || n == 0
                          ? 'À rapprocher'
                          : 'À rapprocher ($n)');
                    },
                  ),
                ),
              ],
              selected: {_vue},
              onSelectionChanged: (s) => setState(() => _vue = s.first),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vueEtablissements() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _regionId,
                  decoration: const InputDecoration(
                    labelText: 'Région',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes')),
                    ..._regions.map(
                        (r) => DropdownMenuItem(value: r.id, child: Text(r.nom))),
                  ],
                  onChanged: _choisirRegion,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _prefectureId,
                  decoration: const InputDecoration(
                    labelText: 'Préfecture',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes')),
                    ..._prefectures.map(
                        (p) => DropdownMenuItem(value: p.id, child: Text(p.nom))),
                  ],
                  onChanged: _prefectures.isEmpty
                      ? null
                      : (v) {
                          setState(() => _prefectureId = v);
                          _rechargerFormations();
                        },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FormationSanitaire>>(
            future: _futureFormations,
            builder: (context, snapshot) {
              // L'erreur se teste AVANT hasData : en erreur, hasData est
              // faux, donc l'ordre inverse rendrait cette branche
              // inatteignable.
              if (snapshot.hasError) {
                return EtatErreur(
                  message: 'Le référentiel n\'a pas pu être chargé.',
                  onReessayer: _rechargerFormations,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final formations = snapshot.data!;
              if (formations.isEmpty) {
                return _vide(
                  icone: Icons.local_hospital_outlined,
                  titre: 'Aucun établissement',
                  detail: _regionId == null
                      ? 'Importez la liste des formations sanitaires, ou '
                          'créez-en une à la main.'
                      : 'Aucun établissement dans cette zone.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: formations.length,
                itemBuilder: (context, i) => _carteFormation(formations[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _carteFormation(FormationSanitaire f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: f.actif ? Colors.white : AppColors.grisLeger,
        border: Border.all(color: AppColors.bordure),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.nom,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: f.actif ? Colors.black87 : AppColors.grisTexte,
                    decoration: f.actif ? null : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  [
                    if (f.regionNom != null) f.regionNom!,
                    if (f.prefectureNom != null) f.prefectureNom!,
                    if (f.typeEtablissement != null) f.typeEtablissement!,
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grisTexte),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Modifier',
            onPressed: () => _ouvrirFormulaire(existant: f),
          ),
          // Désactivation et non suppression : supprimer emporterait le
          // rattachement des signalements historiques.
          Switch(
            value: f.actif,
            activeThumbColor: AppColors.vertPrimaire,
            onChanged: (v) async {
              try {
                await _service.modifierFormation(id: f.id, actif: v);
                _rechargerFormations();
              } catch (e) {
                _annoncer(_sansPrefixe(e), erreur: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _vueRapprochements() {
    return FutureBuilder<List<RapprochementEnAttente>>(
      future: _futureRapprochements,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EtatErreur(
            message: 'La liste des rapprochements n\'a pas pu être chargée.',
            onReessayer: _rechargerRapprochements,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final attentes = snapshot.data!;
        if (attentes.isEmpty) {
          return _vide(
            icone: Icons.task_alt,
            titre: 'Rien à rapprocher',
            detail: 'Tous les centres de santé saisis sont rattachés à un '
                'établissement du référentiel.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: attentes.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Graphies saisies par les citoyens qui ne correspondent à '
                  'aucun établissement connu. Les rattacher une fois suffit : '
                  'les saisies suivantes se rattachent d\'elles-mêmes.',
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: AppColors.grisTexte),
                ),
              );
            }

            final a = attentes[i - 1];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.bordure),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.exempleSaisi,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${a.region} · ${a.prefecture}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.grisTexte),
                        ),
                      ],
                    ),
                  ),
                  if (a.occurrences > 1)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.vertClair,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${a.occurrences}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.vertFonce,
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () => _ouvrirRapprochement(a),
                    child: const Text('Rapprocher'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _vide({
    required IconData icone,
    required String titre,
    required String detail,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 44, color: AppColors.grisTexte),
            const SizedBox(height: 16),
            Text(titre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.grisTexte)),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.grisTexte),
            ),
          ],
        ),
      ),
    );
  }
}
