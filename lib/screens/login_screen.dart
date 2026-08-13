import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'superviseur_dashboard_screen.dart';
import 'point_focal_dashboard_screen.dart';
import '../services/demande_reset_service.dart';
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _motDePasseController = TextEditingController();
  bool _connexionEnCours = false;
  String? _erreur;
  bool _masquerMotDePasse = true;

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _connexionEnCours = true;
      _erreur = null;
    });
    try {
      final profil = await AuthService().login(
        _emailController.text.trim(),
        _motDePasseController.text,
      );
      if (!mounted) return;
      if (profil == null) {
        setState(() => _erreur = 'Compte introuvable. Contactez l\'administrateur.');
        return;
      }
      if (!profil.actif) {
        setState(() => _erreur = 'Ce compte est désactivé. Contactez l\'administrateur.');
        return;
      }
      _routerVersDashboard(profil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = 'Identifiants incorrects ou erreur de connexion.');
    } finally {
      if (mounted) setState(() => _connexionEnCours = false);
    }
  }
Future<void> _ouvrirDialogueMotDePasseOublie() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    bool envoiEnCours = false;
    bool envoye = false;
    String? erreur;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mot de passe oublié'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!envoye) ...[
                    const Text(
                      'Indiquez votre email. Si un compte existe, votre demande '
                      'sera transmise à l\'administrateur, qui vous renverra un '
                      'nouveau mot de passe temporaire par email.',
                      style: TextStyle(fontSize: 13, color: AppColors.grisTexte),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    if (erreur != null) ...[
                      const SizedBox(height: 12),
                      Text(erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 13)),
                    ],
                  ] else
                    const Text(
                      'Si un compte existe pour cette adresse, votre demande a été '
                      'transmise à l\'administrateur.',
                      style: TextStyle(fontSize: 13, color: AppColors.grisTexte),
                    ),
                ],
              ),
              actions: envoye
                  ? [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: envoiEnCours
                            ? null
                            : () async {
                                final email = emailController.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setDialogState(() => erreur = 'Indiquez un email valide.');
                                  return;
                                }
                                setDialogState(() {
                                  envoiEnCours = true;
                                  erreur = null;
                                });
                                try {
                                  await DemandeResetService().demanderReset(email);
                                  setDialogState(() {
                                    envoiEnCours = false;
                                    envoye = true;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    envoiEnCours = false;
                                    erreur = 'Erreur réseau. Réessayez.';
                                  });
                                }
                              },
                        child: envoiEnCours
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Envoyer'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
  void _routerVersDashboard(UserProfile profil) {
    Widget destination;
    switch (profil.role) {
      case 'admin':
        destination = AdminDashboardScreen(profil: profil);
        break;
      case 'superviseur':
        destination = SuperviseurDashboardScreen(profil: profil);
        break;
      case 'point_focal':
        destination = PointFocalDashboardScreen(profil: profil);
        break;
      default:
        setState(() => _erreur = 'Rôle non reconnu : ${profil.role}. Contactez l\'administrateur.');
        return;
    }

    // Forçage du changement de mot de passe : si le compte a été créé ou
    // réinitialisé avec un mot de passe temporaire (doit_changer_mdp = true),
    // on impose l'écran de changement avant l'accès à l'espace. Une fois le
    // mot de passe personnel choisi, ChangePasswordScreen route lui-même vers
    // la destination et remet doit_changer_mdp à false.
    if (profil.doitChangerMdp) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ChangePasswordScreen(
            force: true,
            destinationApres: destination,
          ),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => destination),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.admin_panel_settings, size: 56, color: AppColors.vertPrimaire),
              const SizedBox(height: 16),
              const Text(
                'Accès réservé aux administrateurs, superviseurs et points focaux',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grisTexte),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez votre email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motDePasseController,
                obscureText: _masquerMotDePasse,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_masquerMotDePasse ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _masquerMotDePasse = !_masquerMotDePasse),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Indiquez votre mot de passe' : null,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _connexionEnCours ? null : _seConnecter,
                child: _connexionEnCours
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _connexionEnCours ? null : _ouvrirDialogueMotDePasseOublie,
                child: const Text('Mot de passe oublié ?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
