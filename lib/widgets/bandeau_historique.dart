import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../screens/historique_signalements_screen.dart';
import '../services/signalement_service.dart';
import '../theme/app_colors.dart';

/// Bandeau placé sous les filtres d'un tableau de bord : il dit que la liste
/// est bornée, et ouvre l'historique complet.
///
/// POURQUOI IL EST TOUJOURS VISIBLE
///   Les flux temps réel sont bornés aux `limiteFluxTempsReel` signalements
///   les plus récents, et les filtres de statut d'un tableau de bord
///   s'appliquent CÔTÉ CLIENT — donc à l'intérieur de cette fenêtre. Filtrer
///   sur « Clôturé » peut donc afficher trois cas alors qu'il en existe
///   quatre cents.
///
///   Une liste tronquée qui ne le dit pas est un mensonge d'interface :
///   l'utilisateur ne compte pas les lignes, il fait confiance à ce qu'il voit.
///   Le bandeau est donc affiché en permanence, et pas seulement quand la
///   troncature mord — parce que l'utilisateur ne doit jamais avoir à se
///   demander dans quel régime il se trouve.
class BandeauHistorique extends StatelessWidget {
  final UserProfile profil;

  /// Même règle que les tableaux de bord : seul un superviseur assigne.
  final bool peutAssigner;

  const BandeauHistorique({
    super.key,
    required this.profil,
    this.peutAssigner = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => HistoriqueSignalementsScreen(
              profil: profil,
              peutAssigner: peutAssigner,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.vertTresClair,
        child: Row(
          children: [
            const Icon(Icons.history, size: 16, color: AppColors.vertFonce),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cette liste montre les ${SignalementService.limiteFluxTempsReel} '
                'signalements les plus récents. Ouvrir l\'historique complet.',
                style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.vertFonce),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.vertFonce),
          ],
        ),
      ),
    );
  }
}
