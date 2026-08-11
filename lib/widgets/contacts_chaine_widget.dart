import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/signalement_model.dart';
import '../models/user_profile_model.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

/// Affiche les acteurs de la chaine d'un cas (central, superviseur, point focal)
/// avec des boutons d'appel et WhatsApp. Tout acteur de la chaine se voit.
class ContactsChaineWidget extends StatefulWidget {
  final Signalement signalement;
  final UserProfile profil;

  const ContactsChaineWidget({
    super.key,
    required this.signalement,
    required this.profil,
  });

  @override
  State<ContactsChaineWidget> createState() => _ContactsChaineWidgetState();
}

class _ContactsChaineWidgetState extends State<ContactsChaineWidget> {
  bool _chargement = true;
  final List<_ActeurChaine> _acteurs = [];

  @override
  void initState() {
    super.initState();
    _chargerChaine();
  }

  Future<void> _chargerChaine() async {
    final s = widget.signalement;
    final cibles = <MapEntry<String, String?>>[
      MapEntry('Central', s.adminUid),
      MapEntry('Superviseur', s.superviseurUid),
      MapEntry('Point focal', s.assigneeUid),
    ];

    final resultats = <_ActeurChaine>[];
    for (final cible in cibles) {
      final uid = cible.value;
      if (uid == null) continue;
      if (uid == widget.profil.id) continue;
      final profil = await UserService().obtenirUtilisateur(uid);
      if (profil == null) continue;
      resultats.add(_ActeurChaine(libelleRole: cible.key, profil: profil));
    }

    if (!mounted) return;
    setState(() {
      _acteurs
        ..clear()
        ..addAll(resultats);
      _chargement = false;
    });
  }

  String _nettoyerNumero(String numero) {
    return numero.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<void> _appeler(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _erreur('Impossible de lancer l\'appel.');
    }
  }

  Future<void> _whatsapp(String numero) async {
    final uri = Uri.parse('https://wa.me/${_nettoyerNumero(numero)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _erreur('WhatsApp n\'est pas disponible.');
    }
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (_acteurs.isEmpty) {
      return const Text(
        'Aucun autre acteur a contacter sur ce cas pour le moment.',
        style: TextStyle(color: AppColors.grisTexte, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _acteurs.map(_carteActeur).toList(),
    );
  }

  Widget _carteActeur(_ActeurChaine acteur) {
    final p = acteur.profil;
    final tel = p.telephone;
    final wa = p.whatsapp;
    final aucunContact = (tel == null || tel.isEmpty) && (wa == null || wa.isEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grisLeger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acteur.libelleRole,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
                ),
                const SizedBox(height: 2),
                Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (aucunContact)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Numero non renseigne', style: TextStyle(fontSize: 11, color: AppColors.grisTexte)),
                  ),
              ],
            ),
          ),
          if (tel != null && tel.isNotEmpty)
            IconButton(
              tooltip: 'Appeler',
              onPressed: () => _appeler(tel),
              icon: const Icon(Icons.phone, color: AppColors.vertFonce),
            ),
          if (wa != null && wa.isNotEmpty)
            IconButton(
              tooltip: 'WhatsApp',
              onPressed: () => _whatsapp(wa),
              icon: const Icon(Icons.chat, color: AppColors.vertFonce),
            ),
        ],
      ),
    );
  }
}

class _ActeurChaine {
  final String libelleRole;
  final UserProfile profil;
  _ActeurChaine({required this.libelleRole, required this.profil});
}