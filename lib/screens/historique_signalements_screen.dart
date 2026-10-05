import 'package:flutter/material.dart';
import '../models/signalement_model.dart';
import '../models/user_profile_model.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';
import '../widgets/etat_erreur.dart';
import 'signalement_detail_screen.dart';

/// Historique exhaustif des signalements, paginé et filtré côté serveur.
///
/// POURQUOI CET ÉCRAN EXISTE
///   Les tableaux de bord ouvrent un flux temps réel BORNÉ aux
///   `limiteFluxTempsReel` signalements les plus récents, et leurs filtres de
///   statut s'appliquent côté client — donc à l'intérieur de cette fenêtre.
///   Chercher les cas clôturés depuis un tableau de bord ne renvoie que ceux
///   qui figurent parmi les plus récents.
///
///   Cet écran est l'autre moitié du dispositif : requête ordinaire, tous les
///   filtres appliqués par le serveur, une page à la fois. Pas de temps réel —
///   l'historique se consulte, il n'a pas besoin de bouger sous les yeux.
///
/// LE PÉRIMÈTRE N'EST PAS DÉFINI ICI
///   Les filtres passés au service suivent le rôle, mais ils servent le confort
///   de lecture, pas la sécurité. Le périmètre opposable reste celui des
///   policies RLS sur `signalements`. Un superviseur qui contournerait ce
///   filtre ne verrait rien de plus : la base refuserait.
class HistoriqueSignalementsScreen extends StatefulWidget {
  final UserProfile profil;

  /// Autorise l'assignation depuis le détail. Même règle que les tableaux de
  /// bord : seul un superviseur assigne.
  final bool peutAssigner;

  const HistoriqueSignalementsScreen({
    super.key,
    required this.profil,
    this.peutAssigner = false,
  });

  @override
  State<HistoriqueSignalementsScreen> createState() => _HistoriqueSignalementsScreenState();
}

class _HistoriqueSignalementsScreenState extends State<HistoriqueSignalementsScreen> {
  static const _libellesStatuts = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'traite': 'Traité',
    'cloture': 'Clôturé',
  };

  final List<Signalement> _signalements = [];
  String _filtreStatut = 'tous';
  int _page = 0;
  bool _chargement = false;
  bool _finAtteinte = false;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerPageSuivante();
  }

  /// Périmètre de lecture dérivé du rôle.
  ///
  /// L'administrateur n'a pas de filtre : son périmètre est national. Le
  /// superviseur est borné à sa région, le point focal à ce qui lui est
  /// assigné — exactement ce que leur tableau de bord leur montre déjà.
  Map<String, String?> get _perimetre {
    switch (widget.profil.role) {
      case 'superviseur':
        return {'region': widget.profil.region};
      case 'point_focal':
        return {'assigneeUid': widget.profil.id};
      default:
        return {};
    }
  }

  Future<void> _chargerPageSuivante() async {
    if (_chargement || _finAtteinte) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final perimetre = _perimetre;
      final page = await SignalementService().obtenirHistorique(
        region: perimetre['region'],
        assigneeUid: perimetre['assigneeUid'],
        statut: _filtreStatut == 'tous' ? null : _filtreStatut,
        page: _page,
      );

      if (!mounted) return;
      setState(() {
        _signalements.addAll(page);
        _page += 1;
        // Une page incomplète signifie qu'il n'y a plus rien derrière. Évite
        // une requête supplémentaire pour l'apprendre.
        _finAtteinte = page.length < SignalementService.taillePageHistorique;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  /// Repart de zéro. Appelé au changement de filtre et au réessai : le filtre
  /// est appliqué par le serveur, donc les pages déjà chargées ne sont plus
  /// valables.
  void _reinitialiser() {
    setState(() {
      _signalements.clear();
      _page = 0;
      _finAtteinte = false;
      _erreur = null;
    });
    _chargerPageSuivante();
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_cours':
        return AppColors.statusEnCours;
      case 'traite':
        return AppColors.statusTraite;
      case 'cloture':
        return AppColors.statusCloture;
      default:
        return AppColors.statusNouveau;
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

  String _dateCourte(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Recherche sur l\'ensemble des signalements de votre périmètre, '
              'sans limite d\'ancienneté. Contrairement au tableau de bord, '
              'cette liste n\'est pas tronquée.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.grisTexte),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _ChipStatut(
                  label: 'Tous',
                  valeur: 'tous',
                  selectionne: _filtreStatut,
                  onSelect: (v) {
                    setState(() => _filtreStatut = v);
                    _reinitialiser();
                  },
                ),
                ..._libellesStatuts.entries.map(
                  (e) => _ChipStatut(
                    label: e.value,
                    valeur: e.key,
                    selectionne: _filtreStatut,
                    onSelect: (v) {
                      setState(() => _filtreStatut = v);
                      _reinitialiser();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _corps()),
        ],
      ),
    );
  }

  Widget _corps() {
    // Une erreur sur la PREMIÈRE page remplace la liste ; une erreur survenue
    // plus loin ne doit pas effacer ce qui est déjà affiché — elle s'ajoute
    // en bas, en version compacte.
    if (_erreur != null && _signalements.isEmpty) {
      return EtatErreur(
        message: 'L\'historique n\'a pas pu être chargé.',
        onReessayer: _reinitialiser,
      );
    }

    if (_signalements.isEmpty) {
      if (_chargement) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filtreStatut == 'tous'
                ? 'Aucun signalement dans votre périmètre.'
                : 'Aucun signalement « ${_libellesStatuts[_filtreStatut]} » dans votre périmètre.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grisTexte),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _signalements.length + 1,
      itemBuilder: (context, index) {
        if (index == _signalements.length) return _piedDeListe();

        final s = _signalements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.bordure),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: _couleurNature(s.nature).withValues(alpha: 0.15),
              child: Icon(Icons.report_outlined, color: _couleurNature(s.nature), size: 20),
            ),
            title: Text(
              s.categorieLibelle.isEmpty ? s.groupe : s.categorieLibelle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${s.prefecture} · ${s.centreSante}\n${_dateCourte(s.soumisLe)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _couleurStatut(s.statut).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _libellesStatuts[s.statut] ?? s.statut,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _couleurStatut(s.statut),
                ),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SignalementDetailScreen(
                    signalement: s,
                    profil: widget.profil,
                    peutAssigner: widget.peutAssigner,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _piedDeListe() {
    if (_erreur != null) {
      return EtatErreur(
        compact: true,
        message: 'La suite n\'a pas pu être chargée.',
        onReessayer: _chargerPageSuivante,
      );
    }
    if (_chargement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_finAtteinte) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '${_signalements.length} signalement${_signalements.length > 1 ? 's' : ''} — fin de la liste.',
            style: const TextStyle(fontSize: 12, color: AppColors.grisTexte),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text('Charger la suite'),
          onPressed: _chargerPageSuivante,
        ),
      ),
    );
  }
}

class _ChipStatut extends StatelessWidget {
  final String label;
  final String valeur;
  final String selectionne;
  final ValueChanged<String> onSelect;

  const _ChipStatut({
    required this.label,
    required this.valeur,
    required this.selectionne,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final actif = selectionne == valeur;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: actif,
        onSelected: (_) => onSelect(valeur),
        labelStyle: TextStyle(
          fontSize: 13,
          color: actif ? Colors.white : AppColors.grisTexte,
        ),
        selectedColor: AppColors.vertPrimaire,
        backgroundColor: AppColors.grisLeger,
        side: BorderSide.none,
      ),
    );
  }
}
