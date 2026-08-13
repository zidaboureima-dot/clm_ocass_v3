import 'package:flutter/material.dart';
import '../models/demande_reset_model.dart';
import '../services/demande_reset_service.dart';
import '../theme/app_colors.dart';

class AdminDemandesResetTab extends StatefulWidget {
  const AdminDemandesResetTab({super.key});

  @override
  State<AdminDemandesResetTab> createState() => _AdminDemandesResetTabState();
}

class _AdminDemandesResetTabState extends State<AdminDemandesResetTab> {
  late Stream<List<DemandeReset>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = DemandeResetService().streamDemandesEnAttente();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DemandeReset>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final demandes = snapshot.data!;
        if (demandes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune demande de réinitialisation en attente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grisTexte),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grisLeger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Un responsable a demandé la réinitialisation de son mot de passe. '
                'En envoyant un nouveau lien, un mot de passe temporaire lui est '
                'transmis par email ; il devra le changer à sa prochaine connexion.',
                style: TextStyle(fontSize: 12, color: AppColors.grisTexte),
              ),
            ),
            ...demandes.map((d) => _DemandeTile(demande: d)),
          ],
        );
      },
    );
  }
}

class _DemandeTile extends StatefulWidget {
  final DemandeReset demande;
  const _DemandeTile({required this.demande});

  @override
  State<_DemandeTile> createState() => _DemandeTileState();
}

class _DemandeTileState extends State<_DemandeTile> {
  bool _envoiEnCours = false;

  Future<void> _traiter() async {
    setState(() => _envoiEnCours = true);
    try {
      await DemandeResetService().traiterDemande(widget.demande.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouveau lien envoyé par email.')),
        );
      }
      // La ligne disparaît d'elle-même : la demande passe à 'traitee',
      // le stream ne la renvoie plus.
    } catch (e) {
      if (mounted) {
        setState(() => _envoiEnCours = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : $e'), backgroundColor: AppColors.rouge),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demande;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.bordure),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${d.libelleRole} · ${d.zone}',
              style: const TextStyle(fontSize: 13, color: AppColors.grisTexte),
            ),
            const SizedBox(height: 2),
            Text(
              d.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.grisTexte),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _envoiEnCours ? null : _traiter,
                icon: _envoiEnCours
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.mail_outline, size: 18),
                label: const Text('Envoyer nouveau lien'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.vertPrimaire),
              ),
            ),
          ],
        ),
      ),
    );
  }
}