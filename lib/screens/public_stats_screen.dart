import 'package:flutter/material.dart';
import '../services/signalement_service.dart';
import 'stats_body.dart';

class PublicStatsScreen extends StatelessWidget {
  const PublicStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques publiques')),
      body: StatsBody(
        stream: SignalementService().streamToutesSignalements(),
        description:
            'Données agrégées, aucune information identifiante. Ces statistiques reflètent des signalements anonymes soumis par les communautés, à l\'échelle nationale.',
      ),
    );
  }
}
