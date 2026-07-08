import 'package:flutter/material.dart';
import '../models/signalement_model.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';
import 'signalement_detail_screen.dart';
import 'stats_body.dart';

class PointFocalDashboardScreen extends StatefulWidget {
  final UserProfile profil;
  const PointFocalDashboardScreen({super.key, required this.profil});

  @override
  State<PointFocalDashboardScreen> createState() => _PointFocalDashboardScreenState();
}

class _PointFocalDashboardScreenState extends State<PointFocalDashboardScreen> {
  late Stream<List<Signalement>> _stream;
  String _filtreStatut = 'tous';

  static const _libellesStatuts = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'traite': 'Traité',
    'cloture': 'Clôturé',
  };

  @override
  void initState() {
    super.initState();
    _stream = SignalementService().streamSignalementsAssignes(widget.profil.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace point focal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Statistiques de la préfecture',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: Text('Statistiques — ${widget.profil.prefecture ?? ''}')),
                    body: StatsBody(
                      stream: SignalementService().streamSignalementsParPrefecture(widget.profil.prefecture ?? ''),
                      description: 'Vue préfectorale : ${widget.profil.prefecture ?? ''}, tous les signalements (pas seulement ceux qui vous sont assignés).',
                      afficherRepartitionRegion: false,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Préfecture : ${widget.profil.prefecture ?? 'non définie'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipFiltre(label: 'Tous', valeur: 'tous', selectionne: _filtreStatut, onSelect: (v) => setState(() => _filtreStatut = v)),
                  const SizedBox(width: 8),
                  ..._libellesStatuts.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChipFiltre(label: e.value, valeur: e.key, selectionne: _filtreStatut, onSelect: (v) => setState(() => _filtreStatut = v)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Signalement>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur : ${snapshot.error}'));
                }
                var signalements = snapshot.data!;
                if (_filtreStatut != 'tous') {
                  signalements = signalements.where((s) => s.statut == _filtreStatut).toList();
                }
                if (signalements.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun signalement assigné pour ce filtre.\nLe superviseur vous assignera les signalements de votre préfecture.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grisTexte),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: signalements.length,
                  itemBuilder: (context, index) {
                    final s = signalements[index];
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
                        subtitle: Text(s.centreSante, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _couleurStatut(s.statut).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _libellesStatuts[s.statut] ?? s.statut,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _couleurStatut(s.statut)),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SignalementDetailScreen(
                                signalement: s,
                                profil: widget.profil,
                                peutAssigner: false,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFiltre extends StatelessWidget {
  final String label;
  final String valeur;
  final String selectionne;
  final ValueChanged<String> onSelect;

  const _ChipFiltre({
    required this.label,
    required this.valeur,
    required this.selectionne,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final actif = valeur == selectionne;
    return ChoiceChip(
      label: Text(label),
      selected: actif,
      onSelected: (_) => onSelect(valeur),
      selectedColor: AppColors.vertPrimaire.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: actif ? AppColors.vertFonce : AppColors.grisTexte,
        fontWeight: actif ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: actif ? AppColors.vertPrimaire : AppColors.bordure),
    );
  }
}
