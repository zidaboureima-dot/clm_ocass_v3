import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'services/signalement_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLM/OCASS Guinée',
      theme: AppTheme.lightTheme(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> statsFuture;

  @override
  void initState() {
    super.initState();
    statsFuture = SignalementService().obtenirStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLM/OCASS Guinée'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.vertPrimaire, AppColors.vertFonce],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suivi dirigé par les communautés',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Signalez un dysfonctionnement en toute confidentialité',
                    style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Text('Erreur chargement stats');
                }
                final stats = snapshot.data!;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _StatCard('Total notifiés', stats['total'] ?? 0, AppColors.vertPrimaire),
                    _StatCard('Traités', stats['traites'] ?? 0, AppColors.statusTraite),
                    _StatCard('Ce mois', 0, AppColors.bleu),
                    _StatCard('Clôturés', 0, AppColors.statusCloture),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grisTexte), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
