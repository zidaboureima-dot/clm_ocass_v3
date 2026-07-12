import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_prep.dart';
import '../theme/app_colors.dart';

class PhotoPickerField extends StatefulWidget {
  final void Function(File? fichier) onSelection;

  const PhotoPickerField({super.key, required this.onSelection});

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  File? _fichier;
  bool _preparationEnCours = false;

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
      widget.onSelection(pret);
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

  void _retirer() {
    setState(() => _fichier = null);
    widget.onSelection(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grisLeger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photo (optionnelle)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            'Évitez de cadrer des visages reconnaissables. La localisation est retirée automatiquement.',
            style: TextStyle(fontSize: 11, color: AppColors.grisTexte),
          ),
          const SizedBox(height: 10),
          if (_preparationEnCours)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (_fichier == null)
            OutlinedButton.icon(
              onPressed: _ouvrirChoix,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Ajouter une photo'),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_fichier!, width: 64, height: 64, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _retirer,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Retirer'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
