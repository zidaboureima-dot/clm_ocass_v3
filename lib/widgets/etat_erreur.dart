import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Affichage d'une erreur de chargement, avec réessai quand c'est possible.
///
/// POURQUOI UN WIDGET PARTAGÉ
///   Trois situations doivent rester distinctes aux yeux de l'utilisateur :
///
///     - CHARGEMENT — c'est en cours, patienter ;
///     - VIDE       — tout va bien, il n'y a simplement rien à afficher ;
///     - ERREUR     — quelque chose a échoué, voici quoi faire.
///
///   Avant ce widget, la troisième était absorbée par la première : un
///   builder en erreur renvoyait un CircularProgressIndicator qui tournait
///   indéfiniment. En connexion instable, c'est le pire retour possible —
///   un chargement perpétuel est indiscernable d'une lenteur, donc
///   l'utilisateur attend au lieu de réessayer.
///
/// POURQUOI LE TEXTE DE L'EXCEPTION N'EST JAMAIS AFFICHÉ
///   Les écrans affichaient « Erreur : ${snapshot.error} ». Deux raisons de
///   ne plus le faire :
///
///     1. Le destinataire est un point focal ou un superviseur, pas un
///        développeur. « PostgrestException(message: JWT expired...) » ne lui
///        dit pas quoi faire.
///     2. Le texte d'une exception Postgrest cite noms de tables, de colonnes
///        et de policies. C'est de l'information sur l'architecture, affichée
///        sur un appareil qui peut être consulté par un tiers.
///
///   Le diagnostic appartient aux journaux du serveur, pas à l'écran.
class EtatErreur extends StatelessWidget {
  /// Ce qui a échoué, dit à l'utilisateur et non au développeur.
  final String message;

  /// Rappel de rechargement. Absent quand l'écran n'a aucun moyen de
  /// reconstruire sa source : mieux vaut pas de bouton qu'un bouton qui ne
  /// fait rien.
  final VoidCallback? onReessayer;

  /// Version resserrée, pour une erreur à l'intérieur d'un écran qui, lui,
  /// s'est affiché correctement (une section d'un détail de signalement).
  /// L'erreur ne doit alors occuper que sa section, pas s'imposer comme si
  /// toute la page avait échoué.
  final bool compact;

  const EtatErreur({
    super.key,
    this.message = 'La connexion au serveur a échoué.',
    this.onReessayer,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.grisTexte),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.grisTexte),
              ),
            ),
            if (onReessayer != null)
              TextButton(
                onPressed: onReessayer,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Réessayer', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.grisTexte),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, color: AppColors.grisTexte),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vérifiez votre connexion internet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grisTexte),
            ),
            if (onReessayer != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
                onPressed: onReessayer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
