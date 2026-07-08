import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  final UserProfile profil;
  const AdminDashboardScreen({super.key, required this.profil});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace administrateur'),
        actions: [
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue, ${profil.nom}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
            ),
            const SizedBox(height: 4),
            Text(profil.email, style: const TextStyle(color: AppColors.grisTexte)),
            const SizedBox(height: 24),
            const Text(
              'Tableau de bord administrateur : liste et affectation des signalements, gestion des comptes superviseurs et points focaux, gestion des catégories. À construire dans la suite de la Phase 2.',
              style: TextStyle(color: AppColors.grisTexte, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
