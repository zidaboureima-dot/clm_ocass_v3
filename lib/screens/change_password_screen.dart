import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nouveauController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _envoiEnCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nouveauController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _changer() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _nouveauController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.vertPrimaire),
              const SizedBox(height: 16),
              const Text(
                'Choisissez un nouveau mot de passe personnel, à ne partager avec personne.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grisTexte),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nouveauController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => (v == null || v.length < 6) ? 'Six caractères minimum' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (v) => (v != _nouveauController.text) ? 'Les mots de passe ne correspondent pas' : null,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 16),
                Text(_erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _envoiEnCours ? null : _changer,
                child: _envoiEnCours
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
