import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'superviseur_dashboard_screen.dart';
import 'point_focal_dashboard_screen.dart';

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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => destination),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
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
            ],
          ),
        ),
      ),
    );
  }
}
