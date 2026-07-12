import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_brute_service.dart';
import '../services/photo_prep.dart';
import '../theme/app_colors.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  File? _fichier;
  bool _preparationEnCours = false;
  bool _envoiEnCours = false;

  Future<void> _choisir(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 90);
    if (xfile == null) return;
    setState(() => _preparationEnCours = true);
    try {
      final pret = await preparerPhoto(File(xfile.path));
      setState(() {
        _fichier = pret;
        _preparationEnCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _preparationEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lecture photo : $e')),
      );
    }
  }

  Future<void> _ouvrirChoix() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.vertPrimaire),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(context).pop();
                _choisir(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.vertPrimaire),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.of(context).pop();
                _choisir(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _envoyer() async {
    if (_fichier == null) return;
    setState(() => _envoiEnCours = true);
    try {
      await PhotoBruteService().uploaderPhotoBrute(fichier: _fichier!);
      if (!mounted) return;
      _afficherConfirmation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  void _afficherConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.statusTraite, size: 32),
            SizedBox(width: 12),
            Text('Photo envoyée'),
          ],
        ),
        content: const Text(
          'Votre photo a bien été reçue et sera examinée rapidement.',
          style: TextStyle(height: 1.5, fontSize: 16),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer une photo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.photo_camera_back_outlined, size: 56, color: AppColors.vertPrimaire),
            const SizedBox(height: 12),
            const Text(
              'Photographiez ce qui pose problème',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
            ),
            const SizedBox(height: 6),
            const Text(
              'Évitez de cadrer des visages reconnaissables. La localisation est retirée automatiquement de la photo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.grisTexte),
            ),
            const SizedBox(height: 28),
            if (_preparationEnCours)
              const CircularProgressIndicator()
            else if (_fichier == null)
              OutlinedButton.icon(
                onPressed: _ouvrirChoix,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Choisir une photo'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_fichier!, height: 220, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _envoiEnCours ? null : _envoyer,
                icon: _envoiEnCours
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_envoiEnCours ? 'Envoi…' : 'Envoyer'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _envoiEnCours ? null : () => setState(() => _fichier = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Recommencer'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
