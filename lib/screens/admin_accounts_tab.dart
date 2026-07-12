import 'package:flutter/material.dart';
import '../data/regions_prefectures.dart';
import '../models/user_profile_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class AdminAccountsTab extends StatefulWidget {
  const AdminAccountsTab({super.key});

  @override
  State<AdminAccountsTab> createState() => _AdminAccountsTabState();
}

class _AdminAccountsTabState extends State<AdminAccountsTab> {
  late Stream<List<UserProfile>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = UserService().streamComptesGeres();
  }

  Future<void> _ouvrirDialogueCreation() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final nomController = TextEditingController();
    String role = 'superviseur';
    String? region;
    String? prefecture;
    bool envoiEnCours = false;
    String? erreur;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouveau compte'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Rôle'),
                        items: const [
                          DropdownMenuItem(value: 'superviseur', child: Text('Superviseur')),
                          DropdownMenuItem(value: 'point_focal', child: Text('Point focal')),
                        ],
                        onChanged: (v) => setDialogState(() {
                          role = v ?? 'superviseur';
                          region = null;
                          prefecture = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nomController,
                        decoration: const InputDecoration(labelText: 'Nom complet'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le nom' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez l\'email' : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.grisLeger, borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          'Un mot de passe temporaire sera généré automatiquement et envoyé par email à la personne, qui devra le changer dès sa première connexion.',
                          style: TextStyle(fontSize: 12, color: AppColors.grisTexte),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (role == 'superviseur')
                        DropdownButtonFormField<String>(
                          initialValue: region,
                          decoration: const InputDecoration(labelText: 'Région'),
                          items: RegionsPrefectures.regions
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => region = v),
                          validator: (v) => v == null ? 'Sélectionnez une région' : null,
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: region,
                          decoration: const InputDecoration(labelText: 'Région'),
                          items: RegionsPrefectures.regions
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setDialogState(() {
                            region = v;
                            prefecture = null;
                          }),
                          validator: (v) => v == null ? 'Sélectionnez une région' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: prefecture,
                          decoration: const InputDecoration(labelText: 'Préfecture / Commune'),
                          items: RegionsPrefectures.prefecturesDe(region ?? '')
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: region == null ? null : (v) => setDialogState(() => prefecture = v),
                          validator: (v) => v == null ? 'Sélectionnez une préfecture' : null,
                        ),
                      ],
                      if (erreur != null) ...[
                        const SizedBox(height: 12),
                        Text(erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
                FilledButton(
                  onPressed: envoiEnCours
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() != true) return;
                          setDialogState(() {
                            envoiEnCours = true;
                            erreur = null;
                          });
                          try {
                            await UserService().creerCompte(
                              email: emailController.text.trim(),
                              role: role,
                              nom: nomController.text.trim(),
                              region: region,
                              prefecture: role == 'point_focal' ? prefecture : null,
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setDialogState(() {
                              envoiEnCours = false;
                              erreur = '$e';
                            });
                          }
                        },
                  child: envoiEnCours
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<UserProfile>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final comptes = snapshot.data!;
          final superviseurs = comptes.where((c) => c.role == 'superviseur').toList();
          final pointsFocaux = comptes.where((c) => c.role == 'point_focal').toList();

          if (comptes.isEmpty) {
            return const Center(
              child: Text('Aucun compte superviseur ou point focal pour le moment.', style: TextStyle(color: AppColors.grisTexte)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Superviseurs (${superviseurs.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
              const SizedBox(height: 8),
              ...superviseurs.map((c) => _CompteTile(compte: c, sousTitre: c.region ?? 'région non définie')),
              const SizedBox(height: 20),
              Text('Points focaux (${pointsFocaux.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vertFonce)),
              const SizedBox(height: 8),
              ...pointsFocaux.map((c) => _CompteTile(compte: c, sousTitre: c.prefecture ?? 'préfecture non définie')),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirDialogueCreation,
        icon: const Icon(Icons.person_add),
        label: const Text('Compte'),
        backgroundColor: AppColors.vertPrimaire,
      ),
    );
  }
}

class _CompteTile extends StatelessWidget {
  final UserProfile compte;
  final String sousTitre;
  const _CompteTile({required this.compte, required this.sousTitre});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.bordure)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(compte.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$sousTitre · ${compte.email}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Switch(
          value: compte.actif,
          activeThumbColor: AppColors.vertPrimaire,
          onChanged: (v) => UserService().basculerActifCompte(compte.id, v),
        ),
      ),
    );
  }
}
