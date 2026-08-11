import 'package:flutter/material.dart';
import '../models/stats_agregees_model.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';

/// Affiche les statistiques publiques à partir d'agrégats (vue stats_publiques).
/// Ne consomme jamais de lignes de signalement : uniquement des comptes.
class StatsBodyPublic extends StatefulWidget {
  final String description;
  final bool afficherRepartitionRegion;

  const StatsBodyPublic({
    super.key,
    required this.description,
    this.afficherRepartitionRegion = true,
  });

  @override
  State<StatsBodyPublic> createState() => _StatsBodyPublicState();
}

class _StatsBodyPublicState extends State<StatsBodyPublic> {
  late Future<StatsAgregees> _future;

  static const _libellesStatuts = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'traite': 'Traité',
    'cloture': 'Clôturé',
  };

  static const _libellesNature = {
    'normal': 'Normal',
    'urgent': 'Urgent',
    'critique': 'Critique',
  };

  @override
  void initState() {
    super.initState();
    _future = SignalementService().obtenirStatsPubliques();
  }

  void _recharger() {
    setState(() {
      _future = SignalementService().obtenirStatsPubliques();
    });
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StatsAgregees>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Statistiques momentanément indisponibles.',
                    style: TextStyle(color: AppColors.grisTexte),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Réessayer'),
                    onPressed: _recharger,
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final total = stats.total;

        if (total == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun signalement pour ce périmètre.',
                style: TextStyle(color: AppColors.grisTexte),
              ),
            ),
          );
        }

        final topCategories = stats.parCategorie.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final regionsTriees = stats.parRegion.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.vertTresClair,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total signalement${total > 1 ? 's' : ''} au total',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.description, style: const TextStyle(fontSize: 12, color: AppColors.grisTexte, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _TitreSection('Par statut'),
            const SizedBox(height: 10),
            ..._libellesStatuts.entries.map(
              (e) => _BarreHorizontale(
                label: e.value,
                valeur: stats.parStatut[e.key] ?? 0,
                total: total,
                couleur: _couleurStatut(e.key),
              ),
            ),
            const SizedBox(height: 24),
            const _TitreSection('Par gravité'),
            const SizedBox(height: 10),
            ..._libellesNature.entries.map(
              (e) => _BarreHorizontale(
                label: e.value,
                valeur: stats.parNature[e.key] ?? 0,
                total: total,
                couleur: _couleurNature(e.key),
              ),
            ),
            const SizedBox(height: 24),
            const _TitreSection('Catégories les plus signalées'),
            const SizedBox(height: 10),
            if (topCategories.isEmpty)
              const Text('Aucune donnée.', style: TextStyle(color: AppColors.grisTexte))
            else
              ...topCategories.take(5).map(
                    (e) => _BarreHorizontale(
                      label: e.key,
                      valeur: e.value,
                      total: total,
                      couleur: AppColors.vertPrimaire,
                    ),
                  ),
            if (widget.afficherRepartitionRegion) ...[
              const SizedBox(height: 24),
              const _TitreSection('Par région'),
              const SizedBox(height: 10),
              ...regionsTriees.map(
                (e) => _BarreHorizontale(
                  label: e.key,
                  valeur: e.value,
                  total: total,
                  couleur: AppColors.vertFonce,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;
  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) {
    return Text(texte, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.vertFonce));
  }
}

class _BarreHorizontale extends StatelessWidget {
  final String label;
  final int valeur;
  final int total;
  final Color couleur;

  const _BarreHorizontale({
    required this.label,
    required this.valeur,
    required this.total,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final proportion = total == 0 ? 0.0 : valeur / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('$valeur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleur)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 8, width: constraints.maxWidth, color: AppColors.grisLeger),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * (proportion.clamp(0, 1)),
                      color: couleur,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}