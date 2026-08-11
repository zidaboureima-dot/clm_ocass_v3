import 'package:flutter/material.dart';
import 'stats_body_public.dart';

class PublicStatsScreen extends StatelessWidget {
  const PublicStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques publiques')),
      body: const StatsBodyPublic(
        description:
            'Données agrégées, aucune information identifiante. Ces statistiques reflètent des signalements anonymes soumis par les communautés, à l\'échelle nationale.',
      ),
    );
  }
}