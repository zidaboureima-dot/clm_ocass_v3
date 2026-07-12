import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'services/signalement_service.dart';
import 'screens/signalement_form_screen.dart';
import 'screens/message_vocal_screen.dart';
import 'screens/photo_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_stats_screen.dart';

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
  late Stream<List<Map<String, dynamic>>> statsStream;

  @override
  void initState() {
    super.initState();
    statsStream = SignalementService().streamSignalements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLM/OCASS Guinée'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.vertPrimaire, AppColors.vertFonce],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suivi dirigé par les communautés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Signalez un dysfonctionnement en toute confidentialité',
                    style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Statistiques',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: statsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text('Erreur chargement stats');
                }
                final stats = SignalementService().calculerStats(snapshot.data!);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 2.7,
                  children: [
                    _StatCard('Total global', stats['total'] ?? 0, AppColors.vertPrimaire),
                    _StatCard('En cours', stats['en_cours'] ?? 0, AppColors.orange),
                    _StatCard('Traités', stats['traites'] ?? 0, AppColors.statusTraite),
                    _StatCard('Clôturés', stats['clotures'] ?? 0, AppColors.statusCloture),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.report_outlined, size: 18),
              label: const Text('Signaler un dysfonctionnement'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignalementFormScreen()),
                );
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.mic_outlined, size: 18),
              label: const Text('Message vocal (sans lecture)'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MessageVocalScreen()),
                );
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Envoyer une photo'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PhotoScreen()),
                );
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.bar_chart_outlined, size: 18),
              label: const Text('Statistiques publiques'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PublicStatsScreen()),
                );
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('Accès admin'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(32)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.grisLeger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Cette application respecte la confidentialité et l\'anonymat. Elle est conforme à la loi L/2016/037/AN du 28 juillet 2016, relative à la cybersécurité et à la protection des données à caractère personnel de la République de Guinée.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: AppColors.grisTexte, height: 1.25),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.grisTexte),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
