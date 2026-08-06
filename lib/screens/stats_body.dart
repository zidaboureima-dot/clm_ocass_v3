import 'package:flutter/material.dart';
import '../models/signalement_model.dart';
import '../theme/app_colors.dart';

class StatsBody extends StatelessWidget {
  final Stream<List<Signalement>> stream;
  final String description;
  final bool afficherRepartitionRegion;

  const StatsBody({
    super.key,
    required this.stream,
    required this.description,
    this.afficherRepartitionRegion = true,
  });

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
    return StreamBuilder<List<Signalement>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Statistiques momentanément indisponibles.',
                style: TextStyle(color: AppColors.grisTexte),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final signalements = snapshot.data ?? [];
        if (signalements.isEmpty) {
          return const Center(
            child: Text('Aucun signalement pour ce périmètre.', style: TextStyle(color: AppColors.grisTexte)),
          );
        }

        final parStatut = <String, int>{};
        final parNature = <String, int>{};
        final parCategorie = <String, int>{};
        final parRegion = <String, int>{};
        for (final s in signalements) {
          parStatut[s.statut] = (parStatut[s.statut] ?? 0) + 1;
          parNature[s.nature] = (parNature[s.nature] ?? 0) + 1;
          final cat = s.categorieLibelle.isEmpty ? s.groupe : s.categorieLibelle;
          if (cat.isNotEmpty) parCategorie[cat] = (parCategorie[cat] ?? 0) + 1;
          parRegion[s.region] = (parRegion[s.region] ?? 0) + 1;
        }

        final topCategories = parCategorie.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final regionsTriees = parRegion.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final total = signalements.length;

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
                  Text(description, style: const TextStyle(fontSize: 12, color: AppColors.grisTexte, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _TitreSection('Par statut'),
            const SizedBox(height: 10),
            ..._libellesStatuts.entries.map(
              (e) => _BarreHorizontale(
                label: e.value,
                valeur: parStatut[e.key] ?? 0,
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
                valeur: parNature[e.key] ?? 0,
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
            if (afficherRepartitionRegion) ...[
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
