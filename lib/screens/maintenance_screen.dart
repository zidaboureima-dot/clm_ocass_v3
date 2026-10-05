import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Écran affiché à un responsable lorsque le service est en maintenance.
///
/// Trois choses doivent y figurer, et elles sont là pour des raisons
/// précises :
///
///   - **Ce n'est pas une panne.** Un écran muet laisse croire à une avarie,
///     et un point focal qui croit l'application cassée cesse de l'ouvrir.
///   - **Les signalements continuent d'arriver.** Le dépôt citoyen n'est
///     jamais bloqué : le dire évite qu'un responsable s'inquiète d'une perte.
///   - **Quand revenir**, si le message l'indique.
class MaintenanceScreen extends StatelessWidget {
  final String? message;

  const MaintenanceScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service en maintenance')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.build_outlined, size: 56, color: AppColors.vertFonce),
              const SizedBox(height: 24),
              const Text(
                'Maintenance en cours',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.vertFonce,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message?.trim().isNotEmpty == true
                    ? message!.trim()
                    : 'L’accès aux espaces de traitement est momentanément '
                      'suspendu. Merci de réessayer un peu plus tard.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5, color: AppColors.grisTexte),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.vertTresClair,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Les signalements des citoyens continuent d’être reçus '
                  'normalement. Rien n’est perdu : vous les retrouverez à la '
                  'reprise du service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.grisTexte),
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Retour à l’accueil'),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
