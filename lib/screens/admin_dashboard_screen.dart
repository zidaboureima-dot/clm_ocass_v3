import 'package:flutter/material.dart';
import '../data/regions_prefectures.dart';
import '../models/signalement_model.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../services/message_vocal_service.dart';
import '../services/photo_brute_service.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';
import 'admin_accounts_tab.dart';
import 'admin_categories_tab.dart';
import 'admin_messages_vocaux_tab.dart';
import 'admin_photos_tab.dart';
import 'change_password_screen.dart';
import 'signalement_detail_screen.dart';
import 'stats_body.dart';
import 'admin_demandes_reset_tab.dart';
import '../services/demande_reset_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserProfile profil;
  const AdminDashboardScreen({super.key, required this.profil});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Stream<List<Signalement>> _stream;
  String _filtreStatut = 'tous';
  String _filtreRegion = 'toutes';

  static const _libellesStatuts = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'traite': 'Traité',
    'cloture': 'Clôturé',
  };

  @override
  void initState() {
    super.initState();
    _stream = SignalementService().streamToutesSignalements();
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
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace administrateur'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Signalements'),
              const Tab(text: 'Catégories'),
              const Tab(text: 'Statistiques'),
              const Tab(text: 'Comptes'),
              Tab(
                child: StreamBuilder(
                  stream: DemandeResetService().streamDemandesEnAttente(),
                  builder: (context, snapshot) {
                    final n = snapshot.data?.length ?? 0;
                    if (n == 0) return const Text('Réinitialisations');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Réinitialisations'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.rouge, borderRadius: BorderRadius.circular(10)),
                          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                ),
              ),
                Tab(
                child: StreamBuilder(
                  stream: MessageVocalService().streamMessagesNonTraites(),
                  builder: (context, snapshot) {
                    final n = snapshot.data?.length ?? 0;
                    if (n == 0) return const Text('Messages vocaux');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Messages vocaux'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.rouge, borderRadius: BorderRadius.circular(10)),
                          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Tab(
                child: StreamBuilder(
                  stream: PhotoBruteService().streamPhotosNonTraitees(),
                  builder: (context, snapshot) {
                    final n = snapshot.data?.length ?? 0;
                    if (n == 0) return const Text('Photos');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Photos'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.rouge, borderRadius: BorderRadius.circular(10)),
                          child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Changer le mot de passe',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
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
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filtreRegion,
                          decoration: const InputDecoration(labelText: 'Région', isDense: true),
                          items: [
                            const DropdownMenuItem(value: 'toutes', child: Text('Toutes les régions')),
                            ...RegionsPrefectures.regions.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                          ],
                          onChanged: (v) => setState(() => _filtreRegion = v ?? 'toutes'),
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
                      if (_filtreRegion != 'toutes') {
                        signalements = signalements.where((s) => s.region == _filtreRegion).toList();
                      }
                      if (signalements.isEmpty) {
                        return const Center(
                          child: Text('Aucun signalement pour ce filtre.', style: TextStyle(color: AppColors.grisTexte)),
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
                              subtitle: Text('${s.region} · ${s.prefecture}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                      peutAssigner: true,
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
            const AdminCategoriesTab(),
            StatsBody(
              stream: SignalementService().streamToutesSignalements(),
              description: 'Vue nationale, toutes régions confondues.',
            ),
            const AdminAccountsTab(),
            const AdminDemandesResetTab(),
            AdminMessagesVocauxTab(adminUid: widget.profil.id),
            AdminPhotosTab(adminUid: widget.profil.id),
          ],
        ),
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
